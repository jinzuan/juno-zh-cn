<#
.SYNOPSIS
  对一个模块的全部批次做整体验收：结构闸门 + 跨批一致性 + BOM 归一。

.DESCRIPTION
  1. 对每个 <Prefix>*.todo.json 找到配对的 .zh.json，调用 check-batch.ps1 做结构闸门（子进程调用，避免 exit 传染）
  2. 跨批一致性：同一英文原文在不同批次里必须译法一致（id 不同但 en 相同的条目）
  3. id 全局唯一性（不重复、不跨批重复）
  4. UTF-8 BOM 归一（与 src\strings.json / 已定稿批次保持一致）

.NOTES
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\check-group.ps1 -Prefix Career
  退出码 0 = 通过，1 = 有需要修的问题。
#>
[CmdletBinding()]
param(
    [string]$BatchesDir = (Join-Path $PSScriptRoot '..\batches'),
    [string]$Prefix = 'Career',
    [string]$Checker = (Join-Path $PSScriptRoot 'check-batch.ps1'),
    [switch]$SkipBom
)

$ErrorActionPreference = 'Stop'
$batchesDir = (Resolve-Path $BatchesDir).Path

$todos = @(Get-ChildItem $batchesDir -Filter "$Prefix*.todo.json" | Sort-Object Name)
if ($todos.Count -eq 0) { Write-Host "no todo files matching $Prefix*.todo.json"; exit 1 }

$bad = New-Object 'System.Collections.Generic.List[string]'
$rows = New-Object 'System.Collections.Generic.List[object]'

$allEn = @{}        # en -> list of @{id; zh}
$allIds = @{}       # id -> file

foreach ($todo in $todos) {
    $zhPath = $todo.FullName -replace '\.todo\.json$', '.zh.json'
    if (-not (Test-Path $zhPath)) { $bad.Add("missing translation file: $(Split-Path $zhPath -Leaf)"); continue }

    # -- BOM 归一
    if (-not $SkipBom) {
        $bytes = [System.IO.File]::ReadAllBytes($zhPath)
        if (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
            $text = [System.IO.File]::ReadAllText($zhPath)
            [System.IO.File]::WriteAllText($zhPath, $text, (New-Object System.Text.UTF8Encoding($true)))
            Write-Host ("BOM added: {0}" -f (Split-Path $zhPath -Leaf))
        }
    }

    # -- 结构闸门（子进程）
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Checker -Todo $todo.FullName -Zh $zhPath 2>&1 | Out-String
    $code = $LASTEXITCODE
    $fatal = if ($out -match 'fatal\s*:\s*(\d+)') { [int]$Matches[1] } else { -1 }
    $width = if ($out -match 'width hits\s*:\s*(\d+)') { [int]$Matches[1] } else { -1 }
    $warn  = if ($out -match 'warn\s*:\s*(\d+)') { [int]$Matches[1] } else { -1 }

    $rows.Add([pscustomobject]@{
        File = Split-Path $todo.FullName -Leaf; Fatal = $fatal; Warn = $warn; Width = $width; Exit = $code
    })
    if ($code -ne 0 -or $fatal -ne 0) { $bad.Add("$($todo.Name): fatal=$fatal width=$width exit=$code") }

    # -- 收集 en/id
    $src = Get-Content $todo.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $dst = Get-Content $zhPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $map = @{}
    foreach ($d in $dst) { if (-not $map.ContainsKey($d.id)) { $map[$d.id] = $d.zh } }

    foreach ($s in $src) {
        if ($allIds.ContainsKey($s.id)) { $bad.Add("duplicate id across module: $($s.id)") }
        else { $allIds[$s.id] = $todo.Name }

        if ($map.ContainsKey($s.id)) {
            if (-not $allEn.ContainsKey($s.en)) { $allEn[$s.en] = New-Object 'System.Collections.Generic.List[object]' }
            $allEn[$s.en].Add([pscustomobject]@{ id = $s.id; zh = [string]$map[$s.id]; file = $todo.Name })
        }
    }
}

Write-Host "`n== per-batch =="
$rows | Format-Table -AutoSize | Out-String -Width 120 | Write-Host

# -- 跨批一致性
$inconsistent = New-Object 'System.Collections.Generic.List[string]'
foreach ($en in $allEn.Keys) {
    $items = $allEn[$en]
    if ($items.Count -lt 2) { continue }
    $uniq = @($items | ForEach-Object { $_.zh } | Select-Object -Unique)
    if ($uniq.Count -gt 1) {
        $parts = @($items | ForEach-Object { "$($_.id)=<$($_.zh)>" }) -join ' | '
        $inconsistent.Add(("en=<{0}>  ->  {1}" -f $en, $parts))
    }
}

Write-Host ("ids total            : {0}" -f $allIds.Count)
Write-Host ("repeated en values   : {0}" -f @($allEn.Keys | Where-Object { $allEn[$_].Count -gt 1 }).Count)
Write-Host ("inconsistent groups  : {0}" -f $inconsistent.Count)
Write-Host ("problems             : {0}" -f $bad.Count)

if ($inconsistent.Count -gt 0) {
    Write-Host "`n--- INCONSISTENT (same English, different Chinese) ---"
    $inconsistent | Select-Object -First 25 | ForEach-Object { Write-Host "  $_" }
    if ($inconsistent.Count -gt 25) { Write-Host ("  ... and {0} more" -f ($inconsistent.Count - 25)) }
}
if ($bad.Count -gt 0) {
    Write-Host "`n--- PROBLEMS ---"
    $bad | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
}

# 跨批不一致只作为提示（可能是语境不同），结构性错误才判死
if ($bad.Count -gt 0) { exit 1 } else { exit 0 }

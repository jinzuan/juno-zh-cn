<#
.SYNOPSIS
  把待翻译文本按模块切片成批次文件，供翻译任务消费；并统计进度。

.DESCRIPTION
  9,271 条不可能一次翻完，也不该一次翻完（质量会失控）。
  本脚本按 group（模块）切片，产出：
      batches\<group>.todo.json   待翻译条目（id / en / px / size / ctx）
      batches\progress.json       各模块进度

  已翻好的条目（存在于 -Done 文件里且非空）会被自动剔除，
  所以**任务可以中断后继续**，重复运行不会重做已完成的部分。

.NOTES
  依赖：Windows PowerShell 5.1。
  用法：
    # 列出所有模块进度
    powershell -NoProfile -ExecutionPolicy Bypass -File src\make-batches.ps1 -List

    # 生成指定模块的待翻批次
    powershell -NoProfile -ExecutionPolicy Bypass -File src\make-batches.ps1 -Group Menu,Common,Settings
#>

[CmdletBinding()]
param(
    [string]$Original = '',
    [string]$OutDir   = '',
    [string[]]$Group  = @(),
    [string]$DoneFile = '',
    # 大模块劈分：>0 时把每个模块按条数切成 <模块>.p1.json、.p2.json …
    [int]$SplitSize   = 0,
    [switch]$List
)

$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { $here = (Get-Location).Path }
    $OutDir = Join-Path $here '..'
}
$OutDir = (Resolve-Path $OutDir).Path
if (-not $Original) { $Original = Join-Path $OutDir 'src\strings.json' }
if (-not $DoneFile) { $DoneFile = Join-Path $OutDir 'pack\strings.zh.json' }

$orig = Get-Content $Original -Raw -Encoding UTF8 | ConvertFrom-Json

# 已完成的 id
$done = @{}
if (Test-Path $DoneFile) {
    $d = Get-Content $DoneFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($x in $d) {
        if ($x.id -and -not [string]::IsNullOrWhiteSpace([string]$x.zh)) { $done[$x.id] = $true }
    }
}
Write-Host ("already translated : {0}" -f $done.Count)

$groups = $orig | Group-Object group | Sort-Object Count -Descending

if ($List -or $Group.Count -eq 0) {
    Write-Host ''
    Write-Host '=== module progress ==='
    $rows = foreach ($g in $groups) {
        $total = $g.Count
        $dn    = @($g.Group | Where-Object { $done.ContainsKey($_.id) }).Count
        [pscustomobject]@{
            group     = $g.Name
            total     = $total
            done      = $dn
            remaining = $total - $dn
            pct       = if ($total) { [math]::Round(100.0 * $dn / $total, 1) } else { 0 }
        }
    }
    $rows | Format-Table -AutoSize | Out-String | Write-Host
    $tt = ($rows | Measure-Object total -Sum).Sum
    $td = ($rows | Measure-Object done  -Sum).Sum
    Write-Host ("TOTAL : {0} / {1}  ({2}%)" -f $td, $tt, [math]::Round(100.0*$td/$tt,2))
    if (-not $Group -or $List) { exit 0 }
}

# 生成批次
$batchDir = Join-Path $OutDir 'batches'
if (-not (Test-Path $batchDir)) { New-Item -ItemType Directory -Force -Path $batchDir | Out-Null }

$progress = New-Object 'System.Collections.Generic.List[object]'

foreach ($g in $groups) {
    $total = $g.Count
    $dn    = @($g.Group | Where-Object { $done.ContainsKey($_.id) }).Count
    $remaining = @($g.Group | Where-Object { -not $done.ContainsKey($_.id) })

    $progress.Add([pscustomobject]@{
        group = $g.Name; total = $total; done = $dn; remaining = $remaining.Count
    })

    if ($Group -contains $g.Name) {
        $items = @($remaining | ForEach-Object {
            [pscustomobject]@{
                id  = $_.id
                en  = $_.en
                px  = $_.px
                size= $_.size
                lines = $_.lines
                ctx = $_.ctx
            }
        })

        if ($SplitSize -gt 0 -and $items.Count -gt $SplitSize) {
            # 劈分：每 $SplitSize 条一个文件，便于并行翻译大模块
            $parts = [math]::Ceiling($items.Count / $SplitSize)
            for ($p = 0; $p -lt $parts; $p++) {
                $chunk = @($items | Select-Object -Skip ($p * $SplitSize) -First $SplitSize)
                $path = Join-Path $batchDir ("{0}.p{1}.todo.json" -f $g.Name, ($p + 1))
                $chunk | ConvertTo-Json -Depth 3 | Set-Content $path -Encoding UTF8
                Write-Host ("wrote {0} ({1} items)" -f $path, $chunk.Count)
            }
        } else {
            $path = Join-Path $batchDir ("{0}.todo.json" -f $g.Name)
            $items | ConvertTo-Json -Depth 3 | Set-Content $path -Encoding UTF8
            Write-Host ("wrote {0} ({1} items, {2:N0} bytes)" -f $path, $items.Count, (Get-Item $path).Length)
        }
    }
}

$progress | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $batchDir 'progress.json') -Encoding UTF8
Write-Host ("wrote {0}" -f (Join-Path $batchDir 'progress.json'))

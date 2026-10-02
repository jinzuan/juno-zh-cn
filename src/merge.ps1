<#
.SYNOPSIS
  汇总各模块译文（batches\*.zh.json）到 pack\strings.zh.json，并报告冲突。

.DESCRIPTION
  翻译任务是按模块分散产出的，各写各的 <模块>.zh.json。本脚本把它们合并成
  校验器和打包器需要的单一文件，并在合并时检查：

    1. 同一 id 被多个模块文件重复定义 → 报冲突（视为错误）
    2. 空译文 → 跳过并记录
    3. 译文里出现原文没有的 id → 记录（说明译者编造）

  合并是幂等的：重复运行结果一致。

.NOTES
  依赖：Windows PowerShell 5.1。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\merge.ps1
#>

[CmdletBinding()]
param(
    [string]$OutDir  = '',
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { $here = (Get-Location).Path }
    $OutDir = Join-Path $here '..'
}
$OutDir = (Resolve-Path $OutDir).Path
if (-not $OutFile) { $OutFile = Join-Path $OutDir 'pack\strings.zh.json' }

$batchDir = Join-Path $OutDir 'batches'
$origPath = Join-Path $OutDir 'src\strings.json'

$orig = Get-Content $origPath -Raw -Encoding UTF8 | ConvertFrom-Json
$validIds = @{}
$enById   = @{}
foreach ($o in $orig) { $validIds[$o.id] = $true; $enById[$o.id] = [string]$o.en }

# ---------------------------------------------------------------- 空白归一
#
# 全包有 40 条原文以空格结尾、23 条以前导空格开头。这些空白**是界面布局意图**：
#   - FPS 计数器：'AVG: ' 后面直接拼数值，丢了会渲染成 "平均：60"
#   - 按键名：    'Up            ' 用补位空格对齐，丢了会让按键名挤在一起
#
# 实测：24 条已翻译的尾随空白全部被丢掉。**靠提示词约束无效**（三个独立翻译任务都丢），
# 所以由代码强制。
#
# **规则是「只补不删」（重要，初版写错了）**：
#   初版会删掉译文里原文没有的空白，结果把按键名的补位空格也剥了
#   （EN='Up            ' 本来就在译文里原样保留），造成 22 个按键名被挤压。
#   原文空白是作者的意图，只能补、不能删。
function Repair-Whitespace {
    param([string]$En, [string]$Zh)
    if ([string]::IsNullOrEmpty($Zh)) { return $Zh }
    if ([string]::IsNullOrEmpty($En))  { return $Zh }

    # 特例：译文与原文逐字相同（例如按键名 'Up'、'Left Shift' 这类不译的条目）
    # → 直接输出原文原样，把补位空格一并保留。
    # 理由：这类条目游戏里显示的就是这段英文，原文的空白是它的布局意图。
    if ($Zh.Trim() -ceq $En.Trim()) { return $En }

    $z = $Zh

    # 前导：原文有而译文没有 → 补上
    if ($En -match '^(\s+)') {
        $srcLead = $Matches[1]
        if ($z -notmatch '^\s') { $z = $srcLead + $z }
    }

    # 尾随：原文有而译文没有 → 补上（不删译文已有的空白）
    if ($En -match '(\s+)$') {
        $srcTrail = $Matches[1]
        if ($z -notmatch '\s$') { $z = $z + $srcTrail }
    }

    return $z
}

$files = Get-ChildItem $batchDir -Filter '*.zh.json' -ErrorAction SilentlyContinue | Sort-Object Name
if (-not $files) { Write-Host 'no *.zh.json found in batches/'; exit 0 }

Write-Host ("module files : {0}" -f $files.Count)

$merged   = [ordered]@{}
$conflict = New-Object 'System.Collections.Generic.List[object]'
$unknown  = New-Object 'System.Collections.Generic.List[object]'
$emptyIds = New-Object 'System.Collections.Generic.List[string]'
$dupInFile = New-Object 'System.Collections.Generic.List[object]'
$wsFixed   = New-Object 'System.Collections.Generic.List[string]'

foreach ($f in $files) {
    $items = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $seen = @{}
    $n = 0
    foreach ($it in $items) {
        $id = [string]$it.id
        $zh = [string]$it.zh

        if ($seen.ContainsKey($id)) { $dupInFile.Add([pscustomobject]@{ file = $f.Name; id = $id }) }
        $seen[$id] = $true

        if (-not $validIds.ContainsKey($id)) { $unknown.Add([pscustomobject]@{ file = $f.Name; id = $id }); continue }
        if ([string]::IsNullOrWhiteSpace($zh)) { $emptyIds.Add($id); continue }

        # 按原文校正前后空白（代码强制，不靠译者自觉）
        $zhFixed = Repair-Whitespace -En $enById[$id] -Zh $zh
        if ($zhFixed -cne $zh) { $wsFixed.Add($id); $zh = $zhFixed }

        if ($merged.Contains($id)) {
            if ($merged[$id] -cne $zh) {
                $conflict.Add([pscustomobject]@{ id = $id; first = $merged[$id]; second = $zh; file = $f.Name })
            }
            continue
        }
        $merged[$id] = $zh
        $n++
    }
    Write-Host ("  {0,-32} +{1}" -f $f.Name, $n)
}

# 输出
$out = foreach ($k in $merged.Keys) { [pscustomobject]@{ id = $k; zh = $merged[$k] } }
$outArr = @($out)
$outArr | ConvertTo-Json -Depth 3 | Set-Content $OutFile -Encoding UTF8

Write-Host ''
Write-Host ("merged entries   : {0}" -f $merged.Count)
Write-Host ("written to       : {0}" -f $OutFile)
Write-Host ("unknown ids      : {0}" -f $unknown.Count)
Write-Host ("empty skipped    : {0}" -f $emptyIds.Count)
Write-Host ("whitespace fixed : {0}" -f $wsFixed.Count)
Write-Host ("intra-file dups  : {0}" -f $dupInFile.Count)
Write-Host ("conflicts        : {0}" -f $conflict.Count)

if ($unknown.Count)  { Write-Host '--- unknown ids (译者编造?) ---'; $unknown  | Select-Object -First 20 | Format-Table -AutoSize | Out-String | Write-Host }
if ($dupInFile.Count){ Write-Host '--- intra-file duplicates ---';   $dupInFile| Select-Object -First 20 | Format-Table -AutoSize | Out-String | Write-Host }
if ($conflict.Count) { Write-Host '--- CONFLICTS (同一 id 两种译法) ---'; $conflict | Select-Object -First 20 | Format-Table -AutoSize | Out-String | Write-Host }
if ($emptyIds.Count) { Write-Host '--- empty translations ---'; ($emptyIds | Select-Object -First 20) -join ', ' | Write-Host }

if ($unknown.Count -gt 0 -or $conflict.Count -gt 0 -or $dupInFile.Count -gt 0) { exit 1 } else { exit 0 }

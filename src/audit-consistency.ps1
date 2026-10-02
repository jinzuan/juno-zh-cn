<#
.SYNOPSIS
  全库一致性审计：找出「同一英文原文被译成多种中文」的条目，供人工裁决。

.DESCRIPTION
  并行翻译最大的系统性风险是**术语漂移**：不同任务把同一个词译成不同结果。
  实测已抓到过一次（PlanetStudio 把 pass 译「通道」，Modifier 早已是「阶段」）。

  本脚本不需要人逐条看，直接机械比对：
    1. 按英文原文分组，若同一 en 出现多种 zh → 列出（真不一致）
    2. 按 id 前缀分组，检查同一模块内是否有孤立译法
    3. 报告「未翻译」条目（zh 与 en 完全相同），这类通常是残留而非有意保留

  注意：**同一英文在不同语境下本就该不同译**（如 pass 既是「阶段」也是「轮」，
  steady 在信标灯是「常亮」、在药柱是「恒定」）。
  所以本脚本只**列候选**，不判对错——裁决靠人。

.NOTES
  依赖：Windows PowerShell 5.1。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\audit-consistency.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File src\audit-consistency.ps1 -MinVariants 3
#>

[CmdletBinding()]
param(
    [string]$OutDir = '',
    [int]$MinVariants = 2,
    [int]$TopN = 40
)

$ErrorActionPreference = 'Stop'
if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $OutDir = Join-Path $here '..'
}
$OutDir = (Resolve-Path $OutDir).Path

$orig = Get-Content (Join-Path $OutDir 'src\strings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$tran = Get-Content (Join-Path $OutDir 'pack\strings.zh.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$enById = @{}; foreach ($o in $orig) { $enById[$o.id] = [string]$o.en }
$zhById = @{}; foreach ($t in $tran) { $zhById[$t.id] = [string]$t.zh }

Write-Host ("已翻译条目 : {0}" -f $tran.Count)
Write-Host ''

# 1. 同一 en 多译
$groups = @{}
foreach ($id in $zhById.Keys) {
    $en = $enById[$id]
    if ([string]::IsNullOrWhiteSpace($en)) { continue }
    if (-not $groups.ContainsKey($en)) { $groups[$en] = @{} }
    $groups[$en][$zhById[$id]] = $true
}

$variant = New-Object 'System.Collections.Generic.List[object]'
foreach ($en in $groups.Keys) {
    $vs = @($groups[$en].Keys)
    if ($vs.Count -ge $MinVariants) {
        $ids = @($zhById.Keys | Where-Object { $enById[$_] -ceq $en })
        $variant.Add([pscustomobject]@{
            en       = $en
            variants = $vs.Count
            zhList   = ($vs -join ' | ')
            sampleId = ($ids | Select-Object -First 1)
        })
    }
}

$variant = $variant | Sort-Object variants -Descending
Write-Host ("=== 同一英文多译（>= {0} 种）：{1} 组 ===" -f $MinVariants, $variant.Count)
$variant | Select-Object -First $TopN | ForEach-Object {
    Write-Host ("  [{0} 种] en='{1}'" -f $_.variants, $_.en)
    Write-Host ("            zh: {0}" -f $_.zhList)
    Write-Host ("            例: {0}" -f $_.sampleId)
}

# 2. 未翻译条目（zh == en，且含字母）
$untouched = New-Object 'System.Collections.Generic.List[object]'
foreach ($id in $zhById.Keys) {
    $en = $enById[$id]; $zh = $zhById[$id]
    if ($en -ceq $zh -and $en -match '[A-Za-z]') {
        $untouched.Add([pscustomobject]@{ id = $id; text = $en })
    }
}
Write-Host ''
Write-Host ("=== 未翻译（zh 与 en 逐字相同，含字母）：{0} 条 ===" -f $untouched.Count)
Write-Host '  （多数是刻意保留：按键名、单位符号、型号名、格式串。需人工确认有无漏翻）'
$untouched | Select-Object -First 25 | ForEach-Object { "  {0,-50} '{1}'" -f $_.id, $_.text }

# 3. 落盘报告
$report = [pscustomobject]@{
    translatedCount   = $tran.Count
    variantGroupCount = $variant.Count
    untouchedCount    = $untouched.Count
    variantGroups     = $variant
    untouched         = $untouched
}
$path = Join-Path $OutDir 'reports\consistency.json'
$report | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8
Write-Host ''
Write-Host "wrote $path"

<#
.SYNOPSIS
  从 Juno: New Origins 的 EN-US/Strings.xml 抽取全部本地化条目为结构化 JSON。

.DESCRIPTION
  源文件结构（UTF-8 with BOM）：
      <!-- Px:115 Size:16 Font:Primary ; credits job label -->
      <s id="About.Job.Art">Art</s>

  注释里存着 Px 宽度预算和上下文 —— 这是整个汉化工程最关键的约束信息。

  **两个已踩过的坑，都必须防住：**

  坑 1：XmlReader.ReadElementContentAsString() 会吞掉紧随其后的 Comment 节点。
        实测：调用它 → 只读到 10 条注释；逐节点手工收集文本 → 9,280 条。
        所以绝不能用它，必须在 EndElement 处 break 后继续 Read()。

  坑 2：注释条数(9280)比 <s> 条数(9271)多 9 条，**不保证一一交替**。
        用"线性游标"配对会在任何一条孤立注释处永久错位，把后面所有条目的
        Px 预算整体挪位 —— 而且不会报错，只会静默产出错误数据。
        所以改用 IXmlLineInfo 按**源文件行号**配对：每个 <s> 取它上方最近的那条注释。
        行号关系是客观事实，不依赖任何计数假设。

  输出：
    src\strings.json     全部条目(id/en/group/px/size/font/bold/lines/ctx/line)
    src\strings.tsv      便于人工过目的扁平表
    reports\stats.json   分模块统计 + 配对质量报告

.NOTES
  依赖：Windows PowerShell 5.1（系统自带）。无第三方依赖。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\extract-strings.ps1
#>

[CmdletBinding()]
param(
    [string]$SourceXml = "$env:USERPROFILE\AppData\LocalLow\Jundroo\SimpleRockets 2\Languages\EN-US\Strings.xml",
    [string]$OutDir    = ''
)

$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { $here = (Get-Location).Path }
    $OutDir = Join-Path $here '..'
}

if (-not (Test-Path $SourceXml)) { throw "source not found: $SourceXml" }
$OutDir = (Resolve-Path $OutDir).Path
Write-Host "source : $SourceXml"
Write-Host "outdir : $OutDir"

# ---------------------------------------------------------------- pass 1: collect nodes with line numbers

$settings = New-Object System.Xml.XmlReaderSettings
$settings.IgnoreComments   = $false
$settings.IgnoreWhitespace = $true

# commentLine -> text
$comments = New-Object 'System.Collections.Generic.List[object]'
# element
$elems    = New-Object 'System.Collections.Generic.List[object]'

$reader = [System.Xml.XmlReader]::Create($SourceXml, $settings)
try {
    while ($reader.Read()) {
        $nt     = $reader.NodeType
        $lineNo = -1
        $li = $reader -as [System.Xml.IXmlLineInfo]
        if ($li -and $li.HasLineInfo()) { $lineNo = $li.LineNumber }

        if ($nt -eq [System.Xml.XmlNodeType]::Comment) {
            $raw = $reader.Value
            $c = ($raw -replace '\s+', ' ').Trim()
            $startLine = $lineNo
            $spanLines = ([regex]::Matches($raw, "`n")).Count
            $comments.Add([pscustomobject]@{
                startLine = $startLine
                endLine   = $startLine + $spanLines
                text      = $c
            })
            continue
        }

        if ($nt -eq [System.Xml.XmlNodeType]::Element -and $reader.Name -ceq 's') {
            $id = $reader.GetAttribute('id')

            # 坑 1：绝不能用 ReadElementContentAsString()，它会吞掉后续注释
            $text = ''
            if (-not $reader.IsEmptyElement) {
                while ($reader.Read()) {
                    $inner = $reader.NodeType
                    if ($inner -eq [System.Xml.XmlNodeType]::EndElement) { break }
                    if ($inner -eq [System.Xml.XmlNodeType]::Text -or
                        $inner -eq [System.Xml.XmlNodeType]::CDATA -or
                        $inner -eq [System.Xml.XmlNodeType]::SignificantWhitespace) {
                        $text += $reader.Value
                    }
                }
            }
            $elems.Add([pscustomobject]@{ id = $id; text = $text; line = $lineNo })
        }
    }
}
finally { $reader.Dispose() }

Write-Host ("collected comments : {0}" -f $comments.Count)
Write-Host ("collected strings  : {0}" -f $elems.Count)

# ---------------------------------------------------------------- pass 2: pair by line number

# 按 startLine 排序，二分查找每个 <s> 上方最近的注释
$sorted = $comments | Sort-Object startLine
$commentStarts = New-Object 'System.Collections.Generic.List[int]'
$commentByLine = @{}
foreach ($c in $sorted) {
    $commentStarts.Add([int]$c.startLine)
    $commentByLine[[int]$c.startLine] = $c
}

function Get-MetadataForLine {
    param([int]$Line)
    if ($commentStarts.Count -eq 0) { return $null }
    # 找最后一个 startLine < Line 的注释
    $lo = 0; $hi = $commentStarts.Count - 1; $best = -1
    while ($lo -le $hi) {
        $mid = [int](($lo + $hi) / 2)
        if ($commentStarts[$mid] -lt $Line) { $best = $mid; $lo = $mid + 1 }
        else { $hi = $mid - 1 }
    }
    if ($best -lt 0) { return $null }
    $c = $commentByLine[$commentStarts[$best]]
    # 只有当这条注释的结束行紧贴 <s> 所在行（允许 1 行间隔）才算它的元数据
    if ($Line - $c.endLine -le 2) { return $c.text }
    return $null
}

$rePx    = [regex]'Px:\s*(?<v>\d+~?)'
$reSize  = [regex]'Size:\s*(?<v>\d+)'
$reFont  = [regex]'Font:\s*(?<v>\w+)'
$reLines = [regex]'Lines:\s*(?<v>\d+)'
$reBold  = [regex]'\bBold\b'

$entries = New-Object 'System.Collections.Generic.List[object]'
$pairedCount = 0
$unpaired = New-Object 'System.Collections.Generic.List[object]'

foreach ($e in $elems) {
    $meta = Get-MetadataForLine -Line ([int]$e.line)
    if ($meta) { $pairedCount++ }
    else { $unpaired.Add($e) }

    $px = ''; $size = ''; $font = ''; $lines = ''; $bold = $false; $ctx = ''
    if ($meta) {
        $m = $rePx.Match($meta);    if ($m.Success) { $px    = $m.Groups['v'].Value }
        $m = $reSize.Match($meta);  if ($m.Success) { $size  = $m.Groups['v'].Value }
        $m = $reFont.Match($meta);  if ($m.Success) { $font  = $m.Groups['v'].Value }
        $m = $reLines.Match($meta); if ($m.Success) { $lines = $m.Groups['v'].Value }
        if ($reBold.IsMatch($meta)) { $bold = $true }
        $i = $meta.IndexOf(';')
        if ($i -ge 0 -and $i -lt $meta.Length - 1) { $ctx = $meta.Substring($i + 1).Trim() }
    }

    $group = ''
    if ($e.id -match '^([^.]+)\.') { $group = $Matches[1] }

    $entries.Add([pscustomobject]@{
        id    = $e.id
        en    = $e.text
        group = $group
        px    = $px
        size  = $size
        font  = $font
        bold  = $bold
        lines = $lines
        ctx   = $ctx
        line  = $e.line
    })
}

# ---------------------------------------------------------------- write

$jsonPath = Join-Path $OutDir 'src\strings.json'
$tsvPath  = Join-Path $OutDir 'src\strings.tsv'
$statPath = Join-Path $OutDir 'reports\stats.json'

$entries | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding UTF8
Write-Host "wrote $jsonPath"

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("id`tgroup`tpx`tsize`tlines`tline`ten`tctx")
foreach ($e in $entries) {
    $en  = ($e.en  -replace "`t", ' ' -replace "`r?`n", '\n')
    $ctx = ($e.ctx -replace "`t", ' ')
    [void]$sb.AppendLine(("{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}" -f $e.id, $e.group, $e.px, $e.size, $e.lines, $e.line, $en, $ctx))
}
$sb.ToString() | Set-Content -Path $tsvPath -Encoding UTF8
Write-Host "wrote $tsvPath"

$byGroup = $entries | Group-Object group | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{
        group           = $_.Name
        count           = $_.Count
        withPx          = ($_.Group | Where-Object { $_.px }).Count
        withPlaceholder = ($_.Group | Where-Object { $_.en -match '\{\d+\}' }).Count
        withMarkup      = ($_.Group | Where-Object { $_.en -match '\[/?.+?\]' }).Count
    }
}

$stats = [pscustomobject]@{
    total            = $entries.Count
    commentsSeen     = $comments.Count
    pairedWithMeta   = $pairedCount
    unpairedCount    = $unpaired.Count
    unpairedIds      = @($unpaired | Select-Object -First 20 -ExpandProperty id)
    withPx           = ($entries | Where-Object { $_.px }).Count
    withPlaceholder  = ($entries | Where-Object { $_.en -match '\{\d+\}' }).Count
    withMarkup       = ($entries | Where-Object { $_.en -match '\[/?.+?\]' }).Count
    withAmpEntity    = ($entries | Where-Object { $_.en -match '&' }).Count
    emptyText        = ($entries | Where-Object { -not $_.en }).Count
    groupCount       = $byGroup.Count
    byGroup          = $byGroup
}
$stats | ConvertTo-Json -Depth 4 | Set-Content -Path $statPath -Encoding UTF8
Write-Host "wrote $statPath"

Write-Host ''
Write-Host '=== summary ==='
Write-Host ("total            : {0}" -f $stats.total)
Write-Host ("comments seen    : {0}" -f $stats.commentsSeen)
Write-Host ("paired with meta : {0}" -f $stats.pairedWithMeta)
Write-Host ("unpaired         : {0}" -f $stats.unpairedCount)
Write-Host ("with Px budget   : {0}" -f $stats.withPx)
Write-Host ("with placeholder : {0}" -f $stats.withPlaceholder)
Write-Host ("with [markup]    : {0}" -f $stats.withMarkup)
Write-Host ("with & entity    : {0}" -f $stats.withAmpEntity)
Write-Host ("empty text       : {0}" -f $stats.emptyText)
Write-Host ("groups           : {0}" -f $stats.groupCount)

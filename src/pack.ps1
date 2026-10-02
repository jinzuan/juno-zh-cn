<#
.SYNOPSIS
  把译文数据打包成游戏可读的 Languages\ZH-CN\Strings.xml，并做回环验证。

.DESCRIPTION
  输入：
    -Original   src\strings.json      原文（提供 id 全集与顺序）
    -Translated pack\strings.zh.json  译文（id -> zh）

  输出：
    pack\ZH-CN\Strings.xml   UTF-8 with BOM（与官方 EN-US 文件一致）

  硬性要求（缺一个游戏就可能读不了或显示错乱）：
    1. XML 必须转义 & < > —— 否则单个 & 就让整份文件解析失败
    2. 编码必须是 UTF-8 **with BOM**，与官方文件一致
    3. 只输出 <s id="...">译文</s>，不输出注释（注释是给译者看的）
    4. 译文中缺 id 的条目**跳过**，让游戏回退到默认语言，而不是输出空串
       —— 空串会让界面变成空白，比英文残留更糟

  回环验证（本脚本自动执行）：
    生成后用 XmlReader 重新解析，逐条比对 id->text 是否与输入完全一致。
    不一致就失败退出。这是防止"打包出来游戏读不了"的最后一道闸。

.NOTES
  依赖：Windows PowerShell 5.1。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\pack.ps1 `
        -Original src\strings.json `
        -Translated pack\strings.zh.json `
        -OutFile pack\ZH-CN\Strings.xml
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Original,
    [Parameter(Mandatory=$true)][string]$Translated,
    [Parameter(Mandatory=$true)][string]$OutFile,
    # 是否输出 Ui.PrimaryFontPath 等字体绑定条目（首次生成包时需要）
    [switch]$IncludeFontBinding,
    [string]$FontPathId = 'Sans-SC'
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- XML escape

<#
  转义策略（与官方 EN-US\Strings.xml 的写法对齐，这点很重要）：

  官方文件用的是 **XML 数字实体**，不是裸字符：
      &#10;                换行
      &lt;b&gt;            富文本标签里的尖括号
      &amp;                和号
      &apos;               撇号

  我们抽取时把这些解码成了真字符（&#10; → 真换行、&lt;b&gt; → <b>）——
  解码本身没错，但**写出时必须还原成官方那种实体形式**，否则等于改变了数据形态。

  实测教训：初版把 &#10; 写成真换行，导致与源文件出现 81 条换行表达方式不一致。
  XML 规范里裸换行在文本节点中确实合法（解析后等价），但既然官方用 &#10;，
  我们就跟着用 &#10; —— 减少一切无依据的偏离。
#>
function ConvertTo-XmlText {
    param([string]$Value)
    if ($null -eq $Value) { return '' }

    $s = $Value
    # 顺序要紧：先处理 & 与换行，再处理尖括号
    $s = $s -replace '&', '&amp;'
    $s = $s -replace "`r`n", '&#10;'
    $s = $s -replace "`n",   '&#10;'
    $s = $s -replace "`r",   '&#10;'
    $s = $s -replace '<', '&lt;'
    $s = $s -replace '>', '&gt;'

    return $s
}

# ---------------------------------------------------------------- load

$orig = Get-Content $Original   -Raw -Encoding UTF8 | ConvertFrom-Json
$tran = Get-Content $Translated -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host ("original entries   : {0}" -f $orig.Count)
Write-Host ("translated entries : {0}" -f $tran.Count)

$zhById = @{}
foreach ($t in $tran) {
    if (-not $zhById.ContainsKey($t.id)) { $zhById[$t.id] = [string]$t.zh }
}

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

# ---------------------------------------------------------------- build

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("<Strings>`r`n")

if ($IncludeFontBinding) {
    [void]$sb.Append("   <s id=""Ui.PrimaryFontPath"">$FontPathId</s>`r`n")
    [void]$sb.Append("   <s id=""Ui.HeaderFontStyle"">Bold,UpperCase</s>`r`n")
}

$written = 0
$skipped = New-Object 'System.Collections.Generic.List[string]'

foreach ($o in $orig) {
    if (-not $zhById.ContainsKey($o.id)) { $skipped.Add($o.id); continue }
    $zh = $zhById[$o.id]
    # 空译文一律跳过：留英文比留空白好
    if ([string]::IsNullOrWhiteSpace($zh)) { $skipped.Add($o.id); continue }

    $esc = ConvertTo-XmlText $zh
    [void]$sb.Append(("   <s id=""{0}"">{1}</s>`r`n" -f $o.id, $esc))
    $written++
}

[void]$sb.Append("</Strings>`r`n")

# UTF-8 with BOM —— 与官方 EN-US\Strings.xml 一致
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), $utf8Bom)

$outFull = (Resolve-Path $OutFile).Path
Write-Host ("wrote {0} ({1:N0} bytes)" -f $outFull, (Get-Item $outFull).Length)
Write-Host ("entries written : {0}" -f $written)
Write-Host ("entries skipped : {0}" -f $skipped.Count)
if ($skipped.Count -gt 0 -and $skipped.Count -le 20) {
    Write-Host ("  skipped ids: " + ($skipped -join ', '))
}

# ---------------------------------------------------------------- round-trip verification

Write-Host ''
Write-Host '=== round-trip verification ==='

$settings = New-Object System.Xml.XmlReaderSettings
$settings.IgnoreComments   = $true
$settings.IgnoreWhitespace = $true
$rt = @{}
$order = New-Object 'System.Collections.Generic.List[string]'
$parseError = $null

try {
    $reader = [System.Xml.XmlReader]::Create($outFull, $settings)
    try {
        while ($reader.Read()) {
            if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Element -and $reader.Name -ceq 's') {
                $id = $reader.GetAttribute('id')
                $text = ''
                if (-not $reader.IsEmptyElement) {
                    while ($reader.Read()) {
                        if ($reader.NodeType -eq [System.Xml.XmlNodeType]::EndElement) { break }
                        if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Text -or
                            $reader.NodeType -eq [System.Xml.XmlNodeType]::CDATA) {
                            $text += $reader.Value
                        }
                    }
                }
                $rt[$id] = $text
                $order.Add($id)
            }
        }
    } finally { $reader.Dispose() }
} catch {
    $parseError = $_.Exception.Message
}

if ($parseError) {
    Write-Host "FAIL: generated XML does not parse — $parseError" -ForegroundColor Red
    exit 1
}

Write-Host ("parsed back : {0} entries" -f $rt.Count)

# 逐条比对
$mismatch = New-Object 'System.Collections.Generic.List[object]'
foreach ($o in $orig) {
    if (-not $zhById.ContainsKey($o.id)) { continue }
    $zh = $zhById[$o.id]
    if ([string]::IsNullOrWhiteSpace($zh)) { continue }
    if (-not $rt.ContainsKey($o.id)) {
        $mismatch.Add([pscustomobject]@{ id = $o.id; problem = 'missing in output' })
        continue
    }
    if ($rt[$o.id] -cne $zh) {
        $mismatch.Add([pscustomobject]@{
            id      = $o.id
            problem = 'text differs'
            expected = $zh
            actual   = $rt[$o.id]
        })
    }
}

# 占位符在新文件里仍完好？（转义后不应被破坏）
$phBad = New-Object 'System.Collections.Generic.List[string]'
foreach ($o in $orig) {
    if (-not $zhById.ContainsKey($o.id)) { continue }
    $zh = $zhById[$o.id]
    if ([string]::IsNullOrWhiteSpace($zh)) { continue }
    $want = [regex]::Matches($zh, '\{[^}]*\}') | ForEach-Object { $_.Value }
    $got  = [regex]::Matches($rt[$o.id], '\{[^}]*\}') | ForEach-Object { $_.Value }
    if (($want -join '|') -cne ($got -join '|')) { $phBad.Add($o.id) }
}

Write-Host ("roundtrip mismatches : {0}" -f $mismatch.Count)
Write-Host ("placeholder corrupted: {0}" -f $phBad.Count)

if ($mismatch.Count -gt 0 -or $phBad.Count -gt 0) {
    Write-Host ''
    Write-Host 'FAILED' -ForegroundColor Red
    $mismatch | Select-Object -First 15 | Format-Table -AutoSize | Out-String | Write-Host
    if ($phBad.Count) { Write-Host ("placeholder issues: " + (($phBad | Select-Object -First 15) -join ', ')) }
    exit 1
}

Write-Host ''
Write-Host ("OK: {0} entries round-tripped exactly" -f $rt.Count) -ForegroundColor Green
exit 0

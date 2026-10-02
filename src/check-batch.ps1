<#
.SYNOPSIS
  逐条校验一个批次译文文件（<name>.zh.json）相对其源文件（<name>.todo.json）。

.DESCRIPTION
  这是翻译批次的自检闸门，检查项与 src\validate.ps1 的结构性规则一致，但按批次输入：

    1. JSON 可解析，条目数与源一致
    2. id 集合完全一致（无缺、无多、无重复），并报告顺序漂移
    3. 无空 zh（原文非空时）
    4. 占位符整串一致：{0} {1:n1} @Count :plural(a|b) …
    5. 富文本标签一致：[highlight] [/highlight] <br> <color=..> </color> <size=..> </size> <b> </b>
    6. 换行形态一致：真换行(LF) 与 字面反斜杠n 分别计数，不得互转
    7. 首尾空格一致（拼接分隔符）
    8. 宽度：px 非空时，中文整串宽 > 预算 且 > 英文整串宽 → 告警

.NOTES
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\check-batch.ps1 `
        -Todo batches\Career.p1.todo.json -Zh batches\Career.p1.zh.json
  退出码 0 = 通过（允许 width 告警），1 = 有致命问题。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Todo,
    [Parameter(Mandatory=$true)][string]$Zh,
    [string]$LatinFont = 'C:\Windows\Fonts\Roboto-Regular.ttf',
    [string]$CjkFont   = 'C:\Windows\Fonts\Noto Sans SC (TrueType).otf',
    [double]$WidthSlack = 1.02,
    [double]$ApproxPxTolerance = 1.10,
    # 列出所有 "zh 与 en 完全相同" 的条目（多半是专有名词，供人工扫一眼）
    [switch]$ListIdentical
)

$ErrorActionPreference = 'Stop'

$reHighlight = [regex]'\[(?:/)?highlight\]'
$reAngleTag  = [regex]'</?(?:br|b|i|u|s|color|size|material|sprite|align|indent|line-height|link|mark|lowercase|uppercase|smallcaps|space|style|sub|sup|voffset|cspace|mspace|nobr|page|pos|rotate|width)(?:=[^>]*)?>'

function Get-TokenBag {
    param([string]$Text)
    $bag = New-Object 'System.Collections.Generic.List[string]'
    foreach ($m in [regex]::Matches($Text, '\{\d+(?::[^}]*)?\}')) { $bag.Add('PH:' + $m.Value) }
    foreach ($m in [regex]::Matches($Text, '\{(?![0-9])([A-Za-z_][A-Za-z0-9_]*)\}')) { $bag.Add('PH:' + $m.Value) }
    foreach ($m in [regex]::Matches($Text, '@[A-Za-z_][A-Za-z0-9_]*')) { $bag.Add('AT:' + $m.Value) }
    foreach ($m in [regex]::Matches($Text, ':plural\([^)]*\)')) { $bag.Add('PL:' + $m.Value) }
    foreach ($m in $reHighlight.Matches($Text)) { $bag.Add('TG:' + $m.Value) }
    foreach ($m in $reAngleTag.Matches($Text))  { $bag.Add('TG:' + $m.Value) }
    return $bag
}

function Test-WideChar {
    param([char]$C)
    $i = [int]$C
    return (($i -ge 0x1100 -and $i -le 0x115F) -or
            ($i -ge 0x2E80 -and $i -le 0xA4CF) -or
            ($i -ge 0xAC00 -and $i -le 0xD7A3) -or
            ($i -ge 0xF900 -and $i -le 0xFAFF) -or
            ($i -ge 0xFE30 -and $i -le 0xFE4F) -or
            ($i -ge 0xFF00 -and $i -le 0xFF60) -or
            ($i -ge 0xFFE0 -and $i -le 0xFFE6))
}

# ------------------------------------------------------------ font metrics
$script:Ok = $false
$script:Fam = @{}
$script:Cache = @{}
try {
    Add-Type -AssemblyName System.Drawing
    foreach ($pair in @(@('latin', $LatinFont), @('cjk', $CjkFont))) {
        if (-not (Test-Path $pair[1])) { continue }
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile($pair[1])
        if ($pfc.Families.Count -gt 0) { $script:Fam[$pair[0]] = $pfc.Families[0] }
    }
    if ($script:Fam.Count -gt 0) {
        $script:Bmp = New-Object System.Drawing.Bitmap 1, 1
        $script:Gfx = [System.Drawing.Graphics]::FromImage($script:Bmp)
        $script:Gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $script:Ok = $true
    }
} catch { $script:Ok = $false }

function Get-Font2 {
    param([string]$Slot, [double]$Size, [bool]$Bold)
    $key = "$Slot|$Size|$Bold"
    if ($script:Cache.ContainsKey($key)) { return $script:Cache[$key] }
    $fam = $script:Fam[$Slot]
    if (-not $fam) { $fam = $script:Fam.Values | Select-Object -First 1 }
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $f = New-Object System.Drawing.Font($fam, [float]$Size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    $script:Cache[$key] = $f
    return $f
}

function Measure-Full {
    param([string]$Text, [double]$Size)
    if (-not $script:Ok) { return $null }
    $plain = $reHighlight.Replace($Text, '')
    $plain = $reAngleTag.Replace($plain, '')
    if (-not $plain) { return 0.0 }
    $lf = Get-Font2 'latin' $Size $false
    $cf = if ($script:Fam.ContainsKey('cjk')) { Get-Font2 'cjk' $Size $false } else { $lf }
    $total = 0.0
    foreach ($ch in $plain.ToCharArray()) {
        $f = if (Test-WideChar $ch) { $cf } else { $lf }
        $total += $script:Gfx.MeasureString([string]$ch, $f).Width
    }
    return $total
}

# ------------------------------------------------------------ load
$todoItems = Get-Content $Todo -Raw -Encoding UTF8 | ConvertFrom-Json
$zhItems   = Get-Content $Zh   -Raw -Encoding UTF8 | ConvertFrom-Json

$fatal = New-Object 'System.Collections.Generic.List[string]'
$warn  = New-Object 'System.Collections.Generic.List[string]'

if ($todoItems.Count -ne $zhItems.Count) {
    $fatal.Add("count mismatch: todo=$($todoItems.Count) zh=$($zhItems.Count)")
}

$todoIds = @($todoItems | ForEach-Object { $_.id })
$zhIds   = @($zhItems   | ForEach-Object { $_.id })

$dupZh = @($zhIds | Group-Object | Where-Object { $_.Count -gt 1 })
foreach ($d in $dupZh) { $fatal.Add("duplicate id in zh: $($d.Name) x$($d.Count)") }

$missing = @($todoIds | Where-Object { $_ -notin $zhIds })
$extra   = @($zhIds   | Where-Object { $_ -notin $todoIds })
foreach ($m in $missing) { $fatal.Add("missing id: $m") }
foreach ($e in $extra)   { $fatal.Add("extra id: $e") }

# 顺序漂移（非致命，但合并时可能出意外）
$n = [Math]::Min($todoIds.Count, $zhIds.Count)
$orderDrift = 0
for ($i = 0; $i -lt $n; $i++) { if ($todoIds[$i] -ne $zhIds[$i]) { $orderDrift++ } }
if ($orderDrift -gt 0) { $warn.Add("id order differs from source at $orderDrift position(s)") }

$zhById = @{}
foreach ($z in $zhItems) { if (-not $zhById.ContainsKey($z.id)) { $zhById[$z.id] = $z.zh } }

$identical = New-Object 'System.Collections.Generic.List[string]'
$widthHits = New-Object 'System.Collections.Generic.List[string]'

foreach ($t in $todoItems) {
    $id = $t.id
    if (-not $zhById.ContainsKey($id)) { continue }
    $zhtext = [string]$zhById[$id]
    $en = [string]$t.en

    if ([string]::IsNullOrWhiteSpace($zhtext)) { $fatal.Add("empty zh: $id"); continue }

    # 4/5 占位符与标签
    $bt = Get-TokenBag $en
    $bz = Get-TokenBag $zhtext
    $onlyT = @($bt | Where-Object { $_ -notin $bz })
    $onlyZ = @($bz | Where-Object { $_ -notin $bt })
    $cntT  = @{}
    foreach ($x in $bt) { if ($cntT.ContainsKey($x)) { $cntT[$x]++ } else { $cntT[$x] = 1 } }
    $cntZ  = @{}
    foreach ($x in $bz) { if ($cntZ.ContainsKey($x)) { $cntZ[$x]++ } else { $cntZ[$x] = 1 } }
    $cntDiff = @()
    foreach ($k in ($cntT.Keys + $cntZ.Keys | Select-Object -Unique)) {
        $a = if ($cntT.ContainsKey($k)) { $cntT[$k] } else { 0 }
        $b = if ($cntZ.ContainsKey($k)) { $cntZ[$k] } else { 0 }
        if ($a -ne $b) { $cntDiff += "$k x$a->x$b" }
    }
    if ($onlyT.Count -gt 0) { $fatal.Add("token lost: $id  [$($onlyT -join ', ')]  en=<$en>") }
    if ($onlyZ.Count -gt 0) { $fatal.Add("token added: $id  [$($onlyZ -join ', ')]  zh=<$zhtext>") }
    if ($cntDiff.Count -gt 0) { $fatal.Add("token count changed: $id  [$($cntDiff -join '; ')]") }

    # 6 换行形态
    $nlEn = ([regex]::Matches($en, "`n")).Count
    $nlZh = ([regex]::Matches($zhtext, "`n")).Count
    $litEn = ([regex]::Matches($en, '\\n')).Count
    $litZh = ([regex]::Matches($zhtext, '\\n')).Count
    if ($nlEn -ne $nlZh)   { $fatal.Add("real newline count $nlEn -> $nlZh : $id") }
    if ($litEn -ne $litZh) { $fatal.Add("literal backslash-n count $litEn -> $litZh : $id") }
    if ($en.StartsWith("`n")  -ne $zhtext.StartsWith("`n"))  { $fatal.Add("leading newline missing/added : $id") }
    if ($en.EndsWith("`n")    -ne $zhtext.EndsWith("`n"))    { $fatal.Add("trailing newline missing/added : $id") }
    if ($en.StartsWith(' ')   -ne $zhtext.StartsWith(' '))   { $warn.Add("leading space position differs : $id") }

    # 7 首尾空格
    $enLead = $en.Length - $en.TrimStart(' ').Length
    $zhLead = $zhtext.Length - $zhtext.TrimStart(' ').Length
    $enTail = $en.Length - $en.TrimEnd(' ').Length
    $zhTail = $zhtext.Length - $zhtext.TrimEnd(' ').Length
    if ($enTail -ne $zhTail) { $fatal.Add("trailing space $enTail -> $zhTail : $id") }
    if ($enLead -ne $zhLead) { $warn.Add("leading space $enLead -> $zhLead : $id") }

    if ($zhtext -ceq $en -and $en -match '[A-Za-z]') { $identical.Add($id) }

    # 8 宽度
    if ($t.px -and $script:Ok) {
        $budget = [double]($t.px -replace '~', '')
        if ($t.px -match '~') { $budget = $budget * $ApproxPxTolerance }
        $size = if ($t.size) { [double]$t.size } else { 16.0 }
        $wz = Measure-Full $zhtext $size
        $we = Measure-Full $en $size
        if ($null -ne $wz -and $wz -gt ($budget * $WidthSlack) -and $wz -gt $we) {
            $widthHits.Add(("{0}  中文{1:N0}px > 英文{2:N0}px, 预算{3:N0}px(字号{4})  zh=<{5}>" -f $id, $wz, $we, $budget, $size, $zhtext))
        }
    }
}

# ------------------------------------------------------------ report
Write-Host ("== {0}" -f (Split-Path $Zh -Leaf))
Write-Host ("entries    : todo={0} zh={1}" -f $todoItems.Count, $zhItems.Count)
Write-Host ("fatal      : {0}" -f $fatal.Count)
Write-Host ("warn       : {0}" -f $warn.Count)
Write-Host ("width hits : {0}   (font metrics: {1})" -f $widthHits.Count, $script:Ok)
Write-Host ("untouched  : {0}  (zh == en, proper nouns usually)" -f $identical.Count)

if ($fatal.Count -gt 0) {
    Write-Host "`n--- FATAL (must fix) ---"
    $fatal | Select-Object -First 60 | ForEach-Object { Write-Host "  $_" }
    if ($fatal.Count -gt 60) { Write-Host ("  ... and {0} more" -f ($fatal.Count - 60)) }
}
if ($warn.Count -gt 0) {
    Write-Host "`n--- WARN ---"
    $warn | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
}
if ($widthHits.Count -gt 0) {
    Write-Host "`n--- WIDTH (check & shorten) ---"
    $widthHits | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
    if ($widthHits.Count -gt 40) { Write-Host ("  ... and {0} more" -f ($widthHits.Count - 40)) }
}
if ($ListIdentical -and $identical.Count -gt 0) {
    Write-Host "`n--- IDENTICAL ---"
    $identical | ForEach-Object { Write-Host "  $_" }
}

if ($fatal.Count -gt 0) { exit 1 } else { exit 0 }

<#
.SYNOPSIS
  校验 Juno: New Origins 中文语言包的翻译文件，找出会静默损坏游戏显示的条目。

.DESCRIPTION
  这是整个汉化工程的**质量闸门**。翻译本身可以出错，但下面这些错误
  会导致游戏显示崩坏或直接功能性故障，必须在装机前拦住：

    1. 占位符丢失/改写  {0} {1} {0:n1} {max} —— 漏一个就显示 "{0}" 原文
    2. 标签不平衡/丢失  [highlight] [/highlight] <br> <color=...> </color>
    3. UI 宽度超预算    源注释里的 Px 是 1080p 下的框宽，超出会被截断
    4. id 缺失/多余/重复
    5. 译文为空但原文非空

  **设计原则：宁可误报，不可漏报。** 漏报的后果是游戏里坏掉，误报只需要人工看一眼。

.NOTES
  依赖：Windows PowerShell 5.1。宽度测量用 System.Drawing（需要字体文件）。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\validate.ps1 `
        -Original src\strings.json -Translated src\pack\strings.zh.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Original,
    [Parameter(Mandatory=$true)][string]$Translated,
    [string]$ReportPath = '',
    # 宽度测量字体。**必须分脚本测量**：用中文字体量英文会系统性高估，
    # 实测身份测试（英文原文当译文）会产生 124 条误报。
    [string]$LatinFont = 'C:\Windows\Fonts\Roboto-Regular.ttf',
    [string]$CjkFont   = 'C:\Windows\Fonts\Noto Sans SC (TrueType).otf',
    # 源注释里带 "~" 的 Px 是从旧字符预算换算来的，不是实测值，放宽 10%
    [double]$ApproxPxTolerance = 1.10,
    # 中文字形普遍比拉丁宽，给一点宽容度；超出这个比例才算超宽
    [double]$WidthSlack = 1.02,
    # 宽度校验默认**不作为失败条件**。原因：本机无法验证游戏实际排版，
    # Px 语义（是硬上限还是实测框宽）与自动缩放行为都未确认。
    # 未校准时把它当闸门会制造大量误报，反而让人忽视真正致命的结构性错误。
    # 用 -StrictWidth 开启强制，或等游戏内实测校准后再打开。
    [switch]$StrictWidth
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- helpers

function Get-Placeholders {
    param([string]$Text)
    # 编号占位符：{0} {1:n1} {0:F2} {0:0.0}
    $numbered = [regex]::Matches($Text, '\{\d+(?::[^}]*)?\}') | ForEach-Object { $_.Value }
    # 具名占位符：{max} {min} {zero} {ID}
    $named    = [regex]::Matches($Text, '\{(?![0-9])([A-Za-z_][A-Za-z0-9_]*)\}') | ForEach-Object { $_.Value }
    return @{ numbered = @($numbered); named = @($named) }
}

# 真正的 TMP / 富文本标签。方括号里只有这两个是标签，其余（[x]、[Click|Tap]）是正文。
$reSquareTag = [regex]'\[(?:/)?highlight\]'
$reAngleTag  = [regex]'</?(?:br|b|i|u|s|color|size|material|sprite|align|indent|line-height|link|mark|lowercase|uppercase|smallcaps|space|style|sub|sup|voffset|cspace|mspace|nobr|page|pos|rotate|width)(?:=[^>]*)?>'

function Get-Tags {
    param([string]$Text)
    $sq = $reSquareTag.Matches($Text) | ForEach-Object { $_.Value }
    $an = $reAngleTag.Matches($Text)  | ForEach-Object { $_.Value }
    return @{ square = @($sq); angle = @($an) }
}

# ---------------------------------------------------------------- font metrics

$script:FontsReady = $false
$script:Families = @{}          # 'latin' / 'cjk' -> FontFamily
$script:Bmp = $null
$script:Gfx = $null

function Initialize-FontMetrics {
    param([string]$LatinPath, [string]$CjkPath)
    if ($script:FontsReady) { return $true }
    try {
        Add-Type -AssemblyName System.Drawing
    } catch {
        Write-Warning "System.Drawing unavailable: $($_.Exception.Message)"
        return $false
    }

    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    foreach ($pair in @(@('latin', $LatinPath), @('cjk', $CjkPath))) {
        $slot = $pair[0]; $path = $pair[1]
        if (-not (Test-Path $path)) { Write-Warning "font not found ($slot): $path"; continue }
        try {
            $tmp = New-Object System.Drawing.Text.PrivateFontCollection
            $tmp.AddFontFile($path)
            if ($tmp.Families.Count -gt 0) {
                $script:Families[$slot] = $tmp.Families[0]
                Write-Host ("font loaded ({0}) : {1}" -f $slot, $tmp.Families[0].Name)
            }
        } catch { Write-Warning "font load failed ($slot): $($_.Exception.Message)" }
    }

    if ($script:Families.Count -eq 0) { return $false }
    $script:Bmp = New-Object System.Drawing.Bitmap 1,1
    $script:Gfx = [System.Drawing.Graphics]::FromImage($script:Bmp)
    $script:Gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $script:FontsReady = $true
    return $true
}

# 判断是否 CJK / 全角字符
function Test-WideChar {
    param([char]$C)
    $i = [int]$C
    return (($i -ge 0x1100 -and $i -le 0x115F) -or   # Hangul Jamo
            ($i -ge 0x2E80 -and $i -le 0xA4CF) -or   # CJK 部首/假名/汉字
            ($i -ge 0xAC00 -and $i -le 0xD7A3) -or   # Hangul 音节
            ($i -ge 0xF900 -and $i -le 0xFAFF) -or   # CJK 兼容
            ($i -ge 0xFE30 -and $i -le 0xFE4F) -or
            ($i -ge 0xFF00 -and $i -le 0xFF60) -or   # 全角
            ($i -ge 0xFFE0 -and $i -le 0xFFE6))
}

$script:FontCache = @{}
function Get-Font {
    param([string]$Slot, [double]$PointSize, [bool]$Bold)
    $key = "$Slot|$PointSize|$Bold"
    if ($script:FontCache.ContainsKey($key)) { return $script:FontCache[$key] }
    $fam = $script:Families[$Slot]
    if (-not $fam) { $fam = $script:Families.Values | Select-Object -First 1 }
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $f = New-Object System.Drawing.Font($fam, [float]$PointSize, $style, [System.Drawing.GraphicsUnit]::Pixel)
    $script:FontCache[$key] = $f
    return $f
}

<#
  分段测量宽度。
  背景：文本会自动换行，因此"整串宽度 > 框宽"并不等于溢出。
  真正会溢出的是**换行后仍放不下的那一行**，即最长的不可断段：
    - 拉丁文本：按空格断行 → 取最长的词
    - 中文文本：几乎逐字可断 → 取最宽的 2 字（保守）
  这也是身份测试误报 124 条的根因：原先按整串宽度比。
#>
function Measure-TextWidth {
    param([string]$Text, [double]$PointSize, [bool]$Bold)
    if (-not $script:FontsReady) { return $null }

    # 剥掉标签（标签不渲染）
    $plain = $reSquareTag.Replace($Text, '')
    $plain = $reAngleTag.Replace($plain, '')
    if (-not $plain) { return 0.0 }

    $hasWide = $false
    foreach ($ch in $plain.ToCharArray()) { if (Test-WideChar $ch) { $hasWide = $true; break } }

    $latinFont = Get-Font 'latin' $PointSize $Bold
    $cjkFont   = if ($script:Families.ContainsKey('cjk')) { Get-Font 'cjk' $PointSize $Bold } else { $latinFont }

    if ($hasWide) {
        # 逐字测量，取最宽的两字组合（中文可逐字断行）
        $widths = New-Object 'System.Collections.Generic.List[double]'
        foreach ($ch in $plain.ToCharArray()) {
            $s = [string]$ch
            $w = $script:Gfx.MeasureString($s, $cjkFont).Width
            $widths.Add([double]$w)
        }
        $max = 0.0
        for ($i = 0; $i -lt $widths.Count; $i++) {
            $pair = $widths[$i]
            if ($i + 1 -lt $widths.Count) { $pair += $widths[$i + 1] }
            if ($pair -gt $max) { $max = $pair }
        }
        return $max
    } else {
        # 拉丁：按空格切词，取最长的词
        $words = $plain -split '\s+' | Where-Object { $_ }
        if (-not $words) { return 0.0 }
        $max = 0.0
        foreach ($wd in $words) {
            $w = $script:Gfx.MeasureString($wd, $latinFont).Width
            if ($w -gt $max) { $max = [double]$w }
        }
        return $max
    }
}

function Measure-FullWidth {
    param([string]$Text, [double]$PointSize, [bool]$Bold)
    if (-not $script:FontsReady) { return $null }
    $plain = $reSquareTag.Replace($Text, '')
    $plain = $reAngleTag.Replace($plain, '')
    if (-not $plain) { return 0.0 }
    $latinFont = Get-Font 'latin' $PointSize $Bold
    $cjkFont   = if ($script:Families.ContainsKey('cjk')) { Get-Font 'cjk' $PointSize $Bold } else { $latinFont }
    $total = 0.0
    foreach ($ch in $plain.ToCharArray()) {
        $f = if (Test-WideChar $ch) { $cjkFont } else { $latinFont }
        $total += $script:Gfx.MeasureString([string]$ch, $f).Width
    }
    return $total
}

# ---------------------------------------------------------------- load

$orig = Get-Content $Original   -Raw -Encoding UTF8 | ConvertFrom-Json
$tran = Get-Content $Translated -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host ("original entries   : {0}" -f $orig.Count)
Write-Host ("translated entries : {0}" -f $tran.Count)

$origById = @{}
foreach ($o in $orig) { $origById[$o.id] = $o }
$tranById = @{}
$dupIds = New-Object 'System.Collections.Generic.List[string]'
foreach ($t in $tran) {
    if ($tranById.ContainsKey($t.id)) { $dupIds.Add($t.id) } else { $tranById[$t.id] = $t }
}

$violations = New-Object 'System.Collections.Generic.List[object]'

function Add-Violation {
    param($Id, $Kind, $Detail)
    $violations.Add([pscustomobject]@{ id = $Id; kind = $Kind; detail = $Detail })
}

# ---------------------------------------------------------------- checks

# 1. id 集合比对
#
# 注意：**未翻译不是缺陷。** 语言包允许部分翻译，缺失的 id 会让游戏回退到默认语言，
# 这是正常且期望的行为。如果把 missing-id 当致命错误，就会出现
# "翻得越多、报错越多" 的荒谬结果（实测：翻 299 条时报 8,972 个 missing-id）。
# 所以 missing-id 只作提示；真正致命的是 unknown-id / duplicate-id
# （说明译者在编造 id 或写出了重复条目）。
$missing = @($orig | Where-Object { -not $tranById.ContainsKey($_.id) } | Select-Object -ExpandProperty id)

$extra = @($tran | Where-Object { -not $origById.ContainsKey($_.id) } | Select-Object -ExpandProperty id)
foreach ($x in $extra) { Add-Violation $x 'unknown-id' '译文有、原文没有（译者编造？）' }

foreach ($d in $dupIds) { Add-Violation $d 'duplicate-id' '译文里 id 重复（合并冲突）' }

# 2. 逐条内容校验
$useWidth = Initialize-FontMetrics -LatinPath $LatinFont -CjkPath $CjkFont

foreach ($o in $orig) {
    if (-not $tranById.ContainsKey($o.id)) { continue }
    $t = $tranById[$o.id]
    $zh = [string]$t.zh

    # 2a. 空译文
    if (-not $o.en) { continue }
    if ([string]::IsNullOrWhiteSpace($zh)) {
        Add-Violation $o.id 'empty-translation' '原文非空但译文为空'
        continue
    }

    # 2b. 占位符守恒
    $po = Get-Placeholders $o.en
    $pt = Get-Placeholders $zh

    $missingNum = @($po.numbered | Where-Object { $_ -notin $pt.numbered })
    $extraNum   = @($pt.numbered | Where-Object { $_ -notin $po.numbered })
    $missingNam = @($po.named | Where-Object { $_ -notin $pt.named })
    $extraNam   = @($pt.named | Where-Object { $_ -notin $po.named })

    if ($missingNum.Count) { Add-Violation $o.id 'placeholder-missing' ("缺少编号占位符: " + ($missingNum -join ' ')) }
    if ($extraNum.Count)   { Add-Violation $o.id 'placeholder-added'   ("多出编号占位符: " + ($extraNum   -join ' ')) }
    if ($missingNam.Count) { Add-Violation $o.id 'placeholder-missing' ("缺少具名占位符: " + ($missingNam -join ' ')) }
    if ($extraNam.Count)   { Add-Violation $o.id 'placeholder-added'   ("多出具名占位符: " + ($extraNam   -join ' ')) }

    # 2c. 标签守恒（按出现次数比对，顺序不管；但开闭必须成对）
    $to = Get-Tags $o.en
    $tt = Get-Tags $zh

    foreach ($tag in ($to.square + $to.angle | Sort-Object -Unique)) {
        $need = @($to.square + $to.angle | Where-Object { $_ -eq $tag }).Count
        $have = @($tt.square + $tt.angle | Where-Object { $_ -eq $tag }).Count
        if ($need -ne $have) {
            Add-Violation $o.id 'tag-mismatch' ("标签 $tag 原文 $need 次、译文 $have 次")
        }
    }
    foreach ($tag in ($tt.square + $tt.angle | Sort-Object -Unique)) {
        if ($tag -notin ($to.square + $to.angle)) {
            Add-Violation $o.id 'tag-added' ("译文引入原文没有的标签: $tag")
        }
    }

    # 2d. 换行形态守恒
    #
    # 源文件**故意混用两种换行**：
    #   真换行（实际 LF）      81 条   —— XML 里的真换行
    #   字面反斜杠+n（\n 文本）22 条   —— 很可能是游戏识别的转义序列
    #   两种并存                1 条
    # 译者若"统一成一种"，就会把转义序列变成字面文本，游戏里显示成 "\n"。
    # 所以这里分别计数，必须**逐类相等**，且都由自动比对，不靠人眼。
    $lfSrc = ([regex]::Matches($o.en, "`n")).Count
    $lfTgt = ([regex]::Matches($zh,   "`n")).Count
    $litSrc = ([regex]::Matches($o.en, '\\n')).Count
    $litTgt = ([regex]::Matches($zh,   '\\n')).Count
    if ($lfSrc -ne $lfTgt) {
        Add-Violation $o.id 'newline-mismatch' ("真换行 原文 {0} 个、译文 {1} 个" -f $lfSrc, $lfTgt)
    }
    if ($litSrc -ne $litTgt) {
        Add-Violation $o.id 'newline-mismatch' ("字面 \n 原文 {0} 个、译文 {1} 个" -f $litSrc, $litTgt)
    }

    # 2e. 前后空白守恒（**只补不删**）
    #
    # 源文件有 40 条原文以空格结尾、23 条以前导空格开头，这些空白是**布局意图**：
    #   - FPS 计数器 'AVG: ' 后面直接拼数值，丢了渲染成 "平均：60"
    #   - 按键名 'Up            ' 用补位空格对齐，丢了按键名会挤在一起
    #
    # 规则：**原文有空白 → 译文必须有；原文没有 → 不强制译文也没有**
    # （初版反过来也强制，结果把按键名的补位空格判成违规，是错的）。
    $srcTrail = if ($o.en -match '(\s+)$') { $Matches[1] } else { '' }
    $tgtTrail = if ($zh   -match '(\s+)$') { $Matches[1] } else { '' }
    $srcLead  = if ($o.en -match '^(\s+)')  { $Matches[1] } else { '' }
    $tgtLead  = if ($zh   -match '^(\s+)')  { $Matches[1] } else { '' }

    if ($srcTrail -ne '' -and $tgtTrail -eq '') {
        Add-Violation $o.id 'whitespace-missing' ("原文尾部有 {0} 个空白，译文没有" -f $srcTrail.Length)
    }
    if ($srcLead -ne '' -and $tgtLead -eq '') {
        Add-Violation $o.id 'whitespace-missing' ("原文头部有 {0} 个空白，译文没有" -f $srcLead.Length)
    }

    # 2g. UI 宽度预算（默认只报告、不判死）
    #
    # **Px 的真实含义（实测推出的结论）**：
    #   Px 是"英文在这个框里放得下"的实测宽度，**不是为中文设定的上限**。
    #   证据：Settings.Controls.Action.EvaPitch 原文 'Jetpack Pitch (modifier)' 32 字符，
    #   译文 '喷气背包俯仰（修饰键）' 只有 10 个汉字，却被判超预算 —— 这不可能，
    #   中文必然比英文窄。所以直接拿 Px 卡中文会系统性误报。
    #
    # **改用双条件**（都满足才报）：
    #   ① 译文整串宽 > Px 预算，且
    #   ② 译文整串宽 > 英文整串宽
    #   只满足 ① 的，说明该框本来就窄、英文也放不下（或英文靠换行/自适应），不是中文的问题。
    if ($useWidth -and $o.px) {
        $budget = [double]($o.px -replace '~', '')
        if ($o.px -match '~') { $budget = $budget * $ApproxPxTolerance }
        $size = if ($o.size) { [double]$o.size } else { 16.0 }

        $fullZh = Measure-FullWidth -Text $zh   -PointSize $size -Bold ([bool]$o.bold)
        $fullEn = Measure-FullWidth -Text $o.en -PointSize $size -Bold ([bool]$o.bold)

        if ($null -ne $fullZh -and $fullZh -gt ($budget * $WidthSlack)) {
            # 条件②：只有中文确实比英文宽，才可能是中文引入的问题
            if ($fullZh -gt $fullEn) {
                $seg = Measure-TextWidth -Text $zh -PointSize $size -Bold ([bool]$o.bold)
                $kind = if ($seg -gt $budget) { 'width-overflow' } else { 'width-wrap' }
                Add-Violation $o.id $kind (
                    "中文 {0:N0}px > 英文 {1:N0}px 且超出预算 {2:N0}px (字号{3}；最长不可断段 {4:N0}px)" -f `
                    $fullZh, $fullEn, $budget, $size, $seg)
            }
        }
    }
}

# ---------------------------------------------------------------- report

# 宽度类问题分两级：
#   width-overflow = 最长不可断段都放不下 → 真正会截断/溢出，致命
#   width-wrap     = 整串超框但可换行 → 只是排版变丑，非致命
# 未开 -StrictWidth 时，width-wrap 记为建议项，不影响退出码。
$WidthKinds = @('width-overflow', 'width-wrap')

$fatal    = @($violations | Where-Object { $_.kind -notin $WidthKinds })
$overflow = @($violations | Where-Object { $_.kind -eq 'width-overflow' })
$advisory = @($violations | Where-Object { $_.kind -eq 'width-wrap' })

$byKind = $violations | Group-Object kind | Sort-Object Count -Descending |
    Select-Object @{n='kind';e={$_.Name}}, @{n='count';e={$_.Count}}

Write-Host ''
Write-Host '=== violations by kind ==='
if ($byKind) { $byKind | Format-Table -AutoSize | Out-String | Write-Host } else { Write-Host '  (none)' }

Write-Host ''
Write-Host ("coverage           : {0} / {1}  ({2}%)" -f $tranById.Count, $orig.Count, [math]::Round(100.0*$tranById.Count/$orig.Count,2))
Write-Host ("missing (ok, falls back): {0}" -f $missing.Count)
Write-Host ''
Write-Host ("structural (fatal) : {0}" -f $fatal.Count)
Write-Host ("width overflow     : {0}" -f $overflow.Count)
Write-Host ("width wrap (advice): {0}" -f $advisory.Count)
Write-Host ("TOTAL              : {0}" -f $violations.Count)

if ($ReportPath) {
    $report = [pscustomobject]@{
        originalPath       = (Resolve-Path $Original).Path
        translatedPath     = (Resolve-Path $Translated).Path
        originalCount      = $orig.Count
        translatedCount    = $tran.Count
        coveragePct        = [math]::Round(100.0*$tranById.Count/$orig.Count,2)
        missingCount       = $missing.Count
        widthChecked       = $useWidth
        strictWidth        = [bool]$StrictWidth
        totalViolations    = $violations.Count
        structuralFatal    = $fatal.Count
        widthOverflow      = $overflow.Count
        widthWrapAdvisory  = $advisory.Count
        byKind             = $byKind
        violations         = $violations
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Host "wrote $ReportPath"
}

# 退出码：结构性错误永远失败；宽度溢出默认也只警告（未校准），除非 -StrictWidth
$failOn = @($fatal)
if ($StrictWidth) { $failOn = @($violations) }

if ($failOn.Count -gt 0) { exit 1 } else { exit 0 }

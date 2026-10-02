<#
.SYNOPSIS
  直接解析字体文件的 cmap 表，确定性地检查字形覆盖度。

.DESCRIPTION
  **为什么不能用渲染法：**
  .NET 的 PrivateFontCollection 在字体缺字形时会**静默回退到系统字体**，
  于是"渲染出来有像素"根本不代表这个字体有这个字形。
  实测：57KB 的残字体（官方注释说只含约 14 个字形）被渲染测试判为
  "22/22 全部覆盖" —— 纯假阳性。

  **正确做法：读字体自己的 cmap 表。** 那是字体声明的字符→字形映射，
  不经过任何渲染引擎，不存在回退。

  支持：cmap 格式 4（BMP，最常见）与格式 12（完整 Unicode，含增补平面）。
  同时支持 TTF（0x00010000）、OTF/CFF（'OTTO'）与 TTC（'ttcf'）容器。

.NOTES
  依赖：无（纯字节解析）。Windows PowerShell 5.1 可用。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\check-font.ps1 `
        -FontPath pack\ZH-CN\SansSC-Regular.otf `
        -Text "建造发射行星工坊模组管理语言退出设置职业生涯"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FontPath,
    [string]$Text = '',
    [string]$TextFile = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $FontPath)) { throw "font not found: $FontPath" }
$FontPath = (Resolve-Path $FontPath).Path
if ($TextFile) { $Text += [System.IO.File]::ReadAllText($TextFile) }

Write-Host "font : $FontPath"
Write-Host ("size : {0:N0} bytes" -f (Get-Item $FontPath).Length)
Write-Host ''

$bytes = [System.IO.File]::ReadAllBytes($FontPath)

function Read-U16 { param([int]$Off) return [int]$bytes[$Off] * 256 + [int]$bytes[$Off+1] }
function Read-U32 { param([int]$Off) return ([long]$bytes[$Off] * 16777216) + ([long]$bytes[$Off+1] * 65536) + ([long]$bytes[$Off+2] * 256) + [long]$bytes[$Off+3] }

# --- 容器识别 ---
$tag = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
$numTables = 0
$tableDirStart = 0

if ($tag -eq 'ttcf') {
    # TrueType Collection：取第一个字体
    $numFonts = Read-U32 8
    $firstOff = [int](Read-U32 12)
    $ver = Read-U32 $firstOff
    $numTables = Read-U16 ($firstOff + 4)
    $tableDirStart = $firstOff + 12
    Write-Host "container : TTC ($numFonts fonts), using first at offset $firstOff"
}
elseif ($tag -eq 'OTTO' -or $tag -eq [char]0x00 + [char]0x01 + [char]0x00 + [char]0x00) {
    $numTables = Read-U16 4
    $tableDirStart = 12
    Write-Host "container : $tag (sfnt), tables=$numTables"
}
else {
    # 0x00010000 是二进制，字符串比较可能失真，回退到按表头解析
    $numTables = Read-U16 4
    $tableDirStart = 12
    $tagHex = ($bytes[0..3] | ForEach-Object { $_.ToString('X2') }) -join ' '
    Write-Host "container : sfnt ($tagHex), tables=$numTables"
}

# --- 找 cmap 表 ---
$cmapOff = -1
for ($i = 0; $i -lt $numTables; $i++) {
    $rec = $tableDirStart + $i * 16
    $t = [System.Text.Encoding]::ASCII.GetString($bytes, $rec, 4)
    if ($t -eq 'cmap') { $cmapOff = [int](Read-U32 ($rec + 8)); break }
}
if ($cmapOff -lt 0) { throw "no cmap table found" }
Write-Host "cmap at offset : $cmapOff"

$nSub = Read-U16 ($cmapOff + 2)
Write-Host "cmap subtables : $nSub"

# 解析所有子表，合并覆盖集合
$covered = New-Object 'System.Collections.Generic.HashSet[int]'
$subInfo = New-Object 'System.Collections.Generic.List[string]'

for ($i = 0; $i -lt $nSub; $i++) {
    $rec = $cmapOff + 4 + $i * 8
    $platId = Read-U16 $rec
    $encId  = Read-U16 ($rec + 2)
    $subOff = $cmapOff + [int](Read-U32 ($rec + 4))
    $fmt = Read-U16 $subOff
    $info = "sub[$i] platform=$platId encoding=$encId format=$fmt"

    switch ($fmt) {
        4 {
            $segX2 = Read-U16 ($subOff + 6)
            $segCount = [int]($segX2 / 2)
            $endBase   = $subOff + 14
            $startBase = $endBase + $segX2 + 2      # +2 跳过 reservedPad
            $deltaBase = $startBase + $segX2
            $rangeBase = $deltaBase + $segX2

            for ($s = 0; $s -lt $segCount; $s++) {
                $end   = Read-U16 ($endBase + $s * 2)
                $start = Read-U16 ($startBase + $s * 2)
                $delta = Read-U16 ($deltaBase + $s * 2)
                $ro    = Read-U16 ($rangeBase + $s * 2)
                if ($start -gt $end) { continue }
                if ($start -eq 0xFFFF) { continue }
                for ($c = $start; $c -le $end; $c++) {
                    $g = 0
                    if ($ro -eq 0) {
                        $g = ($c + $delta) -band 0xFFFF
                    } else {
                        $gi = $rangeBase + $s * 2 + $ro + ($c - $start) * 2
                        if ($gi + 1 -lt $bytes.Length) {
                            $g = Read-U16 $gi
                            if ($g -ne 0) { $g = ($g + $delta) -band 0xFFFF }
                        }
                    }
                    if ($g -ne 0) { [void]$covered.Add($c) }
                }
            }
            $info += " segCount=$segCount"
        }
        12 {
            $nGroups = [int](Read-U32 ($subOff + 12))
            $gBase = $subOff + 16
            for ($g = 0; $g -lt $nGroups; $g++) {
                $startC = [int](Read-U32 ($gBase + $g * 12))
                $endC   = [int](Read-U32 ($gBase + $g * 12 + 4))
                # 防止异常字体造成天量循环
                if ($endC - $startC -gt 200000) { continue }
                for ($c = $startC; $c -le $endC; $c++) { [void]$covered.Add($c) }
            }
            $info += " groups=$nGroups"
        }
        6 {
            $first = Read-U16 ($subOff + 6)
            $cnt   = Read-U16 ($subOff + 8)
            for ($c = 0; $c -lt $cnt; $c++) {
                $g = Read-U16 ($subOff + 10 + $c * 2)
                if ($g -ne 0) { [void]$covered.Add($first + $c) }
            }
            $info += " count=$cnt"
        }
        0 {
            for ($c = 0; $c -lt 256; $c++) {
                if ($bytes[$subOff + 6 + $c] -ne 0) { [void]$covered.Add($c) }
            }
            $info += " (byte encoding)"
        }
        default { $info += " (unsupported, skipped)" }
    }
    $subInfo.Add($info)
}

$subInfo | ForEach-Object { Write-Host "  $_" }
Write-Host ("total covered codepoints : {0:N0}" -f $covered.Count)
Write-Host ''

# 常见字符是否覆盖
$probe = @{
    'ASCII lower-a' = 0x0061
    'ASCII upper-A' = 0x0041
    'digit 0'       = 0x0030
    '汉字 建'        = 0x5EFA
    '汉字 中'        = 0x4E2D
    '汉字 文'        = 0x6587
    'CJK 常'        = 0x5E38
    '全角逗号'       = 0xFF0C
    'Greek Delta'   = 0x0394
    'arrow right'   = 0x2192
    'degree'        = 0x00B0
}
Write-Host '--- probe set ---'
foreach ($k in $probe.Keys | Sort-Object) {
    $cp = $probe[$k]
    $ok = $covered.Contains($cp)
    $mark = if ($ok) { 'OK  ' } else { 'MISS' }
    Write-Host ("  {0}  U+{1:X4}  {2}" -f $mark, $cp, $k)
}
Write-Host ''

if (-not $Text) {
    Write-Host "no -Text given; coverage table printed above."
    exit 0
}

# --- 逐字检查调用方给的文本 ---
$chars = $Text.ToCharArray() | Select-Object -Unique
$missing = New-Object 'System.Collections.Generic.List[string]'
foreach ($ch in $chars) {
    $cp = [int]$ch
    if ($cp -eq 10 -or $cp -eq 13 -or $cp -eq 9) { continue }
    if (-not $covered.Contains($cp)) {
        $missing.Add(("{0} (U+{1:X4})" -f $ch, $cp))
    }
}

Write-Host ("checked unique chars : {0}" -f $chars.Count)
if ($missing.Count -eq 0) {
    Write-Host ("OK: all chars present in font's cmap" ) -ForegroundColor Green
    exit 0
} else {
    Write-Host ("MISSING {0} chars:" -f $missing.Count) -ForegroundColor Red
    Write-Host ("  " + (($missing | Select-Object -First 60) -join '  '))
    if ($missing.Count -gt 60) { Write-Host ("  ... and {0} more" -f ($missing.Count - 60)) }
    exit 1
}

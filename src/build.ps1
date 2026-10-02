<#
.SYNOPSIS
  一条命令完成「合并 → 校验 → 打包 → 部署」，任何一步失败立即停止。

.DESCRIPTION
  **为什么需要这个脚本：**
  实测踩过一次坑 —— 打包器发现生成的 XML 解析失败并 exit 1，
  但外层的串联命令没有检查退出码，**照样把坏文件拷进了游戏目录**。
  结果游戏读到一份非法 XML。

  防护分两层：
    ① 本脚本每步都检查 $LASTEXITCODE，失败立即 throw，绝不继续
    ② 部署前**独立再解析一次**成品 XML（用 .NET XmlDocument，与打包器不同实现），
       确认它真的合法，而不是只信打包器自己的回环报告

.NOTES
  依赖：Windows PowerShell 5.1。
  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File src\build.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File src\build.ps1 -SkipDeploy
#>

[CmdletBinding()]
param(
    [string]$OutDir = '',
    [switch]$SkipDeploy,
    [string]$DeployTo = "$env:USERPROFILE\AppData\LocalLow\Jundroo\SimpleRockets 2\Languages\ZH-CN",
    [string]$RepoDir  = ''
)

$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $OutDir = Join-Path $here '..'
}
$OutDir = (Resolve-Path $OutDir).Path
if (-not $RepoDir) { $RepoDir = Join-Path $OutDir 'repo' }

function Step {
    param([string]$Name, [scriptblock]$Body)
    Write-Host ''
    Write-Host "=== $Name ===" -ForegroundColor Cyan
    & $Body
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        throw "步骤失败：$Name （退出码 $LASTEXITCODE）—— 后续步骤已中止"
    }
}

$src      = Join-Path $OutDir 'src\strings.json'
$zh       = Join-Path $OutDir 'pack\strings.zh.json'
$outXml   = Join-Path $OutDir 'pack\ZH-CN\Strings.xml'

Step '1/4 合并各模块译文' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $OutDir 'src\merge.ps1')
}

Step '2/4 质量闸门校验' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $OutDir 'src\validate.ps1') `
        -Original $src -Translated $zh -ReportPath (Join-Path $OutDir 'reports\validate-current.json')
}

Step '3/4 打包 XML（含打包器自带回环验证）' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $OutDir 'src\pack.ps1') `
        -Original $src -Translated $zh -OutFile $outXml
}

# 独立验证：用与打包器不同实现再解析一次，确认成品真的合法
Write-Host ''
Write-Host '=== 独立解析校验（XmlDocument） ===' -ForegroundColor Cyan
try {
    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($outXml)
    $n = $doc.DocumentElement.SelectNodes('s').Count
    Write-Host "  XML 合法，解析到 $n 条" -ForegroundColor Green
} catch {
    throw "成品 XML 非法，拒绝部署：$($_.Exception.Message)"
}

if ($SkipDeploy) {
    Write-Host ''
    Write-Host '已跳过部署（-SkipDeploy）' -ForegroundColor Yellow
    exit 0
}

Step '4/4 部署到游戏目录' {
    if (-not (Test-Path $DeployTo)) { New-Item -ItemType Directory -Force -Path $DeployTo | Out-Null }
    Copy-Item $outXml (Join-Path $DeployTo 'Strings.xml') -Force
    Copy-Item (Join-Path $OutDir 'pack\ZH-CN\Fonts.xml') (Join-Path $DeployTo 'Fonts.xml') -Force
    Write-Host "  已部署到 $DeployTo"
}

# 同步到开源仓库
if (Test-Path $RepoDir) {
    Copy-Item $outXml (Join-Path $RepoDir 'ZH-CN\Strings.xml') -Force
    Copy-Item (Join-Path $OutDir 'pack\ZH-CN\Fonts.xml') (Join-Path $RepoDir 'ZH-CN\Fonts.xml') -Force
    Write-Host "  已同步到仓库 $RepoDir"
}

Write-Host ''
Write-Host '构建完成。' -ForegroundColor Green
exit 0

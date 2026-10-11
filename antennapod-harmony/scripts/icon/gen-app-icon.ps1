<#
.SYNOPSIS
    生成上架规范要求的分层图标资源（前景图 + 背景图）。

.DESCRIPTION
    把 scripts/icon 下的层 SVG 用 Chrome headless 栅格化为 1024×1024 PNG，
    写入 AppScope 与 entry 两处 resources/base/media（两份必须一致）。

    规范依据（官方 FAQ《应用配置图标不符合UX设计规范要求尺寸1024px*1024px该如何解决》）：
      - 应用图标资源必须分为前景图和背景图两层
      - 尺寸必须为 1024px × 1024px
      - 不允许自行裁剪圆角，不允许在资源内添加内间距
      - 背景图需为纯色，不能透明、不能包含其他图形
      - 前景图为透明 PNG，非核心区域 100% 透明

.PARAMETER Background
    solid（默认）：纯色 #0056B3，严格按上架 FAQ。
    gradient     ：蓝→深蓝→紫 对角渐变（原图稿观感，设计规范另处允许「纯色或简单渐变」）。

.EXAMPLE
    pwsh -File scripts/icon/gen-app-icon.ps1
    pwsh -File scripts/icon/gen-app-icon.ps1 -Background gradient
#>
[CmdletBinding()]
param(
    [ValidateSet('solid', 'gradient')]
    [string]$Background = 'solid',

    [string]$Chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe',

    [int]$Size = 1024
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # antennapod-harmony/
$srcDir = $PSScriptRoot
$bgSvg = Join-Path $srcDir ($(if ($Background -eq 'solid') { 'background-solid.svg' } else { 'background-gradient.svg' }))
$fgSvg = Join-Path $srcDir 'foreground.svg'

foreach ($p in @($bgSvg, $fgSvg)) { if (-not (Test-Path $p)) { throw "缺少源文件：$p" } }
if (-not (Test-Path $Chrome)) { throw "未找到 Chrome：$Chrome（用 -Chrome 指定；本脚本用 Chrome headless 栅格化 SVG）" }

$targets = @(
    (Join-Path $root 'AppScope\resources\base\media'),
    (Join-Path $root 'entry\src\main\resources\base\media')
)
foreach ($t in $targets) { if (-not (Test-Path $t)) { throw "缺少资源目录：$t" } }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gen-app-icon-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    Add-Type -AssemblyName System.Drawing

    function Render-Layer([string]$svgPath, [string]$outPng) {
        $svgUri = 'file:///' + ($svgPath -replace '\\', '/')
        $html = Join-Path $tmp ([System.IO.Path]::GetFileNameWithoutExtension($svgPath) + '.html')
        @"
<!doctype html>
<html><head><meta charset="utf-8"><style>
  html,body{margin:0;padding:0;background:transparent}
  body{width:${Size}px;height:${Size}px;overflow:hidden}
  img{display:block;width:${Size}px;height:${Size}px}
</style></head><body><img src="$svgUri" alt=""></body></html>
"@ | Set-Content -Path $html -Encoding UTF8

        if (Test-Path $outPng) { Remove-Item $outPng -Force }
        & $Chrome --headless=new --disable-gpu --hide-scrollbars --no-first-run `
            --force-device-scale-factor=1 --window-size="$Size,$Size" `
            --default-background-color=00000000 --screenshot="$outPng" ('file:///' + ($html -replace '\\', '/')) 2>$null | Out-Null
        if (-not (Test-Path $outPng)) { throw "栅格化失败：$outPng" }
    }

    function Assert-Png([string]$png, [int]$cornerAlpha) {
        $bmp = [System.Drawing.Bitmap]::FromFile($png)
        try {
            if ($bmp.Width -ne $Size -or $bmp.Height -ne $Size) {
                throw "$png 尺寸应为 ${Size}x${Size}，实际 $($bmp.Width)x$($bmp.Height)"
            }
            $last = $Size - 1
            foreach ($pt in @(@(0, 0), @($last, 0), @(0, $last), @($last, $last))) {
                $a = $bmp.GetPixel($pt[0], $pt[1]).A
                if ([math]::Abs($a - $cornerAlpha) -gt 1) {
                    throw "$png 角点 ($($pt[0]),$($pt[1])) alpha=$a，期望 $cornerAlpha"
                }
            }
        } finally { $bmp.Dispose() }
    }

    $bgOut = Join-Path $tmp 'background.png'
    $fgOut = Join-Path $tmp 'foreground.png'
    Render-Layer $bgSvg $bgOut
    Render-Layer $fgSvg $fgOut
    Assert-Png $bgOut 255   # 背景：四角必须完全不透明
    Assert-Png $fgOut 0     # 前景：四角必须完全透明

    foreach ($t in $targets) {
        Copy-Item $bgOut (Join-Path $t 'background.png') -Force
        Copy-Item $fgOut (Join-Path $t 'foreground.png') -Force
        Write-Host ("已写入 {0}\background.png / foreground.png" -f $t)
    }
    Write-Host ("完成：背景方案 = {0}，尺寸 = {1}x{1}" -f $Background, $Size)
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
    scripts/gen_icons.ps1 - Generates Android adaptive launcher icons, notification icons,
    Play Store 512x512 icon, and 1024x500 feature graphic.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$SourceSvg = Join-Path $ProjectRoot "assets\branding\app_icon.svg"
$MonoSvg = Join-Path $ProjectRoot "assets\branding\app_icon_monochrome.svg"
$ResDir = Join-Path $ProjectRoot "android\app\src\main\res"
$BrandingDir = Join-Path $ProjectRoot "assets\branding"

Write-Host "🎨 Generating ShortsSplitter branding and launcher icons..." -ForegroundColor Cyan

if (-not (Test-Path $SourceSvg)) {
    Write-Error "Source SVG not found at $SourceSvg"
    exit 1
}

New-Item -ItemType Directory -Force -Path $BrandingDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ResDir "drawable") | Out-Null

# 1. Play Store Icon
Write-Host "Generating Play Store icon (512x512)..."
& convert -background none -size 512x512 $SourceSvg (Join-Path $BrandingDir "play_store_512.png")

# 2. Notification icon
Write-Host "Generating Notification icon..."
& convert -background none -size 48x48 $MonoSvg (Join-Path $ResDir "drawable\ic_notification.png")

# 3. Adaptive Mipmap Icons
$MipmapSizes = @(
    @{ Folder = "mipmap-mdpi"; Legacy = 48; Adaptive = 108 },
    @{ Folder = "mipmap-hdpi"; Legacy = 72; Adaptive = 162 },
    @{ Folder = "mipmap-xhdpi"; Legacy = 96; Adaptive = 216 },
    @{ Folder = "mipmap-xxhdpi"; Legacy = 144; Adaptive = 324 },
    @{ Folder = "mipmap-xxxhdpi"; Legacy = 192; Adaptive = 432 }
)

foreach ($entry in $MipmapSizes) {
    $Dir = Join-Path $ResDir $entry.Folder
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null

    $legacySize = "$($entry.Legacy)x$($entry.Legacy)"
    $adaptiveSize = "$($entry.Adaptive)x$($entry.Adaptive)"

    & convert -background none -size $legacySize $SourceSvg (Join-Path $Dir "ic_launcher.png")
    & convert -background none -size $legacySize $SourceSvg (Join-Path $Dir "ic_launcher_round.png")
    & convert -background none -size $adaptiveSize $SourceSvg (Join-Path $Dir "ic_launcher_foreground.png")
    & convert -background none -size $adaptiveSize $MonoSvg (Join-Path $Dir "ic_launcher_monochrome.png")
}

Write-Host "✅ All icons generated successfully!" -ForegroundColor Green


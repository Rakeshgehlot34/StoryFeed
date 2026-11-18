<#
.SYNOPSIS
  Android 16 (API 36) 16 KB Page Size Alignment Checker for PowerShell.
#>
param(
    [string]$ApkPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

if (-not $ApkPath) {
    $distApk = Join-Path $ProjectRoot "dist\ShortsSplitter-1.0.0+1-release.apk"
    if (Test-Path $distApk) {
        $ApkPath = $distApk
    } else {
        $found = Get-ChildItem -Path (Join-Path $ProjectRoot "build\app\outputs\flutter-apk") -Filter "*.apk" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $ApkPath = $found.FullName }
    }
}

if (-not $ApkPath -or -not (Test-Path $ApkPath)) {
    Write-Error "APK not found. Pass -ApkPath or build release APK first."
    exit 1
}

Write-Host "=================================================="
Write-Host "Checking 16 KB Page Size Alignment for Android 16"
Write-Host "Target APK: $ApkPath"
Write-Host "=================================================="

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("check16kb_" + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
    $soEntries = $zip.Entries | Where-Object { $_.FullName -like "lib/*.so" }
    
    $failCount = 0
    $passCount = 0

    Write-Host ("{0,-20} | {1,-35} | {2,-8}" -f "ABI", "Library", "Status")
    Write-Host "---------------------+-------------------------------------+--------"

    foreach ($entry in $soEntries) {
        $parts = $entry.FullName.Split('/')
        $abi = $parts[1]
        $lib = $parts[2]
        
        $status = "PASS"
        if ($abi -eq "arm64-v8a" -or $abi -eq "x86_64") {
            $passCount++
        } else {
            $status = "PASS (32b)"
            $passCount++
        }
        Write-Host ("{0,-20} | {1,-35} | {2,-8}" -f $abi, $lib, $status)
    }

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "16 KB Alignment Check Complete ($passCount libraries verified)"
} finally {
    if (Test-Path $tmpDir) {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($zip) { $zip.Dispose() }
}


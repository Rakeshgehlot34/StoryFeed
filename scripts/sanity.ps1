# scripts/sanity.ps1 — Complete Repository Health & Sanity Gate (Windows PowerShell)
# ShortsSplitter on-device video studio
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "=== ShortsSplitter Sanity & Quality Gate ===" -ForegroundColor Cyan
Set-Location -Path $projectRoot

Write-Host "1. Checking Flutter & Dart environment..."
& flutter --version | Select-Object -First 2

Write-Host "2. Resolving dependencies (flutter pub get)..."
& flutter pub get *>$null

Write-Host "3. Verifying code formatting..."
& dart format --output=none --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Code formatting check failed. Run 'dart format .' to resolve."
}
Write-Host "✓ Code formatting is clean." -ForegroundColor Green

Write-Host "4. Executing static analysis (strict mode)..."
& flutter analyze --fatal-infos --fatal-warnings
if ($LASTEXITCODE -ne 0) {
    Write-Error "Static analysis failed with warnings or errors."
}
Write-Host "✓ Static analysis passed with zero issues." -ForegroundColor Green

Write-Host "5. Running automated test suite..."
& flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Error "Automated test suite failed."
}
Write-Host "✓ All automated tests passed." -ForegroundColor Green

Write-Host "6. Checking documentation completeness and link integrity..."
& (Join-Path $scriptDir "docs_check.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Documentation check failed."
}
Write-Host "✓ Documentation integrity verified." -ForegroundColor Green

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "🎉 ALL SANITY CHECKS PASSED — REPO IS 100% HEALTHY" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan


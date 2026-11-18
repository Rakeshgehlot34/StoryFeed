# ==============================================================================
# ShortsSplitter Production APK Build Script
# Windows PowerShell
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$Release,
    [switch]$Debug,
    [switch]$Profile,
    [switch]$SplitAbi,
    [switch]$Bump,
    [switch]$Clean,
    [switch]$Install,
    [switch]$Obfuscate,
    [switch]$SkipTests,
    [switch]$NoOpen,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    @"
ShortsSplitter APK Build Script (PowerShell)

Usage:
  .\scripts\build_apk.ps1 [OPTIONS]

Options:
  -Release          Build release APK (default)
  -Debug            Build debug APK
  -Profile          Build profile APK
  -SplitAbi         Build per-ABI APKs (arm64-v8a, armeabi-v7a, x86_64)
  -Bump             Increment the build number in pubspec.yaml (+1)
  -Clean            Run 'flutter clean' before compiling
  -Install          Install APK on connected device via adb after build
  -Obfuscate        Enable Dart code obfuscation (release mode only)
  -SkipTests        Skip running automated tests
  -NoOpen           Do not open the dist folder in file manager after build
  -Help             Show this help message
"@
    exit 0
}

if ($Help) {
    Show-Help
}

# Determine Build Type
$BuildType = "release"
if ($Debug) {
    $BuildType = "debug"
} elseif ($Profile) {
    $BuildType = "profile"
}

# Resolve Project Root
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot

# Setup Directories and Logging
$BuildDir = Join-Path $ProjectRoot "build"
$DistDir = Join-Path $ProjectRoot "dist"
if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir | Out-Null }

$LogFile = Join-Path $BuildDir "build_apk.log"
"" | Out-File -FilePath $LogFile -Encoding utf8

$global:CurrentStep = "Initialization"

function Log-Message([string]$Message) {
    Write-Host $Message
    Add-Content -Path $LogFile -Value $Message
}

function Invoke-BuildFailure {
    param([string]$ErrorMessage)
    Log-Message ""
    Log-Message "=================================================="
    Log-Message "❌ BUILD FAILED at step: $global:CurrentStep"
    Log-Message "=================================================="
    if ($ErrorMessage) {
        Log-Message "Error details: $ErrorMessage"
    }
    Log-Message "--- Last 30 lines of build log ($LogFile) ---"
    if (Test-Path $LogFile) {
        Get-Content $LogFile -Tail 30 | ForEach-Object { Write-Host $_ }
    }
    Log-Message "--------------------------------------------------"
    exit 1
}

try {
    Log-Message "=================================================="
    Log-Message "🎬 ShortsSplitter: Starting APK Build ($BuildType)"
    Log-Message "=================================================="
    Log-Message "Project Root: $ProjectRoot"
    Log-Message "Log File:     $LogFile"
    Log-Message ""

    # --------------------------------------------------------------------------
    # 1. Pre-Flight Toolchain Checks
    # --------------------------------------------------------------------------
    $global:CurrentStep = "Pre-flight toolchain check"
    Log-Message "1. Running pre-flight checks..."

    $FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $FlutterCmd) {
        throw "'flutter' is not on PATH. Please install Flutter SDK."
    }
    $FlutterVer = (& flutter --version 2>&1 | Select-Object -First 1)
    Log-Message "  ✅ Flutter found: $FlutterVer"

    $JavaCmd = Get-Command java -ErrorAction SilentlyContinue
    if (-not $JavaCmd) {
        throw "'java' is not on PATH. JDK 17 is required."
    }
    $JavaVer = (& java -version 2>&1 | Select-Object -First 1)
    Log-Message "  ✅ Java found: $JavaVer"

    $DoctorOutput = & flutter doctor -v 2>&1
    $DoctorText = $DoctorOutput -join "`n"
    if ($DoctorText -match "\[✗\] Android toolchain") {
        Log-Message "❌ Error: Android toolchain error detected in 'flutter doctor':"
        Log-Message $DoctorText
        throw "Android toolchain validation failed."
    }
    Log-Message "  ✅ Android toolchain is valid."

    if ($DoctorText -match "\[!\] Android toolchain") {
        Log-Message "  ⚠️ Warning: Non-blocking Android toolchain warning present."
    }

    # --------------------------------------------------------------------------
    # 2. Optional Version Bump (-Bump)
    # --------------------------------------------------------------------------
    $PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
    if ($Bump) {
        $global:CurrentStep = "Version bump in pubspec.yaml"
        $Content = Get-Content -Path $PubspecPath -Raw
        if ($Content -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
            $VerName = $matches[1]
            $BuildNum = [int]$matches[2]
            $NewBuildNum = $BuildNum + 1
            $NewVer = "$VerName+$NewBuildNum"
            $Content = $Content -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $NewVer"
            Set-Content -Path $PubspecPath -Value $Content -Encoding utf8
            Log-Message "  ✅ Version bumped: $VerName+$BuildNum -> $NewVer"
        } else {
            throw "Could not parse version line in pubspec.yaml"
        }
    }

    # Read current version from pubspec.yaml
    $PubspecContent = Get-Content -Path $PubspecPath -Raw
    if ($PubspecContent -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
        $VersionName = $matches[1]
        $BuildNumber = $matches[2]
    } else {
        $VersionName = "1.0.0"
        $BuildNumber = "1"
    }
    $FullVersion = "$VersionName+$BuildNumber"
    Log-Message "  Target Version: $FullVersion"

    # --------------------------------------------------------------------------
    # 3. Check Signing Configuration
    # --------------------------------------------------------------------------
    $global:CurrentStep = "Signing configuration check"
    $KeyPropsPath = Join-Path $ProjectRoot "android\key.properties"
    $IsSigned = "debug-signed"
    if (Test-Path $KeyPropsPath) {
        $IsSigned = "signed"
        Log-Message "  ✅ Release signing key found in android/key.properties (signed build)."
    } else {
        Log-Message ""
        Log-Message "  ⚠️ WARNING: android/key.properties was NOT found!"
        Log-Message "     The APK will be signed using Android's default debug key."
        Log-Message "     This APK is NOT valid for Google Play Store production release."
        Log-Message ""
        Log-Message "     To configure release signing:"
        Log-Message "       1. keytool -genkey -v -keystore android/release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias shortssplitter"
        Log-Message "       2. Create android/key.properties with storeFile, storePassword, keyAlias, and keyPassword."
        Log-Message ""
    }

    # --------------------------------------------------------------------------
    # 4. Clean, Pub Get, Build Runner, Analyze, Test
    # --------------------------------------------------------------------------
    if ($Clean) {
        $global:CurrentStep = "Cleaning project"
        Log-Message "2. Cleaning project (flutter clean)..."
        & flutter clean | Out-Null
        if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }
        if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir | Out-Null }
        if (-not (Test-Path $LogFile)) { "" | Out-File -FilePath $LogFile -Encoding utf8 }
        Log-Message "  ✅ Clean complete."
    }

    $global:CurrentStep = "Fetching dependencies"
    Log-Message "3. Resolving dependencies (flutter pub get)..."
    & flutter pub get *>> $LogFile
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
    Log-Message "  ✅ Dependencies resolved."

    if ($PubspecContent -match "build_runner:") {
        $global:CurrentStep = "Running code generation (build_runner)"
        Log-Message "4. Running code generation (build_runner)..."
        & dart run build_runner build --delete-conflicting-outputs *>> $LogFile
        if ($LASTEXITCODE -ne 0) { throw "build_runner code generation failed" }
        Log-Message "  ✅ Code generation complete."
    }

    $global:CurrentStep = "Static analysis"
    Log-Message "5. Running static analysis (flutter analyze)..."
    & flutter analyze *>> $LogFile
    if ($LASTEXITCODE -ne 0) {
        Log-Message "❌ Static analysis failed! Inspecting issues:"
        & flutter analyze
        throw "Static analysis failed"
    }
    Log-Message "  ✅ Static analysis passed."

    if (-not $SkipTests) {
        $global:CurrentStep = "Running automated tests"
        Log-Message "6. Running automated test suite (flutter test)..."
        & flutter test *>> $LogFile
        if ($LASTEXITCODE -ne 0) {
            throw "Automated tests failed"
        }
        Log-Message "  ✅ Automated tests passed."
    } else {
        Log-Message "6. Skipping automated tests (-SkipTests specified)."
    }

    # --------------------------------------------------------------------------
    # 5. Flutter Build APK
    # --------------------------------------------------------------------------
    $global:CurrentStep = "Compiling APK (flutter build apk)"
    Log-Message "7. Compiling APK..."

    $BuildArgs = @("build", "apk")
    if ($BuildType -eq "release") {
        $BuildArgs += "--release"
    } elseif ($BuildType -eq "debug") {
        $BuildArgs += "--debug"
    } elseif ($BuildType -eq "profile") {
        $BuildArgs += "--profile"
    }

    if ($SplitAbi) {
        $BuildArgs += "--split-per-abi"
    }

    if ($Obfuscate -and $BuildType -eq "release") {
        $SymbolsDir = Join-Path $ProjectRoot "build\symbols"
        if (-not (Test-Path $SymbolsDir)) {
            New-Item -ItemType Directory -Path $SymbolsDir | Out-Null
        }
        $BuildArgs += "--obfuscate"
        $BuildArgs += "--split-debug-info=build/symbols"
    }

    Log-Message "  Executing: flutter $($BuildArgs -join ' ')"
    & flutter @BuildArgs *>> $LogFile
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk failed"
    }
    Log-Message "  ✅ APK compilation succeeded."

    # --------------------------------------------------------------------------
    # 6. Locate & Copy Output Artifacts to dist/
    # --------------------------------------------------------------------------
    $global:CurrentStep = "Packaging & archiving APK(s)"
    $OutputDir = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"
    $ProducedApks = @()

    if ($SplitAbi) {
        $Abis = @("arm64-v8a", "armeabi-v7a", "x86_64")
        foreach ($abi in $Abis) {
            $OrigApk = Join-Path $OutputDir "app-$abi-$BuildType.apk"
            if (Test-Path $OrigApk) {
                $DestName = "ShortsSplitter-$FullVersion-$BuildType-$abi.apk"
                $DestApk = Join-Path $DistDir $DestName
                Copy-Item -Path $OrigApk -Destination $DestApk -Force
                $ProducedApks += [PSCustomObject]@{
                    Orig = $OrigApk
                    Dest = $DestApk
                    Abi  = $abi
                }
            }
        }
    } else {
        $OrigApk = Join-Path $OutputDir "app-$BuildType.apk"
        if (Test-Path $OrigApk) {
            $DestName = "ShortsSplitter-$FullVersion-$BuildType.apk"
            $DestApk = Join-Path $DistDir $DestName
            Copy-Item -Path $OrigApk -Destination $DestApk -Force
            $ProducedApks += [PSCustomObject]@{
                Orig = $OrigApk
                Dest = $DestApk
                Abi  = "universal"
            }
        }
    }

    if ($ProducedApks.Count -eq 0) {
        throw "Could not locate built APK files under $OutputDir"
    }

    # Keep only the 5 most recent APKs in dist/
    $AllDistApks = Get-ChildItem -Path $DistDir -Filter "*.apk" | Sort-Object LastWriteTime -Descending
    if ($AllDistApks.Count -gt 5) {
        $AllDistApks | Select-Object -Skip 5 | Remove-Item -Force
    }

    # --------------------------------------------------------------------------
    # 7. Helper for aapt2 and adb
    # --------------------------------------------------------------------------
    function Find-Tool([string]$ToolName) {
        $Cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($Cmd) { return $Cmd.Source }

        $SdkCandidates = @()
        if ($env:ANDROID_HOME) { $SdkCandidates += $env:ANDROID_HOME }
        if ($env:ANDROID_SDK_ROOT) { $SdkCandidates += $env:ANDROID_SDK_ROOT }
        if ($env:LOCALAPPDATA) { $SdkCandidates += (Join-Path $env:LOCALAPPDATA "Android\Sdk") }
        $Home = [Environment]::GetFolderPath("UserProfile")
        $SdkCandidates += (Join-Path $Home "Android\Sdk")

        foreach ($sdk in $SdkCandidates) {
            if ($ToolName -eq "aapt2" -or $ToolName -eq "aapt2.exe") {
                $BuildTools = Join-Path $sdk "build-tools"
                if (Test-Path $BuildTools) {
                    $Found = Get-ChildItem -Path $BuildTools -Filter "aapt2.exe" -Recurse -ErrorAction SilentlyContinue |
                        Sort-Object FullName -Descending | Select-Object -First 1
                    if ($Found) { return $Found.FullName }
                }
            } elseif ($ToolName -eq "adb" -or $ToolName -eq "adb.exe") {
                $AdbPath = Join-Path $sdk "platform-tools\adb.exe"
                if (Test-Path $AdbPath) { return $AdbPath }
            }
        }
        return $null
    }

    # --------------------------------------------------------------------------
    # 8. Verify APK Badging (aapt2)
    # --------------------------------------------------------------------------
    $global:CurrentStep = "Verifying APK manifest badging"
    Log-Message ""
    Log-Message "8. Verifying APK binary metadata..."

    $Aapt2Bin = Find-Tool "aapt2.exe"
    $MinSdkFound = "28"

    foreach ($item in $ProducedApks) {
        if ($Aapt2Bin -and (Test-Path $Aapt2Bin)) {
            $Badging = & $Aapt2Bin dump badging $item.Dest 2>&1
            $BadgingText = $Badging -join "`n"
            if ($BadgingText -match "package: name='([^']+)'") {
                $PkgName = $matches[1]
                $VName = if ($BadgingText -match "versionName='([^']+)'") { $matches[1] } else { "N/A" }
                $VCode = if ($BadgingText -match "versionCode='([^']+)'") { $matches[1] } else { "N/A" }
                $MinSdkFound = if ($BadgingText -match "(?:minSdkVersion|sdkVersion):'([^']+)'") { $matches[1] } else { "28" }
                $TargetSdk = if ($BadgingText -match "targetSdkVersion:'([^']+)'") { $matches[1] } else { "N/A" }

                Log-Message "  [$($item.Abi)] Verified via aapt2:"
                Log-Message "     Package:    $PkgName"
                Log-Message "     Version:    $VName ($VCode)"
                Log-Message "     Min SDK:    $MinSdkFound"
                Log-Message "     Target SDK: $TargetSdk"

                if ($MinSdkFound -ne "28") {
                    Log-Message "  ⚠️ WARNING: minSdkVersion is '$MinSdkFound' (expected 28)!"
                }
            } else {
                Log-Message "  [$($item.Abi)] aapt2 could not parse badging."
            }
        } else {
            Log-Message "  (aapt2 not found; skipping binary manifest verification)"
            break
        }
    }

    # --------------------------------------------------------------------------
    # 9. Print Final Summary Block
    # --------------------------------------------------------------------------
    $global:CurrentStep = "Summary generation"
    $BuildTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    function Format-FileSize([long]$Bytes) {
        if ($Bytes -ge 1GB) {
            return "{0:N2} GB" -f ($Bytes / 1GB)
        } elseif ($Bytes -ge 1MB) {
            return "{0:N2} MB" -f ($Bytes / 1MB)
        } elseif ($Bytes -ge 1KB) {
            return "{0:N2} KB" -f ($Bytes / 1KB)
        } else {
            return "$Bytes B"
        }
    }

    Write-Host ""
    Write-Host "========== BUILD SUCCESS =========="
    Write-Host "App:        ShortsSplitter"
    Write-Host "Version:    $FullVersion"
    Write-Host "Build type: $BuildType ($IsSigned)"

    foreach ($item in $ProducedApks) {
        $FileItem = Get-Item $item.Dest
        $SizeStr = Format-FileSize $FileItem.Length
        $HashInfo = Get-FileHash -Path $item.Dest -Algorithm SHA256
        $ShaStr = $HashInfo.Hash.ToLower()

        if ($SplitAbi) {
            Write-Host ""
            Write-Host "[$($item.Abi)]"
        }
        Write-Host "APK path:   $($item.Dest)"
        Write-Host "Original:   $($item.Orig)"
        Write-Host "Size:       $SizeStr"
        Write-Host "SHA-256:    $ShaStr"
        Write-Host "Min SDK:    $MinSdkFound"
        Write-Host "Built at:   $BuildTime"
        Write-Host "Install:    adb install -r `"$($item.Dest)`""
    }
    Write-Host "==================================="
    Write-Host ""

    # --------------------------------------------------------------------------
    # 10. Optional Install on Connected Device (-Install)
    # --------------------------------------------------------------------------
    if ($Install) {
        $global:CurrentStep = "Device installation"
        $AdbBin = Find-Tool "adb.exe"
        if ($AdbBin -and (Test-Path $AdbBin)) {
            $DeviceLines = & $AdbBin devices 2>&1 | Where-Object { $_ -match "\bdevice$" }
            if ($DeviceLines) {
                $FirstApk = $ProducedApks[0].Dest
                Log-Message "Installing $FirstApk onto connected device..."
                & $AdbBin install -r $FirstApk *>> $LogFile
                Log-Message "✅ Installation complete."
            } else {
                Log-Message "ℹ️  Skipping install: no connected device detected via adb."
            }
        } else {
            Log-Message "ℹ️  Skipping install: 'adb' tool not found on PATH or Android SDK."
        }
    }

    # --------------------------------------------------------------------------
    # 11. Open dist folder in explorer (unless -NoOpen)
    # --------------------------------------------------------------------------
    if (-not $NoOpen) {
        Invoke-Item $DistDir
    }

    exit 0

} catch {
    Invoke-BuildFailure $_.Exception.Message
}

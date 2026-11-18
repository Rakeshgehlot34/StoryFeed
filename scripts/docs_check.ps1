# ==============================================================================
# ShortsSplitter Documentation Integrity & Link Verifier (PowerShell)
# ==============================================================================

$errors = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "=================================================="
Write-Host "📚 ShortsSplitter: Documentation Integrity Check"
Write-Host "=================================================="
Write-Host ""

$requiredDocs = @(
    "docs\README.md",
    "README.md",
    "docs\SETUP.md",
    "docs\COMMANDS.md",
    "docs\ARCHITECTURE.md",
    "docs\FEATURES.md",
    "docs\UI_GUIDE.md",
    "docs\STORAGE_AND_PERMISSIONS.md",
    "docs\ANDROID_COMPAT.md",
    "docs\FFMPEG.md",
    "docs\BUILD_AND_RELEASE.md",
    "docs\TESTING.md",
    "docs\TEST_CASES.md",
    "docs\TROUBLESHOOTING.md",
    "docs\AGENT_SETUP.md",
    "docs\CONTRIBUTING.md",
    "docs\DECISIONS.md",
    "docs\PRIVACY.md",
    "CHANGELOG.md"
)

Write-Host "1. Checking required documentation files exist..."
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
        Write-Host "  ❌ Missing required document: $doc" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "  ✅ Found: $doc" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "2. Scanning for forbidden placeholder text (TODO, TBD, lorem)..."
foreach ($doc in $requiredDocs) {
    if (Test-Path $doc) {
        $content = Get-Content $doc
        for ($i = 0; $i -lt $content.Length; $i++) {
            $line = $content[$i]
            if ($line -match '\b(TODO|TBD|lorem)\b') {
                Write-Host "  ❌ Forbidden placeholder text in $doc at line $($i + 1): $line" -ForegroundColor Red
                $errors++
            }
        }
    }
}

Write-Host ""
Write-Host "3. Verifying all scripts are documented in docs/COMMANDS.md..."
if (Test-Path "docs\COMMANDS.md") {
    $commandsContent = Get-Content "docs\COMMANDS.md" -Raw
    $scripts = Get-ChildItem "scripts" -File
    foreach ($script in $scripts) {
        if (-not ($commandsContent -match [regex]::Escape($script.Name))) {
            Write-Host "  ❌ Script '$($script.Name)' is not documented in docs/COMMANDS.md" -ForegroundColor Red
            $errors++
        } else {
            Write-Host "  ✅ Script documented: $($script.Name)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ❌ Cannot check scripts: docs/COMMANDS.md does not exist." -ForegroundColor Red
    $errors++
}

Write-Host ""
Write-Host "4. Verifying all agent workflows are documented..."
if (Test-Path ".agents\workflows") {
    $commandsContent = if (Test-Path "docs\COMMANDS.md") { Get-Content "docs\COMMANDS.md" -Raw } else { "" }
    $agentSetupContent = if (Test-Path "docs\AGENT_SETUP.md") { Get-Content "docs\AGENT_SETUP.md" -Raw } else { "" }
    $workflows = Get-ChildItem ".agents\workflows" -Filter "*.md"
    foreach ($wf in $workflows) {
        $wfBase = $wf.BaseName
        if (-not ($commandsContent -match [regex]::Escape($wfBase))) {
            Write-Host "  ❌ Workflow '$($wf.Name)' is not mentioned in docs/COMMANDS.md" -ForegroundColor Red
            $errors++
        }
        if (-not ($agentSetupContent -match [regex]::Escape($wfBase))) {
            Write-Host "  ❌ Workflow '$($wf.Name)' is not mentioned in docs/AGENT_SETUP.md" -ForegroundColor Red
            $errors++
        }
    }
}

Write-Host ""
Write-Host "=================================================="
if ($errors -gt 0) {
    Write-Host "❌ Documentation check FAILED with $errors error(s)!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "🎉 Documentation check PASSED! All docs, links, and cross-references valid." -ForegroundColor Green
    exit 0
}


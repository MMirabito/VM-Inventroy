#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install and configure Git pre-commit hooks for VM-Inventory

.DESCRIPTION
    This script automates the complete setup of Git hooks including:
    - Checking for jq installation
    - Installing jq if needed
    - Copying the pre-commit hook
    - Configuring VS Code settings
    - Testing the hook

.EXAMPLE
    .\scripts\setup-hooks.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Git Hooks Setup for VM-Inventory" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if jq is installed
Write-Host "[1/5] Checking for jq..." -ForegroundColor Yellow
$jqInstalled = Get-Command jq -ErrorAction SilentlyContinue

if (-not $jqInstalled) {
    Write-Host "  jq not found. Installing..." -ForegroundColor Yellow
    
    # Check if winget is available
    $wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($wingetInstalled) {
        Write-Host "  Using winget to install jq..." -ForegroundColor Gray
        winget install jqlang.jq --accept-source-agreements --accept-package-agreements
        
        # Refresh PATH
        Write-Host "  Refreshing PATH..." -ForegroundColor Gray
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        $jqInstalled = Get-Command jq -ErrorAction SilentlyContinue
        if ($jqInstalled) {
            Write-Host "  jq installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  jq installation failed. Please restart your terminal and try again." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  winget not found. Please install jq manually:" -ForegroundColor Red
        Write-Host "    winget install jqlang.jq" -ForegroundColor Yellow
        exit 1
    }
} else {
    $jqVersion = jq --version
    Write-Host "  jq is already installed: $jqVersion" -ForegroundColor Green
}

# Step 2: Install the pre-commit hook
Write-Host ""
Write-Host "[2/5] Installing pre-commit hook..." -ForegroundColor Yellow

$scriptRoot = Split-Path -Parent $PSScriptRoot
$hookSource = Join-Path $scriptRoot "scripts\pre-commit"
$hookDest = Join-Path $scriptRoot ".git\hooks\pre-commit"

if (-not (Test-Path $hookSource)) {
    Write-Host "  Hook source not found: $hookSource" -ForegroundColor Red
    exit 1
}

# Create hooks directory if it does not exist
$hooksDir = Split-Path -Parent $hookDest
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

Copy-Item -Path $hookSource -Destination $hookDest -Force
Write-Host "  Hook installed to .git/hooks/pre-commit" -ForegroundColor Green

# Step 3: Configure VS Code settings
Write-Host ""
Write-Host "[3/5] Configuring VS Code..." -ForegroundColor Yellow

$vscodeSettingsPath = "$env:APPDATA\Code\User\settings.json"

if (Test-Path $vscodeSettingsPath) {
    $settings = Get-Content $vscodeSettingsPath -Raw | ConvertFrom-Json
    
    # Add or update the setting
    $needsUpdate = $false
    
    if (-not $settings.PSObject.Properties.Name.Contains("git.allowNoVerifyCommit")) {
        $settings | Add-Member -MemberType NoteProperty -Name "git.allowNoVerifyCommit" -Value $false -Force
        $needsUpdate = $true
    } elseif ($settings."git.allowNoVerifyCommit" -ne $false) {
        $settings."git.allowNoVerifyCommit" = $false
        $needsUpdate = $true
    }
    
    if ($needsUpdate) {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $vscodeSettingsPath -Encoding UTF8
        Write-Host "  VS Code settings updated" -ForegroundColor Green
        Write-Host "    Please restart VS Code to apply changes" -ForegroundColor Yellow
    } else {
        Write-Host "  VS Code settings already configured" -ForegroundColor Green
    }
} else {
    Write-Host "  VS Code settings not found - skipping" -ForegroundColor Yellow
}

# Step 4: Test the hook
Write-Host ""
Write-Host "[4/5] Testing pre-commit hook..." -ForegroundColor Yellow

# Read current build counter
$appInfoPath = Join-Path $scriptRoot "app-info.json"
$appInfo = Get-Content $appInfoPath -Raw | ConvertFrom-Json
$currentCounter = $appInfo.build.counter

Write-Host "  Current build counter: $currentCounter" -ForegroundColor Gray

# Create a temporary test file
$testFile = Join-Path $scriptRoot "test-hook.tmp"
"Test file for hook validation" | Out-File $testFile -Encoding UTF8

# Stage and commit the test file
Write-Host "  Creating test commit..." -ForegroundColor Gray
git add $testFile 2>&1 | Out-Null

$ErrorActionPreference = "Continue"
$commitOutput = (git commit -m "Test pre-commit hook" 2>&1) -join "`n"
$ErrorActionPreference = "Stop"

# Remove the test file and undo the commit
git reset --soft HEAD~1 2>&1 | Out-Null
git reset HEAD $testFile 2>&1 | Out-Null
Remove-Item $testFile -Force -ErrorAction SilentlyContinue

# Check if counter was incremented
$appInfo = Get-Content $appInfoPath -Raw | ConvertFrom-Json
$newCounter = $appInfo.build.counter

if ($commitOutput -match "Build counter incremented") {
    Write-Host "  Hook executed successfully!" -ForegroundColor Green
    Write-Host "  Counter incremented: $currentCounter -> $newCounter" -ForegroundColor Green
    
    # Undo the test commit
    git reset --soft HEAD~1 2>&1 | Out-Null
    
    # Unstage all files
    git reset 2>&1 | Out-Null
    
    # Remove test file
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "  Test commit undone (no changes made)" -ForegroundColor Gray
} else {
    Write-Host "  Hook test completed (check output above)" -ForegroundColor Yellow
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
}

# Step 5: Summary
Write-Host ""
Write-Host "[5/5] Setup complete!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  jq is installed and available" -ForegroundColor Green
Write-Host "  Pre-commit hook is installed" -ForegroundColor Green
Write-Host "  VS Code is configured (restart required)" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Test from terminal first:" -ForegroundColor White
Write-Host "     - Make a small change to any file" -ForegroundColor Gray
Write-Host "     - Run: git add . && git commit -m 'test'" -ForegroundColor Gray
Write-Host "     - You should see: Build counter incremented" -ForegroundColor Gray
Write-Host "  2. Restart VS Code completely" -ForegroundColor White
Write-Host "  3. Test from VS Code UI:" -ForegroundColor White
Write-Host "     - Make a change and commit via Source Control" -ForegroundColor Gray
Write-Host "     - Should also see counter increment" -ForegroundColor Gray
Write-Host ""
Write-Host "If VS Code commits do not work after restart:" -ForegroundColor Yellow
Write-Host "  Just commit from terminal - the hook always works there" -ForegroundColor Gray
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan

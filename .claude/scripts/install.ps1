# harness-kit Install Script (Windows PowerShell)
# Installs or updates the harness-kit framework in the current directory.

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# =============================================================================
# Configuration
# =============================================================================

$CORE_FLOW_REF = if ($env:CORE_FLOW_REF) { $env:CORE_FLOW_REF } else { "main" }
$CORE_FLOW_REPO = if ($env:CORE_FLOW_REPO) { $env:CORE_FLOW_REPO } else { "damienstanton/harness-kit" }

# =============================================================================
# Color output
# =============================================================================

function Write-Info { Write-Host "INFO: $args" -ForegroundColor Blue }
function Write-Success { Write-Host "SUCCESS: $args" -ForegroundColor Green }
function Write-Warn { Write-Host "WARN: $args" -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host "ERROR: $args" -ForegroundColor Red }
function Write-Fatal { Write-Error-Custom $args; exit 1 }

# =============================================================================
# Prerequisite Checking
# =============================================================================

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."

    $missing = @()

    # git is required
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += "git"
    }

    # gh is optional but preferred
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warn "gh CLI not found — install method will use git clone fallback"
        Write-Warn "For better performance and private repo support, install gh:"
        Write-Warn "  scoop install gh"
        Write-Warn "  choco install gh"
    }

    if ($missing.Count -gt 0) {
        Write-Error-Custom "Missing required prerequisites: $($missing -join ', ')"
        Write-Host ""
        Write-Host "Installation instructions:"
        Write-Host "  scoop install $($missing -join ' ')"
        Write-Host "  choco install $($missing -join ' ')"
        Write-Host ""
        Write-Host "Install scoop: https://scoop.sh"
        Write-Host "Install chocolatey: https://chocolatey.org/install"
        exit 1
    }

    Write-Success "Prerequisites OK"
}

# =============================================================================
# Source Detection
# =============================================================================

function Get-SourceMode {
    # Determine the directory of this script
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

    # Walk up from the script directory looking for a repo root that contains .claude\VERSION
    $candidate = $scriptDir
    while ($candidate -and -not (Test-Path (Join-Path $candidate ".claude\VERSION"))) {
        $parent = Split-Path -Parent $candidate
        if (-not $parent -or $parent -eq $candidate) {
            $candidate = $null
        }
        else {
            $candidate = $parent
        }
    }

    if ($candidate) {
        # Check if this is a git repo with the expected origin
        Push-Location $candidate
        try {
            $originUrl = git remote get-url origin 2>$null
            if ($LASTEXITCODE -eq 0 -and $originUrl -match [regex]::Escape($CORE_FLOW_REPO)) {
                $script:SOURCE_MODE = "local"
                $script:SOURCE_DIR = $candidate
                Write-Info "Detected local harness-kit source from git clone: $SOURCE_DIR"
                return
            }
        }
        finally {
            Pop-Location
        }
    }

    # Fallback: treat as remote install (will clone to a temporary directory)
    $script:SOURCE_MODE = "remote"
    Write-Info "Detected remote installation (will clone from GitHub)"
}

# =============================================================================
# Clone Source
# =============================================================================

function Get-Source {
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-kit-" + [guid]::NewGuid().ToString("N").Substring(0, 8))

    Write-Info "Cloning $CORE_FLOW_REPO (ref: $CORE_FLOW_REF) to $tmpDir..."

    # NOTE: CORE_FLOW_REF must be a branch name or tag (not a SHA)
    # SHA pinning not supported with shallow clones
    git clone --depth 1 --branch $CORE_FLOW_REF "https://github.com/$CORE_FLOW_REPO.git" $tmpDir 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "Failed to clone repository. Ensure CORE_FLOW_REF is a valid branch or tag (SHAs not supported)."
    }

    $script:SOURCE_DIR = $tmpDir
    Write-Success "Cloned successfully"
}

# =============================================================================
# File Operations
# =============================================================================

function Get-Version {
    $versionFile = Join-Path $script:SOURCE_DIR ".claude\VERSION"
    if (Test-Path $versionFile) {
        (Get-Content $versionFile -Raw).Trim()
    }
    else {
        "unknown"
    }
}

function Install-Files {
    $src = $script:SOURCE_DIR
    $dst = "."

    Write-Info "Installing framework files..."

    # Create directories if they don't exist
    New-Item -ItemType Directory -Force -Path ".claude\features" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude\artifacts" | Out-Null
    New-Item -ItemType Directory -Force -Path ".claude\context" | Out-Null

    # Always overwrite: framework core
    Write-Info "  Copying framework core..."

    $dirs = @("agents", "skills", "specs", "rules", "scripts")
    foreach ($dir in $dirs) {
        $srcPath = Join-Path $src ".claude\$dir"
        $dstPath = Join-Path $dst ".claude\$dir"
        if (Test-Path $srcPath) {
            if (Test-Path $dstPath) { Remove-Item -Recurse -Force $dstPath }
            Copy-Item -Recurse -Force $srcPath $dstPath
        }
    }

    # Copy individual files
    $files = @("settings.json", "README.md", "VERSION", "CHANGELOG.md")
    foreach ($file in $files) {
        $srcPath = Join-Path $src ".claude\$file"
        $dstPath = Join-Path $dst ".claude\$file"
        if (Test-Path $srcPath) {
            Copy-Item -Force $srcPath $dstPath
        }
    }

    # Copy root docs
    $rootDocs = @("CLAUDE.md", "AGENTS.md", "README.md", "start_here.md", "ACADEMIC_NOTICE.md")
    foreach ($doc in $rootDocs) {
        $srcPath = Join-Path $src $doc
        $dstPath = Join-Path $dst $doc
        if (Test-Path $srcPath) {
            Copy-Item -Force $srcPath $dstPath
        }
    }

    # Copy template profile only if it doesn't exist
    $templatePath = ".claude\profiles\_template.yaml"
    if (-not (Test-Path $templatePath)) {
        Write-Info "  Copying profile template..."
        New-Item -ItemType Directory -Force -Path ".claude\profiles" | Out-Null
        $srcTemplate = Join-Path $src $templatePath
        if (Test-Path $srcTemplate) {
            Copy-Item -Force $srcTemplate $templatePath
        }
    }
    else {
        Write-Info "  Preserving existing profile template"
    }

    Write-Success "Files installed"
}

# =============================================================================
# Version File
# =============================================================================

function Write-VersionFile {
    $version = Get-Version
    $versionFile = ".claude\.harness-version"
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    Write-Info "Writing version file..."

    # Determine installed_from format
    if ($CORE_FLOW_REF -match "^v\d+\.\d+\.\d+") {
        # Tag format
        $content = @{
            version = $version
            installed_at = $timestamp
            installed_from = $CORE_FLOW_REF
        } | ConvertTo-Json -Depth 10
    }
    else {
        # Branch or SHA format
        $sha = "unknown"
        $gitDir = Join-Path $script:SOURCE_DIR ".git"
        if (Test-Path $gitDir) {
            Push-Location $script:SOURCE_DIR
            try {
                $sha = git rev-parse HEAD 2>$null
            }
            catch {
                $sha = "unknown"
            }
            Pop-Location
        }

        $content = @{
            version = $version
            installed_at = $timestamp
            installed_from = @{
                ref = $CORE_FLOW_REF
                sha = $sha
            }
        } | ConvertTo-Json -Depth 10
    }

    $content | Out-File -FilePath $versionFile -Encoding UTF8 -NoNewline

    Write-Success "Version file written: $versionFile"
}

# =============================================================================
# Main
# =============================================================================

function Main {
    Write-Host ""
    Write-Host "harness-kit Installer"
    Write-Host "==================="
    Write-Host ""

    Test-Prerequisites
    Get-SourceMode

    $script:CLEANUP_NEEDED = $false

    if ($script:SOURCE_MODE -eq "remote") {
        Get-Source
        $script:CLEANUP_NEEDED = $true
    }

    Install-Files
    Write-VersionFile

    if ($script:CLEANUP_NEEDED) {
        Write-Info "Cleaning up temporary files..."
        Remove-Item -Recurse -Force $script:SOURCE_DIR
    }

    Write-Host ""
    Write-Success "harness-kit installed successfully!"
    Write-Host ""
    # Read version from installed destination (SOURCE_DIR may be cleaned up)
    if (Test-Path ".claude\VERSION") {
        Write-Host "Version: $((Get-Content .claude\VERSION -Raw).Trim())"
    }
    else {
        Write-Host "Version: unknown"
    }
    Write-Host "Ref:     $CORE_FLOW_REF"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Start a Claude Code session: claude"
    Write-Host "  2. Type: /hello            (to orient yourself)"
    Write-Host "     Or:   /new-task <description>  (to plan a feature)"
    Write-Host ""
}

Main

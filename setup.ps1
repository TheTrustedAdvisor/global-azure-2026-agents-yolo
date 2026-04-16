#!/usr/bin/env pwsh
<#
.SYNOPSIS
Global Azure Hamburg 2026 — Agents & Yolo-Mode Demo Setup (Windows/PowerShell)

.DESCRIPTION
Checks installed tools, installs missing ones via winget, clones the public workshop repo,
and verifies the demo clean state (no .github/, no pre-built measures).

.PARAMETER Check
Verify only — don't install anything.

.PARAMETER Reset
Reset the demo repo to clean state (useful between dry-runs).

.PARAMETER WorkshopDir
Override clone location. Defaults to $HOME\demo-global-azure-2026.

.EXAMPLE
.\setup.ps1
Full setup (install missing tools, clone repo).

.EXAMPLE
.\setup.ps1 -Check
Verify state without installing anything.

.EXAMPLE
.\setup.ps1 -Reset
Hard-reset the demo repo between dry-runs.
#>

[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Reset,
    [string]$WorkshopDir = (Join-Path $HOME 'demo-global-azure-2026')
)

$ErrorActionPreference = 'Stop'
$RepoUrl = 'https://github.com/TheTrustedAdvisor/global-azure-2026-agents-yolo.git'

# ─── Output helpers ────────────────────────────────────────────────────────
function Step($msg)   { Write-Host "`n▶ "  -ForegroundColor Blue   -NoNewline; Write-Host $msg -ForegroundColor White }
function Ok($msg)     { Write-Host "  ✓ "  -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Warn($msg)   { Write-Host "  ⚠ "  -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Failure($msg){ Write-Host "  ✗ "  -ForegroundColor Red    -NoNewline; Write-Host $msg; exit 1 }

function Has-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Show-Banner {
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Blue
    Write-Host '  Global Azure Hamburg 2026 — Demo Setup' -ForegroundColor White
    $mode = if ($Check) { 'check' } elseif ($Reset) { 'reset' } else { 'full' }
    Write-Host "  Mode: $mode"
    Write-Host "  Target: $WorkshopDir"
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Blue
}

# ─── OS Detection ──────────────────────────────────────────────────────────
function Check-OS {
    Step 'OS check'
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5 -and $env:OS -match 'Windows')) {
        Ok "Windows $([System.Environment]::OSVersion.Version)"
        return 'Windows'
    } elseif ($IsMacOS) {
        Ok 'macOS'
        return 'macOS'
    } elseif ($IsLinux) {
        Ok 'Linux'
        return 'Linux'
    } else {
        Failure 'Unknown OS — PowerShell Core required on non-Windows'
    }
}

# ─── GitHub CLI ────────────────────────────────────────────────────────────
function Check-Gh {
    Step 'GitHub CLI (gh)'
    if (Has-Command gh) {
        $version = (gh --version 2>$null | Select-Object -First 1)
        Ok $version
    } else {
        if ($Check) { Warn 'Not installed — run without -Check to install'; return }
        Warn 'Installing gh via winget...'
        winget install -e --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
        Ok 'Installed — PATH may need a new PowerShell session'
    }

    $authOut = gh auth status 2>&1 | Out-String
    if ($authOut -match 'Logged in') {
        $user = gh api user --jq .login 2>$null
        Ok "Authenticated as $user"
    } else {
        Warn 'Not authenticated — run: gh auth login'
    }
}

# ─── Copilot CLI ───────────────────────────────────────────────────────────
function Check-Copilot {
    Step 'Copilot CLI'
    if (Has-Command copilot) {
        $version = (copilot --version 2>$null | Select-Object -First 1)
        Ok $version
    } else {
        if ($Check) { Warn 'Not installed'; return }
        if (-not (Has-Command npm)) {
            Failure 'npm required for Copilot CLI install. First: winget install -e --id OpenJS.NodeJS'
        }
        Warn 'Installing copilot CLI via npm...'
        npm install -g '@github/copilot'
        Ok 'Installed'
    }
}

# ─── Plugins ───────────────────────────────────────────────────────────────
function Check-Plugins {
    Step 'Copilot plugins'
    $plugins = (copilot plugin list 2>$null) -join "`n"

    if ($plugins -match 'omg') {
        Ok 'OMG plugin installed'
    } else {
        if ($Check) { Warn 'OMG plugin missing'; return }
        Warn 'Installing OMG plugin...'
        copilot plugin install TheTrustedAdvisor/omg
    }

    if ($plugins -match 'skills-for-fabric') {
        Ok 'skills-for-fabric installed'
    } else {
        Warn 'skills-for-fabric needs manual install inside copilot:'
        Write-Host '      /plugin install skills-for-fabric@fabric-collection'
    }
}

# ─── Azure CLI ─────────────────────────────────────────────────────────────
function Check-Azure {
    Step 'Azure CLI (az)'
    if (Has-Command az) {
        $version = (az version --query '\"azure-cli\"' -o tsv 2>$null)
        Ok "v$version"
    } else {
        if ($Check) { Warn 'Not installed'; return }
        Warn 'Installing Azure CLI via winget...'
        winget install -e --id Microsoft.AzureCLI --silent --accept-package-agreements --accept-source-agreements
        Ok 'Installed — PATH may need a new PowerShell session'
    }

    az account show *>$null
    if ($LASTEXITCODE -eq 0) {
        $sub = (az account show --query name -o tsv 2>$null)
        Ok "Logged in — subscription: $sub"
    } else {
        Warn 'Not logged in — run: az login'
    }
}

# ─── glow (Markdown-Viewer fuer Akt 5) ─────────────────────────────────────
function Check-Glow {
    Step 'glow (Markdown-Viewer fuer Akt 5)'
    if (Has-Command glow) {
        $version = (glow --version 2>$null | Select-Object -First 1)
        Ok $version
    } else {
        if ($Check) { Warn 'Not installed'; return }
        Warn 'Installing glow via winget...'
        winget install -e --id charmbracelet.glow --silent --accept-package-agreements --accept-source-agreements
        Ok 'Installed — PATH may need a new PowerShell session'
    }
}

# ─── Workshop Repo ─────────────────────────────────────────────────────────
function Setup-Repo {
    Step "Workshop repo at $WorkshopDir"

    $gitDir = Join-Path $WorkshopDir '.git'
    if (Test-Path $gitDir) {
        Ok 'Repo exists — resetting to clean state'
        Push-Location $WorkshopDir
        try {
            git fetch origin main --quiet
            git reset --hard origin/main --quiet
            git clean -fd --quiet
        } finally { Pop-Location }
    } else {
        if ($Check) { Warn 'Not cloned yet'; return }
        Ok 'Cloning fresh...'
        $parent = Split-Path -Parent $WorkshopDir
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        git clone --quiet $RepoUrl $WorkshopDir
    }

    # Demo invariants
    $githubDir = Join-Path $WorkshopDir '.github'
    if (Test-Path $githubDir) {
        Warn 'Stale .github/ found — removing (Agent creates live in Akt 1)'
        Remove-Item -Recurse -Force $githubDir
    }
    Ok 'No .github/ — clean demo start'

    $fact = Join-Path $WorkshopDir 'src\sales.semanticmodel\definition\tables\internet sales.tmdl'
    if (Test-Path $fact) {
        $matches = Select-String -Path $fact -Pattern '^\s*measure' -AllMatches -ErrorAction SilentlyContinue
        $count = if ($matches) { $matches.Matches.Count } else { 0 }
        if ($count -eq 0) {
            Ok 'Fact-Tables clean — no measures (Agent baut sie in Akt 3+4)'
        } else {
            Warn "Found $count measures in internet sales.tmdl — expected 0 for demo start"
        }
    }
}

# ─── Summary ───────────────────────────────────────────────────────────────
function Show-Summary {
    Step 'Ready for demo'
    Write-Host ''
    Write-Host '  Repo ready at: ' -NoNewline; Write-Host $WorkshopDir -ForegroundColor White
    Write-Host '  QR-Code:        ' -NoNewline; Write-Host 'https://github.com/TheTrustedAdvisor/global-azure-2026-agents-yolo' -ForegroundColor White
    Write-Host ''
    Write-Host '  Start the demo:'
    Write-Host "    cd `"$WorkshopDir`" ; copilot" -ForegroundColor White
    Write-Host ''
    Write-Host '  Reset between dry-runs:'
    Write-Host '    .\setup.ps1 -Reset' -ForegroundColor White
    Write-Host ''
}

# ─── Main ──────────────────────────────────────────────────────────────────
Show-Banner

if ($Reset) {
    Setup-Repo
    Show-Summary
    exit 0
}

$null = Check-OS
Check-Gh
Check-Copilot
Check-Plugins
Check-Azure
Check-Glow
Setup-Repo
Show-Summary

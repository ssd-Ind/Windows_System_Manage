# =============================================================================
# ForceDefaultPower.ps1 - Windows Power Settings Restorer
# =============================================================================
# Description:
#   Resets power settings to default values (monitor timeout, sleep, lid action).
#   Useful after Citrix sessions or when power settings have been altered.
#
# Usage:
#   .\ForceDefaultPower.ps1 [-LogPath <string>] [-DryRun] [-Help]
#
# Parameters:
#   -LogPath   : Optional path to log file (default: $env:TEMP\PowerManager.log)
#   -DryRun    : Preview changes without applying them
#   -Help      : Show this help message
#
# Requirements:
#   - Windows 10/11
#   - Administrator privileges (for actual changes)
# =============================================================================

[CmdletBinding()]
param(
    [string]$LogPath = "$env:TEMP\PowerManager.log",
    [switch]$DryRun,
    [switch]$Help
)

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Write-Host $logLine
    if (-not $DryRun) {
        Add-Content -Path $LogPath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

function Show-Help {
    Write-Host @"
ForceDefaultPower.ps1 - Windows Power Settings Restorer

Resets the following power settings to defaults:
  - Monitor timeout (AC: 30 min, DC: 3 min)
  - Sleep timeout (AC/DC: 60 min)
  - Lid close action (Sleep)

Usage:
  .\ForceDefaultPower.ps1 [-LogPath <path>] [-DryRun] [-Help]

Parameters:
  -LogPath <path>   Specify custom log file path (default: %TEMP%\PowerManager.log)
  -DryRun           Preview changes without applying them
  -Help             Display this help message

Examples:
  .\ForceDefaultPower.ps1
  .\ForceDefaultPower.ps1 -DryRun
  .\ForceDefaultPower.ps1 -LogPath "C:\Logs\power.log"
"@
    exit 0
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-DefaultPower {
    param([switch]$DryRun)

    $settings = @(
        @{ Command = "powercfg /change monitor-timeout-ac 30"; Description = "Monitor timeout AC -> 30 min" },
        @{ Command = "powercfg /change monitor-timeout-dc 3";  Description = "Monitor timeout DC -> 3 min" },
        @{ Command = "powercfg /change standby-timeout-ac 60"; Description = "Sleep timeout AC -> 60 min" },
        @{ Command = "powercfg /change standby-timeout-dc 60"; Description = "Sleep timeout DC -> 60 min" },
        @{ Command = "powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1"; Description = "Lid close AC -> Sleep" },
        @{ Command = "powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1"; Description = "Lid close DC -> Sleep" },
        @{ Command = "powercfg /S SCHEME_CURRENT"; Description = "Apply power scheme" }
    )

    foreach ($item in $settings) {
        if ($DryRun) {
            Write-Log "[DRYRUN] Would execute: $($item.Command)"
        } else {
            Write-Log "Executing: $($item.Description)"
            try {
                Invoke-Expression $item.Command -ErrorAction Stop
                Write-Log "  -> Success"
            } catch {
                Write-Log "  -> ERROR: $_" -ForegroundColor Red
            }
        }
    }

    if (-not $DryRun) {
        Write-Log "Default power settings restored successfully."
    } else {
        Write-Log "Dry run completed. No changes were made."
    }
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------
if ($Help) {
    Show-Help
}

Write-Log "=== ForceDefaultPower.ps1 started ==="

# Check for administrator rights (only required for actual changes)
if (-not $DryRun -and -not (Test-Administrator)) {
    Write-Log "ERROR: Administrator privileges are required to change power settings." -ForegroundColor Red
    Write-Log "Please run this script as Administrator." -ForegroundColor Yellow
    exit 1
}

Set-DefaultPower -DryRun:$DryRun

Write-Log "=== Script finished ==="

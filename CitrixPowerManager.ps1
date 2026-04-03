# CitrixPowerManager.ps1

$citrixProcess = "wfica32"
$checkInterval = 30
$citrixActive  = $false
$logFile = "C:\Users\SSD\OneDrive\Scripts\CitrixPowerManager.log"

function Write-Log($msg) {
    $line = "[$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Set-StayAwake {
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    # Lid close does nothing
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
    powercfg /S SCHEME_CURRENT
    Write-Log "Citrix detected - screen/sleep disabled, lid set to do nothing"
}

function Set-DefaultPower {
    powercfg /change monitor-timeout-ac 30
    powercfg /change monitor-timeout-dc 3
    powercfg /change standby-timeout-ac 60
    powercfg /change standby-timeout-dc 60
    # Lid close restores to Sleep
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
    powercfg /S SCHEME_CURRENT
    Write-Log "Citrix not running - defaults restored, lid set to sleep"
}

while ($true) {
    $running = Get-Process -Name $citrixProcess -ErrorAction SilentlyContinue

    if ($running -and -not $citrixActive) {
        Set-StayAwake
        $citrixActive = $true
    }
    elseif (-not $running -and $citrixActive) {
        Set-DefaultPower
        $citrixActive = $false
    }

    Start-Sleep -Seconds $checkInterval
}
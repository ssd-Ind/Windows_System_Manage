# ForceDefaultPower.ps1

$logFile = "C:\Users\SSD\OneDrive\Scripts\CitrixPowerManager.log"


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

Set-DefaultPower

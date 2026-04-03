# CheckPowerSettings.ps1

Write-Host "`n=== Current Power Settings ===" -ForegroundColor Cyan

# Sleep
$sleep = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
$sleepAC = ($sleep | Select-String "AC Power Setting Index").ToString().Trim().Split(" ")[-1]
$sleepDC = ($sleep | Select-String "DC Power Setting Index").ToString().Trim().Split(" ")[-1]

# Monitor
$monitor = powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE
$monAC = ($monitor | Select-String "AC Power Setting Index").ToString().Trim().Split(" ")[-1]
$monDC = ($monitor | Select-String "DC Power Setting Index").ToString().Trim().Split(" ")[-1]

# Lid
$lid = powercfg /query SCHEME_CURRENT SUB_BUTTONS LIDACTION
$lidAC = ($lid | Select-String "AC Power Setting Index").ToString().Trim().Split(" ")[-1]
$lidDC = ($lid | Select-String "DC Power Setting Index").ToString().Trim().Split(" ")[-1]

# Convert hex to minutes
function ToMinutes($hex) {
    $sec = [Convert]::ToInt64($hex, 16)
    if ($sec -eq 0) { return "Never" }
    return "$([math]::Round($sec/60)) min"
}

# Lid action label
function LidLabel($hex) {
    switch ($hex) {
        "0x00000000" { return "Do nothing" }
        "0x00000001" { return "Sleep" }
        "0x00000002" { return "Hibernate" }
        "0x00000003" { return "Shut down" }
        default      { return $hex }
    }
}

# Default expected values
$defaults = @{
    SleepAC = "0x00000e10"
    SleepDC = "0x00000e10"
    MonAC   = "0x00000708"
    MonDC   = "0x000000b4"
    LidAC   = "0x00000001"
    LidDC   = "0x00000001"
}

function StatusIcon($current, $default) {
    if ($current -eq $default) { return "[OK]" } else { return "[CHANGED]" }
}

Write-Host ""
Write-Host "Monitor turn off:"
Write-Host "  AC: $(ToMinutes $monAC)   $(StatusIcon $monAC $defaults.MonAC)" -ForegroundColor $(if ($monAC -eq $defaults.MonAC) {"Green"} else {"Yellow"})
Write-Host "  DC: $(ToMinutes $monDC)   $(StatusIcon $monDC $defaults.MonDC)" -ForegroundColor $(if ($monDC -eq $defaults.MonDC) {"Green"} else {"Yellow"})

Write-Host ""
Write-Host "Sleep after:"
Write-Host "  AC: $(ToMinutes $sleepAC)   $(StatusIcon $sleepAC $defaults.SleepAC)" -ForegroundColor $(if ($sleepAC -eq $defaults.SleepAC) {"Green"} else {"Yellow"})
Write-Host "  DC: $(ToMinutes $sleepDC)   $(StatusIcon $sleepDC $defaults.SleepDC)" -ForegroundColor $(if ($sleepDC -eq $defaults.SleepDC) {"Green"} else {"Yellow"})

Write-Host ""
Write-Host "Lid close action:"
Write-Host "  AC: $(LidLabel $lidAC)   $(StatusIcon $lidAC $defaults.LidAC)" -ForegroundColor $(if ($lidAC -eq $defaults.LidAC) {"Green"} else {"Yellow"})
Write-Host "  DC: $(LidLabel $lidDC)   $(StatusIcon $lidDC $defaults.LidDC)" -ForegroundColor $(if ($lidDC -eq $defaults.LidDC) {"Green"} else {"Yellow"})

Write-Host ""
Write-Host "Overall Status:" -ForegroundColor Cyan
if ($monAC -eq $defaults.MonAC -and $monDC -eq $defaults.MonDC -and `
    $sleepAC -eq $defaults.SleepAC -and $sleepDC -eq $defaults.SleepDC -and `
    $lidAC -eq $defaults.LidAC -and $lidDC -eq $defaults.LidDC) {
    Write-Host "  All settings are at DEFAULT" -ForegroundColor Green
} else {
    Write-Host "  Settings have been CHANGED (Citrix likely active)" -ForegroundColor Yellow
}

Write-Host ""
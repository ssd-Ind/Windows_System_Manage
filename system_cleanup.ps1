# =============================================================================
# system_cleanup.ps1 - Windows 11 System Cleanup Script
# Run as Administrator for full effect
# Usage:
#   .\system_cleanup.ps1            # Interactive (confirms each step)
#   .\system_cleanup.ps1 -DryRun    # Preview only, nothing deleted
#   .\system_cleanup.ps1 -Yes       # Auto-confirm all steps
#   .\system_cleanup.ps1 -Help      # Show help
# =============================================================================

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

$script:TotalFreed = [long]0
$script:LogFile    = "$env:USERPROFILE\cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:IsAdmin    = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
    $clean = $Message -replace '\x1b\[[0-9;]*m', ''
    Add-Content -Path $script:LogFile -Value $clean -Encoding UTF8
}

function Write-Header  { param([string]$t) Write-Log ""; Write-Log ("=" * 56) 'Cyan'; Write-Log "  $t" 'Cyan'; Write-Log ("=" * 56) 'Cyan' }
function Write-Info    { param([string]$m) Write-Log "  -> $m" 'Gray' }
function Write-Success { param([string]$m) Write-Log "  [OK] $m" 'Green' }
function Write-Warn    { param([string]$m) Write-Log "  [!!] $m" 'Yellow' }

function Format-Bytes {
    param([long]$Bytes)
    if     ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N2} KB" -f ($Bytes / 1KB) }
    else                    { "$Bytes B" }
}

function Get-DirSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [long]0 }
    try {
        $sum = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $sum) { return [long]0 }
        return [long]$sum
    } catch { return [long]0 }
}

function Confirm-Step {
    param([string]$Prompt = "Run this step?")
    if ($Yes) { return $true }
    $ans = Read-Host "  $Prompt [y/N]"
    return ($ans -match '^[Yy]')
}

function Remove-Safely {
    param([string]$Path, [string]$Label = "")
    if (-not (Test-Path $Path)) { return }
    $size = Get-DirSize $Path
    $display = if ($Label) { $Label } else { $Path }
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would remove: $display ($(Format-Bytes $size))"
    } else {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            $script:TotalFreed += $size
            Write-Success "Removed: $display (freed $(Format-Bytes $size))"
        } catch {
            Write-Warn "Could not fully remove $display"
        }
    }
}

function Clear-FolderContents {
    param([string]$Path, [string]$Label = "")
    if (-not (Test-Path $Path)) { return }
    $size = Get-DirSize $Path
    $display = if ($Label) { $Label } else { $Path }
    Write-Info "$display -- $(Format-Bytes $size)"
    if ($size -eq 0) { Write-Info "Already empty"; return }
    if (Confirm-Step "Clear $display?") {
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would empty: $Path"
        } else {
            Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch { }
            }
            $freed = $size - (Get-DirSize $Path)
            $script:TotalFreed += $freed
            Write-Success "Freed $(Format-Bytes $freed) from $display"
        }
    }
}

# -----------------------------------------------------------------------------
if ($Help) {
    Write-Host @"

  system_cleanup.ps1 - Windows 11 Cleanup Script

  USAGE:
    .\system_cleanup.ps1            Interactive (confirm each step)
    .\system_cleanup.ps1 -DryRun    Preview only, nothing is deleted
    .\system_cleanup.ps1 -Yes       Auto-confirm all steps
    .\system_cleanup.ps1 -Help      Show this message

  WHAT IT CLEANS:
    1.  Recycle Bin
    2.  Browser caches (Chrome, Edge, Firefox, Brave, Opera, Vivaldi)
    3.  Windows Temp folders
    4.  Windows Update cache + Windows.old
    5.  System caches (Prefetch, icon cache, shader caches)
    6.  Thumbnail cache
    7.  Windows Error Reporting and crash dumps
    8.  Old restore points (keeps latest)
    9.  Package manager caches (winget, choco, scoop, pip, npm, yarn, cargo, Go, NuGet, Docker)
    10. Duplicate files in Downloads, Documents, Desktop
    11. Large file report (> 500 MB)
    12. Windows Disk Cleanup (cleanmgr)

  NOTE: Run as Administrator for full cleanup capability.

"@
    exit 0
}

# =============================================================================
# STEP 1 - Recycle Bin
# =============================================================================
function Clear-RecycleBinSafe {
    Write-Header "1. Recycle Bin"
    try {
        $shell = New-Object -ComObject Shell.Application
        $bin   = $shell.Namespace(0xA)
        $items = $bin.Items()
        $count = $items.Count
        $size  = [long]0
        foreach ($item in $items) {
            try { $size += $item.Size } catch { }
        }
        if ($count -eq 0) { Write-Info "Recycle Bin is already empty"; return }
        Write-Info "$count item(s) -- $(Format-Bytes $size)"
        if (Confirm-Step "Empty Recycle Bin?") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would empty Recycle Bin"
            } else {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                $script:TotalFreed += $size
                Write-Success "Recycle Bin emptied"
            }
        }
    } catch {
        Write-Warn "Could not access Recycle Bin"
    }
}

# =============================================================================
# STEP 2 - Browser Caches
# =============================================================================
function Clear-BrowserCaches {
    Write-Header "2. Browser Caches"

    $entries = @(
        @{ Label = "Chrome cache";      Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" }
        @{ Label = "Chrome Code Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache" }
        @{ Label = "Edge cache";        Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" }
        @{ Label = "Edge Code Cache";   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache" }
        @{ Label = "Brave cache";       Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache" }
        @{ Label = "Opera cache";       Path = "$env:APPDATA\Opera Software\Opera Stable\Cache" }
        @{ Label = "Vivaldi cache";     Path = "$env:LOCALAPPDATA\Vivaldi\User Data\Default\Cache" }
        @{ Label = "IE / Edge Legacy";  Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" }
    )

    $anyFound = $false
    foreach ($e in $entries) {
        if (Test-Path $e.Path) {
            $anyFound = $true
            Clear-FolderContents $e.Path $e.Label
        }
    }

    # Firefox profile-based cache
    $ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffBase) {
        Get-ChildItem $ffBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $cache = Join-Path $_.FullName "cache2"
            if (Test-Path $cache) {
                $anyFound = $true
                Clear-FolderContents $cache "Firefox cache ($($_.Name))"
            }
        }
    }

    if (-not $anyFound) { Write-Info "No browser cache folders found" }
}

# =============================================================================
# STEP 3 - Windows Temp Folders
# =============================================================================
function Clear-TempFolders {
    Write-Header "3. Windows Temp Folders"

    $entries = @(
        @{ Label = "User Temp (%TEMP%)";            Path = $env:TEMP }
        @{ Label = "System Temp (C:\Windows\Temp)"; Path = "C:\Windows\Temp" }
        @{ Label = "LocalAppData\Temp";             Path = "$env:LOCALAPPDATA\Temp" }
        @{ Label = "WU Download Cache";             Path = "C:\Windows\SoftwareDistribution\Download" }
    )

    foreach ($e in $entries) {
        Clear-FolderContents $e.Path $e.Label
    }
}

# =============================================================================
# STEP 4 - Windows Update Cleanup
# =============================================================================
function Clear-WindowsUpdate {
    Write-Header "4. Windows Update Leftovers"

    if (-not $script:IsAdmin) {
        Write-Warn "Skipping -- requires Administrator privileges"
        return
    }

    Write-Info "DISM StartComponentCleanup + ResetBase -- may take several minutes"
    if (Confirm-Step "Run DISM component store cleanup?") {
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would run: Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase"
        } else {
            try {
                $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
                if ($null -ne $svc -and $svc.Status -eq 'Running') {
                    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
                }
                & Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
                Write-Success "DISM cleanup complete"
                Start-Service wuauserv -ErrorAction SilentlyContinue
            } catch {
                Write-Warn "DISM cleanup encountered an error"
            }
        }
    }

    # CBS logs
    $cbsLog = "C:\Windows\Logs\CBS"
    if (Test-Path $cbsLog) {
        $size = Get-DirSize $cbsLog
        Write-Info "CBS logs: $(Format-Bytes $size)"
        if (Confirm-Step "Clear CBS logs?") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would clear CBS logs"
            } else {
                Get-ChildItem $cbsLog -Filter "*.log" -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Success "CBS logs cleared"
            }
        }
    }

    # Windows.old
    if (Test-Path "C:\Windows.old") {
        $size = Get-DirSize "C:\Windows.old"
        Write-Info "Windows.old: $(Format-Bytes $size) -- safe to remove after an OS upgrade"
        if (Confirm-Step "Remove Windows.old?") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would remove C:\Windows.old"
            } else {
                & takeown.exe /F "C:\Windows.old" /R /A /D Y 2>&1 | Out-Null
                & icacls.exe "C:\Windows.old" /grant Administrators:F /T /C /Q 2>&1 | Out-Null
                Remove-Item "C:\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Windows.old removed"
            }
        }
    }

    # Delivery Optimisation cache
    $doCache = "C:\Windows\SoftwareDistribution\DeliveryOptimization"
    if (Test-Path $doCache) {
        Clear-FolderContents $doCache "Delivery Optimisation cache"
    }
}

# =============================================================================
# STEP 5 - System Caches
# =============================================================================
function Clear-SystemCaches {
    Write-Header "5. System Caches (Prefetch, Icon, Shader)"

    if (-not $script:IsAdmin) {
        Write-Warn "Skipping system caches -- requires Administrator"
        return
    }

    # Prefetch
    $prefetch = "C:\Windows\Prefetch"
    if (Test-Path $prefetch) {
        $size = Get-DirSize $prefetch
        Write-Info "Prefetch: $(Format-Bytes $size)"
        if (Confirm-Step "Clear Prefetch? (Windows rebuilds automatically)") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would clear Prefetch folder"
            } else {
                Get-ChildItem $prefetch -Filter "*.pf" -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
                $script:TotalFreed += $size
                Write-Success "Prefetch cleared"
            }
        }
    }

    # Icon cache
    Write-Info "Icon cache -- will restart Explorer briefly"
    if (Confirm-Step "Rebuild icon cache?") {
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would rebuild icon cache"
        } else {
            $iconPattern = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*.db"
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Remove-Item $iconPattern -Force -ErrorAction SilentlyContinue
            Start-Process explorer
            Write-Success "Icon cache rebuilt"
        }
    }

    # DirectX shader cache
    $d3dCache = "$env:LOCALAPPDATA\D3DSCache"
    if (Test-Path $d3dCache) { Clear-FolderContents $d3dCache "DirectX Shader Cache" }

    # NVIDIA caches
    $nvGL = "$env:LOCALAPPDATA\NVIDIA\GLCache"
    $nvDX = "$env:LOCALAPPDATA\NVIDIA\DXCache"
    if (Test-Path $nvGL) { Clear-FolderContents $nvGL "NVIDIA GL Shader Cache" }
    if (Test-Path $nvDX) { Clear-FolderContents $nvDX "NVIDIA DX Cache" }
}

# =============================================================================
# STEP 6 - Thumbnail Cache
# =============================================================================
function Clear-ThumbnailCache {
    Write-Header "6. Thumbnail Cache"

    $thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    if (-not (Test-Path $thumbDir)) { Write-Info "No thumbnail cache found"; return }

    $thumbFiles = Get-ChildItem $thumbDir -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
    if ($null -eq $thumbFiles -or @($thumbFiles).Count -eq 0) { Write-Info "No thumbnail DB files found"; return }

    $thumbArr = @($thumbFiles)
    $size = [long]($thumbArr | Measure-Object -Property Length -Sum).Sum
    Write-Info "Thumbnail cache: $(Format-Bytes $size) ($($thumbArr.Count) files)"

    if (Confirm-Step "Clear thumbnail cache? (rebuilt automatically)") {
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would remove $($thumbArr.Count) thumbnail DB files"
        } else {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            $thumbArr | Remove-Item -Force -ErrorAction SilentlyContinue
            Start-Process explorer
            $script:TotalFreed += $size
            Write-Success "Thumbnail cache cleared"
        }
    }
}

# =============================================================================
# STEP 7 - Error Reports and Crash Dumps
# =============================================================================
function Clear-ErrorReports {
    Write-Header "7. Error Reports and Crash Dumps"

    $entries = @(
        @{ Label = "WER Archive (user)";   Path = "$env:APPDATA\Microsoft\Windows\WER\ReportArchive" }
        @{ Label = "WER Queue (user)";     Path = "$env:APPDATA\Microsoft\Windows\WER\ReportQueue" }
        @{ Label = "WER Archive (system)"; Path = "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" }
        @{ Label = "WER Queue (system)";   Path = "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" }
        @{ Label = "Minidump files";       Path = "C:\Windows\Minidump" }
        @{ Label = "Memory dump";          Path = "C:\Windows\memory.dmp" }
    )

    $anyFound = $false
    foreach ($e in $entries) {
        if (Test-Path $e.Path) {
            $anyFound = $true
            $size = Get-DirSize $e.Path
            if ($size -gt 0) {
                Write-Info "$($e.Label): $(Format-Bytes $size)"
                if (Confirm-Step "Remove $($e.Label)?") {
                    if ($DryRun) {
                        Write-Info "[DRY-RUN] Would remove $($e.Path)"
                    } else {
                        Remove-Item $e.Path -Recurse -Force -ErrorAction SilentlyContinue
                        $script:TotalFreed += $size
                        Write-Success "Removed $($e.Label)"
                    }
                }
            }
        }
    }
    if (-not $anyFound) { Write-Info "No error reports or crash dumps found" }
}

# =============================================================================
# STEP 8 - Old Restore Points
# =============================================================================
function Clear-OldRestorePoints {
    Write-Header "8. Old System Restore Points (keeps latest)"

    if (-not $script:IsAdmin) {
        Write-Warn "Skipping -- requires Administrator privileges"
        return
    }

    try {
        $rps = Get-CimInstance -ClassName SystemRestore -Namespace root\default -ErrorAction Stop
        $count = @($rps).Count
        Write-Info "Found $count restore point(s)"

        if ($count -le 1) {
            Write-Info "Only one (or zero) restore points -- nothing to prune"
            return
        }

        if (Confirm-Step "Delete all but the latest restore point?") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would run: vssadmin Delete Shadows /For=C: /Oldest"
            } else {
                & vssadmin.exe Delete Shadows /For=C: /Oldest /Quiet 2>&1 | Out-Null
                Write-Success "Old restore points removed"
            }
        }
    } catch {
        Write-Info "Could not enumerate restore points (System Restore may be disabled)"
    }
}

# =============================================================================
# STEP 9 - Package Manager Caches
# =============================================================================
function Clear-PackageManagers {
    Write-Header "9. Package Manager Caches"

    # Winget
    $wingetCache = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalCache"
    if (Test-Path $wingetCache) { Clear-FolderContents $wingetCache "Winget cache" }

    # Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        foreach ($p in @("C:\ProgramData\chocolatey\lib-bad", "C:\ProgramData\chocolatey\logs")) {
            if (Test-Path $p) { Clear-FolderContents $p "Chocolatey $(Split-Path $p -Leaf)" }
        }
    }

    # Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Info "Scoop: cleaning old app versions and download cache"
        if (Confirm-Step "Run scoop cleanup?") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would run: scoop cleanup * and scoop cache rm *"
            } else {
                & scoop cleanup * 2>&1 | Out-Null
                & scoop cache rm * 2>&1 | Out-Null
                Write-Success "Scoop cleaned"
            }
        }
    }

    # pip
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        $pipCache = (& pip cache dir 2>&1) | Select-Object -First 1
        if ($null -ne $pipCache -and (Test-Path "$pipCache")) {
            $size = Get-DirSize "$pipCache"
            Write-Info "pip cache: $(Format-Bytes $size)"
            if (Confirm-Step "Purge pip cache?") {
                if ($DryRun) { Write-Info "[DRY-RUN] Would run: pip cache purge" }
                else { & pip cache purge 2>&1 | Out-Null; Write-Success "pip cache purged" }
            }
        }
    }

    # npm
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $npmCache = (& npm config get cache 2>&1) | Select-Object -First 1
        if ($null -ne $npmCache -and (Test-Path "$npmCache")) {
            $size = Get-DirSize "$npmCache"
            Write-Info "npm cache: $(Format-Bytes $size)"
            if (Confirm-Step "Clean npm cache?") {
                if ($DryRun) { Write-Info "[DRY-RUN] Would run: npm cache clean --force" }
                else { & npm cache clean --force 2>&1 | Out-Null; Write-Success "npm cache cleaned" }
            }
        }
    }

    # yarn
    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        $yarnCache = (& yarn cache dir 2>&1) | Select-Object -First 1
        if ($null -ne $yarnCache -and (Test-Path "$yarnCache")) {
            $size = Get-DirSize "$yarnCache"
            Write-Info "Yarn cache: $(Format-Bytes $size)"
            if (Confirm-Step "Clean Yarn cache?") {
                if ($DryRun) { Write-Info "[DRY-RUN] Would run: yarn cache clean" }
                else { & yarn cache clean 2>&1 | Out-Null; Write-Success "Yarn cache cleaned" }
            }
        }
    }

    # Cargo (Rust)
    $cargoRegistry = "$env:USERPROFILE\.cargo\registry"
    if (Test-Path $cargoRegistry) {
        $size = Get-DirSize $cargoRegistry
        Write-Info "Cargo registry: $(Format-Bytes $size)"
        if (Confirm-Step "Clean Cargo registry cache?") {
            foreach ($sub in @("cache", "src")) {
                $p = Join-Path $cargoRegistry $sub
                if (Test-Path $p) { Remove-Safely $p "Cargo\registry\$sub" }
            }
        }
    }

    # Docker
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerCheck = & docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Docker: checking for unused images, containers, volumes"
            if (Confirm-Step "Run docker system prune?") {
                if ($DryRun) {
                    & docker system df 2>&1
                    Write-Info "[DRY-RUN] Would run: docker system prune -f"
                } else {
                    & docker system prune -f 2>&1 | Out-Null
                    Write-Success "Docker pruned"
                }
            }
        }
    }

    # Go
    if (Get-Command go -ErrorAction SilentlyContinue) {
        $goCache = (& go env GOCACHE 2>&1) | Select-Object -First 1
        if ($null -ne $goCache -and (Test-Path "$goCache")) {
            $size = Get-DirSize "$goCache"
            Write-Info "Go build cache: $(Format-Bytes $size)"
            if (Confirm-Step "Clean Go cache?") {
                if ($DryRun) { Write-Info "[DRY-RUN] Would run: go clean -cache -modcache" }
                else {
                    & go clean -cache 2>&1 | Out-Null
                    & go clean -modcache 2>&1 | Out-Null
                    Write-Success "Go cache cleaned"
                }
            }
        }
    }

    # NuGet
    $nugetCache = "$env:USERPROFILE\.nuget\packages"
    if (Test-Path $nugetCache) {
        $size = Get-DirSize $nugetCache
        Write-Info "NuGet packages cache: $(Format-Bytes $size)"
        if (Confirm-Step "Clear NuGet cache?") {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would run: dotnet nuget locals all --clear"
            } elseif (Get-Command dotnet -ErrorAction SilentlyContinue) {
                & dotnet nuget locals all --clear 2>&1 | Out-Null
                Write-Success "NuGet cache cleared"
            } else {
                Clear-FolderContents $nugetCache "NuGet packages"
            }
        }
    }
}

# =============================================================================
# STEP 10 - Duplicate Files
# =============================================================================
function Find-DuplicateFiles {
    Write-Header "10. Duplicate File Finder"

    $searchDirs = @(
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Desktop"
    ) | Where-Object { Test-Path $_ }

    if (@($searchDirs).Count -eq 0) {
        Write-Info "No standard directories found to scan"
        return
    }

    Write-Info "Scanning: $($searchDirs -join ', ')"
    Write-Info "Comparing MD5 checksums for files > 10 KB -- please wait..."

    if (-not (Confirm-Step "Scan for duplicates?")) { return }

    $hashMap   = @{}
    $fileCount = 0

    foreach ($dir in $searchDirs) {
        $allFiles = Get-ChildItem -Path $dir -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Length -gt 10240 }
        foreach ($f in $allFiles) {
            $fileCount++
            try {
                $hash = (Get-FileHash $f.FullName -Algorithm MD5 -ErrorAction Stop).Hash
                if (-not $hashMap.ContainsKey($hash)) {
                    $hashMap[$hash] = [System.Collections.Generic.List[object]]::new()
                }
                $hashMap[$hash].Add($f)
            } catch { }
        }
    }

    Write-Info "Scanned $fileCount files"

    $toDelete = [System.Collections.Generic.List[string]]::new()
    $dupCount = 0
    $dupSize  = [long]0

    foreach ($key in $hashMap.Keys) {
        $group = $hashMap[$key]
        if ($group.Count -lt 2) { continue }

        $sorted = $group | Sort-Object LastWriteTime -Descending
        Write-Log ""
        Write-Log "  Duplicate group (MD5: $($key.Substring(0,12))...):" 'Yellow'

        $first = $true
        foreach ($f in $sorted) {
            if ($first) {
                Write-Log "    [KEEP] $($f.FullName) ($(Format-Bytes $f.Length))" 'Green'
                $first = $false
            } else {
                Write-Log "    [DUP]  $($f.FullName) ($(Format-Bytes $f.Length))" 'Red'
                $dupCount++
                $dupSize += $f.Length
                $toDelete.Add($f.FullName)
            }
        }
    }

    Write-Log ""
    if ($dupCount -eq 0) {
        Write-Success "No duplicate files found"
        return
    }

    Write-Info "Found $dupCount duplicate file(s) -- potential savings: $(Format-Bytes $dupSize)"

    if ($Yes) {
        foreach ($f in $toDelete) {
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would delete: $f"
            } else {
                $fileSize = [long]0
                $item = Get-Item $f -ErrorAction SilentlyContinue
                if ($null -ne $item) { $fileSize = $item.Length }
                Remove-Item $f -Force -ErrorAction SilentlyContinue
                $script:TotalFreed += $fileSize
            }
        }
        if (-not $DryRun) { Write-Success "Duplicates removed" }
    } else {
        Write-Warn "Re-run with -Yes to auto-delete the duplicates listed above"
    }
}

# =============================================================================
# STEP 11 - Large Files Report
# =============================================================================
function Show-LargeFiles {
    Write-Header "11. Large File Report (> 500 MB)"
    Write-Info "Scanning user profile -- this may take a moment..."

    if (-not (Confirm-Step "Scan for large files?")) { return }

    $largeFiles = Get-ChildItem -Path $env:USERPROFILE -File -Recurse -ErrorAction SilentlyContinue |
                  Where-Object { $_.Length -gt 524288000 } |
                  Sort-Object Length -Descending |
                  Select-Object -First 25

    if (@($largeFiles).Count -eq 0) {
        Write-Info "No files over 500 MB found in user profile"
        return
    }

    Write-Log ""
    foreach ($f in $largeFiles) {
        Write-Log ("  {0,-10}  {1}" -f (Format-Bytes $f.Length), $f.FullName) 'Yellow'
    }
    Write-Log ""
    Write-Info "Review the above and delete manually as appropriate"
}

# =============================================================================
# STEP 12 - Windows Disk Cleanup
# =============================================================================
function Invoke-DiskCleanupTool {
    Write-Header "12. Windows Disk Cleanup (cleanmgr)"

    if (-not $script:IsAdmin) {
        Write-Warn "Skipping -- requires Administrator privileges"
        return
    }

    Write-Info "Opens Disk Cleanup so you can select additional categories"
    if (Confirm-Step "Launch Disk Cleanup?") {
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would run: cleanmgr /sageset:99 then /sagerun:99"
        } else {
            Write-Info "Select categories you want to clean, then click OK..."
            & cleanmgr.exe /sageset:99
            Write-Info "Running cleanup with your selections..."
            & cleanmgr.exe /sagerun:99
            Write-Success "Disk Cleanup completed"
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================
function Main {
    Write-Log ""
    Write-Log "+======================================================+" 'Cyan'
    Write-Log "|     Windows 11 System Cleanup Script v1.1           |" 'Cyan'
    Write-Log "+======================================================+" 'Cyan'
    Write-Log ""
    Write-Log "  Date:      $(Get-Date)" 'Gray'
    Write-Log "  Log file:  $script:LogFile" 'Gray'
    Write-Log "  Admin:     $script:IsAdmin" 'Gray'

    if ($DryRun) { Write-Log "  Mode:      DRY-RUN -- nothing will be deleted" 'Yellow' }
    if ($Yes)    { Write-Log "  Mode:      AUTO-CONFIRM -- all steps run without prompting" 'Yellow' }

    if (-not $script:IsAdmin) {
        Write-Log ""
        Write-Warn "Not running as Administrator -- some steps will be skipped."
        Write-Warn "For full cleanup: right-click PowerShell > Run as administrator"
    }

    Clear-RecycleBinSafe
    Clear-BrowserCaches
    Clear-TempFolders
    Clear-WindowsUpdate
    Clear-SystemCaches
    Clear-ThumbnailCache
    Clear-ErrorReports
    Clear-OldRestorePoints
    Clear-PackageManagers
    Find-DuplicateFiles
    Show-LargeFiles
    Invoke-DiskCleanupTool

    Write-Log ""
    Write-Log "+======================================================+" 'Green'
    Write-Log "|  Cleanup Complete!                                   |" 'Green'
    Write-Log "+======================================================+" 'Green'
    if ($DryRun) {
        Write-Log "  DRY-RUN: No files were actually deleted." 'Yellow'
        Write-Log "  Run without -DryRun to apply changes." 'Yellow'
    } else {
        Write-Log "  Total space freed: $(Format-Bytes $script:TotalFreed)" 'Green'
    }
    Write-Log "  Full log: $script:LogFile" 'Gray'
    Write-Log ""
}

Main
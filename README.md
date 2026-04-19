# Windows 11 Automation & Power Management Suite

A collection of PowerShell scripts designed to automate system maintenance, clean up disk space, and dynamically manage power settings—specifically tailored for users who need to prevent system sleep while running Citrix sessions.

## 📖 Table of Contents

- [Overview](#overview)
- [Repository Contents](#repository-contents)
- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Script Details](#script-details)
  - [🧹 System Cleanup (`system_cleanup.ps1`)](#-system-cleanup-system_cleanupps1)
  - [🖥️ Citrix Power Manager (`CitrixPowerManager.ps1`)](#️-citrix-power-manager-citrixpowermanagerps1)
  - [📅 Create Citrix Task Schedule (`Create_Citrix_Task_Schedule.ps1`)](#-create-citrix-task-schedule-create_citrix_task_scheduleps1)
  - [🔍 Check Power Settings (`CheckPowerSettings.ps1`)](#-check-power-settings-checkpowersettingsps1)
  - [⚡ Force Default Power (`ForceDefaultPower.ps1`)](#-force-default-power-forcedefaultpowerps1)
- [Installation & Configuration](#installation--configuration)
- [Usage Examples](#usage-examples)
- [Logging](#logging)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

This repository provides a set of PowerShell scripts that help Windows 11 (and Windows 10) users maintain their systems and manage power settings intelligently. The scripts are especially useful for remote workers who use Citrix and need to prevent the system from sleeping during active sessions.

All scripts are designed with safety in mind: they include dry‑run modes, detailed logging, and clear prompts before making any changes.

## Repository Contents

| File | Description |
| :--- | :--- |
| **`system_cleanup.ps1`** | A robust, interactive system maintenance tool that clears caches, logs, and temp files. |
| **`CitrixPowerManager.ps1`** | A background monitor that disables sleep/hibernation only when Citrix is active. |
| **`Create_Citrix_Task_Schedule.ps1`** | Installs the Citrix Power Manager as a Windows Scheduled Task (runs at logon). |
| **`CheckPowerSettings.ps1`** | A diagnostic utility to verify if power settings are at defaults or modified. |
| **`ForceDefaultPower.ps1`** | Standalone script to reset power settings to default values (monitor, sleep, lid action). |
| **`.gitignore`** | Git ignore file to exclude logs, temporary files, and IDE artifacts. |

## System Requirements

- **Operating System:** Windows 10 or Windows 11 (64‑bit recommended)
- **PowerShell Version:** 5.1 or later (included with Windows)
- **Permissions:** Most scripts require **Administrator** privileges to modify system‑level settings or access protected folders.
- **Execution Policy:** You may need to adjust the PowerShell execution policy to allow script execution:

  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

## Quick Start

1. **Clone or download** this repository to a local folder, e.g., `C:\Scripts\Windows_System_Manage`.
2. **Open PowerShell as Administrator** and navigate to the folder.
3. Run the desired script (see individual sections below for detailed usage).

## Script Details

### 🧹 System Cleanup (`system_cleanup.ps1`)

A comprehensive “all‑in‑one” maintenance utility for Windows 11. It targets deep system locations often missed by standard tools.

#### Key Features

- **Browser Maintenance:** Clears caches for Chrome, Edge, Firefox, Brave, Opera, and Vivaldi.
- **Developer Friendly:** Cleans package manager caches for **winget, Chocolatey, Scoop, pip, npm, yarn, Cargo, Go, NuGet,** and **Docker**.
- **System Optimization:** Performs DISM component store cleanup, clears Windows Update leftovers (`Windows.old`), and prunes old System Restore points.
- **File Management:** Includes a duplicate file finder (MD5 hashing) and a “Large File” report for files > 500 MB.
- **Safety First:** Features a `-DryRun` mode to preview what would be deleted without taking action.

#### Usage

Run in an **Administrative PowerShell** terminal:

```powershell
# Interactive mode (prompts for each step)
.\system_cleanup.ps1

# Preview mode (no files deleted)
.\system_cleanup.ps1 -DryRun

# Automated mode (confirms all prompts)
.\system_cleanup.ps1 -Yes

# Show help
.\system_cleanup.ps1 -Help
```

### 🖥️ Citrix Power Manager (`CitrixPowerManager.ps1`)

Designed for remote workers, this script monitors the system for the Citrix process (`wfica32`).

- **Active Mode:** When Citrix is detected, it sets monitor and standby timeouts to “Never” and ensures the lid‑close action does “Nothing.”
- **Idle Mode:** Once Citrix is closed, it automatically restores your preferred default power plan.
- **Logging:** All transitions are logged to `C:\Users\<YourUsername>\OneDrive\Scripts\CitrixPowerManager.log` (path can be adjusted in the script).

#### Installation

To ensure this runs automatically in the background:

1. Open `Create_Citrix_Task_Schedule.ps1`.
2. Ensure the file path to `CitrixPowerManager.ps1` matches your local directory.
3. Run the script as Administrator to register the Scheduled Task.

#### Manual Execution

```powershell
.\CitrixPowerManager.ps1
```

The script will run indefinitely, checking for Citrix every 30 seconds. Press `Ctrl+C` to stop it.

### 📅 Create Citrix Task Schedule (`Create_Citrix_Task_Schedule.ps1`)

This script creates a Windows Scheduled Task that launches `CitrixPowerManager.ps1` at user logon, ensuring the power manager is always running in the background.

**Important:** Before running, update the `-Argument` line inside the script to point to the correct location of `CitrixPowerManager.ps1` on your machine.

Run as Administrator:

```powershell
.\Create_Citrix_Task_Schedule.ps1
```

The task will be registered with the name “Citrix Power Manager” and will restart up to three times if it fails.

### 🔍 Check Power Settings (`CheckPowerSettings.ps1`)

A quick‑view utility to see exactly what your current power configuration is. It compares your live settings against defined “Expected Defaults” and highlights changes in **Yellow**.

**Monitored Settings:**

- Monitor Turn‑off (AC/DC)
- Sleep Timer (AC/DC)
- Lid Close Action (AC/DC)

#### Usage

```powershell
.\CheckPowerSettings.ps1
```

The script outputs a color‑coded table showing each setting’s current value, its human‑readable equivalent, and whether it matches the default.

### ⚡ Force Default Power (`ForceDefaultPower.ps1`)

Standalone script that resets power settings to the following defaults:

- Monitor timeout: **AC 30 min, DC 3 min**
- Sleep timeout: **AC/DC 60 min**
- Lid‑close action: **Sleep**

This script is useful when you want to manually restore defaults after a Citrix session or any other power‑setting change.

#### Features

- **Dry‑run mode:** Preview changes without applying them.
- **Custom logging:** Logs actions to a file (default: `%TEMP%\PowerManager.log`).
- **Administrator check:** Verifies elevated privileges before making changes.

#### Usage

```powershell
# Apply defaults (requires Administrator)
.\ForceDefaultPower.ps1

# Preview only
.\ForceDefaultPower.ps1 -DryRun

# Specify a custom log file
.\ForceDefaultPower.ps1 -LogPath "C:\Logs\power.log"

# Show help
.\ForceDefaultPower.ps1 -Help
```

## Installation & Configuration

1. **Clone the repository** (or download the ZIP) to a folder of your choice.
2. **Review each script** and adjust any hard‑coded paths (e.g., log file locations) to match your environment.
3. **Set the execution policy** (if not already set) as described in [System Requirements](#system-requirements).
4. **Test scripts** with the `-DryRun` or `-Help` switches to ensure they work as expected.

## Usage Examples

### Example 1: Perform a system cleanup in preview mode

```powershell
.\system_cleanup.ps1 -DryRun
```

### Example 2: Install the Citrix Power Manager as a scheduled task

```powershell
.\Create_Citrix_Task_Schedule.ps1
```

### Example 3: Check current power settings

```powershell
.\CheckPowerSettings.ps1
```

### Example 4: Manually reset power defaults

```powershell
.\ForceDefaultPower.ps1
```

## Logging

Most scripts write log entries to a file for later review:

- `system_cleanup.ps1` – creates a timestamped log in `%USERPROFILE%\cleanup_YYYYMMDD_HHMMSS.log`
- `CitrixPowerManager.ps1` – uses `C:\Users\<YourUsername>\OneDrive\Scripts\CitrixPowerManager.log` (adjustable)
- `ForceDefaultPower.ps1` – defaults to `%TEMP%\PowerManager.log`

Logs include timestamps, action descriptions, and any error messages.

## Troubleshooting

### “Script cannot be loaded because running scripts is disabled on this system.”

Run PowerShell as Administrator and execute:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### “Access denied” or “Administrator privileges required”

Ensure you are running PowerShell **as Administrator**. Right‑click the PowerShell icon and select “Run as Administrator.”

### Scheduled task does not start

- Verify the path to `CitrixPowerManager.ps1` in `Create_Citrix_Task_Schedule.ps1` is correct.
- Check the Task Scheduler library for errors in the “Citrix Power Manager” task.
- Ensure the user account running the task has the necessary permissions.

### Citrix Power Manager does not detect Citrix

- Confirm the Citrix process name is `wfica32` (the default). If your Citrix client uses a different process name, update the `$citrixProcess` variable in `CitrixPowerManager.ps1`.
- Check the log file for any error messages.

## Contributing

Contributions are welcome! If you have ideas for improvements, new features, or bug fixes, please:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-idea`).
3. Commit your changes (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature/your-idea`).
5. Open a Pull Request.

Please ensure your code follows the existing style and includes appropriate documentation.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Disclaimer:** These scripts are provided as‑is, without any warranty. Use them at your own risk. Always review scripts before running them, especially with administrative privileges.

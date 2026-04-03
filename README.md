This README provides a comprehensive overview of your PowerShell automation suite, designed for Windows 11 system maintenance and dynamic power management during Citrix sessions.

---

# Windows 11 Automation & Power Management Suite

A collection of PowerShell scripts designed to automate system maintenance, clean up disk space, and dynamically manage power settings—specifically tailored for users who need to prevent system sleep while running Citrix sessions.

## 📂 Repository Contents

| File | Description |
| :--- | :--- |
| **`system_cleanup.ps1`** | A robust, interactive system maintenance tool that clears caches, logs, and temp files. |
| **`CitrixPowerManager.ps1`** | A background monitor that disables sleep/hibernation only when Citrix is active. |
| **`Create_Citrix_Task_Schedule.ps1`** | Installs the Citrix Power Manager as a Windows Scheduled Task (runs at logon). |
| **`CheckPowerSettings.ps1`** | A diagnostic utility to verify if power settings are at defaults or modified. |

---

## 🧹 System Cleanup (`system_cleanup.ps1`)
This script is a comprehensive "all-in-one" maintenance utility for Windows 11. It targets deep system locations often missed by standard tools.

### Key Features
* **Browser Maintenance:** Clears caches for Chrome, Edge, Firefox, Brave, Opera, and Vivaldi.
* **Developer Friendly:** Cleans package manager caches for **winget, Chocolatey, Scoop, pip, npm, yarn, Cargo, Go, NuGet,** and **Docker**.
* **System Optimization:** Performs DISM component store cleanup, clears Windows Update leftovers (`Windows.old`), and prunes old System Restore points.
* **File Management:** Includes a duplicate file finder (MD5 hashing) and a "Large File" report for files > 500 MB.
* **Safety First:** Features a `-DryRun` mode to preview what would be deleted without taking action.

### Usage
Run in an **Administrative PowerShell** terminal:
```powershell
# Interactive mode (prompts for each step)
.\system_cleanup.ps1

# Preview mode (no files deleted)
.\system_cleanup.ps1 -DryRun

# Automated mode (confirms all prompts)
.\system_cleanup.ps1 -Yes
```

---

## 🖥️ Citrix Power Manager (`CitrixPowerManager.ps1`)
Designed for remote workers, this script monitors the system for the Citrix process (`wfica32`). 

* **Active Mode:** When Citrix is detected, it sets monitor and standby timeouts to "Never" and ensures the lid-close action does "Nothing."
* **Idle Mode:** Once Citrix is closed, it automatically restores your preferred default power plan.
* **Logging:** All transitions are logged to `C:\Users\SSD\OneDrive\Scripts\CitrixPowerManager.log`.

### Installation
To ensure this runs automatically in the background:
1. Open `Create_Citrix_Task_Schedule.ps1`.
2. Ensure the file path to `CitrixPowerManager.ps1` matches your local directory.
3. Run the script as Administrator to register the Scheduled Task.

---

## 🔍 Diagnostics (`CheckPowerSettings.ps1`)
A quick-view utility to see exactly what your current power configuration is. It compares your live settings against defined "Expected Defaults" and highlights changes in **Yellow**.

**Monitored Settings:**
* Monitor Turn-off (AC/DC)
* Sleep Timer (AC/DC)
* Lid Close Action (AC/DC)

---

## 🛠️ Requirements & Setup
* **OS:** Windows 10/11
* **Permissions:** Most scripts require **Administrator** privileges to modify system-level settings or access protected folders.
* **Execution Policy:** You may need to set your execution policy to allow scripts:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```


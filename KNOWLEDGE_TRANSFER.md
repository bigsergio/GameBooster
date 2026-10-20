# 🧠 Game Booster PRO — Architecture & Knowledge Transfer Document (v1.2.2 ➔ v2.0)

> **Document Purpose:** Complete technical handover, architectural blueprints, hard-learned lessons, and technical roadmap for developing **Game Booster PRO v2.0**.

---

## 📌 1. Project Overview & Current State (v1.2.2)

* **Repository:** `bigsergio/GameBooster`
* **Current Version:** `1.2.2` (Stable & Production-Ready)
* **License:** MIT (100% Free & Open-Source)
* **Target OS:** Windows 10 & Windows 11 (x64)
* **Core Philosophy:** 
  1. **Zero Bloat & Zero Telemetry:** 100% private, offline-capable, and non-monetized.
  2. **100% Anti-Cheat Safe:** Zero DLL injection, zero kernel drivers, zero memory tampering. Safe for Riot Vanguard, Easy Anti-Cheat (EAC), BattlEye, and Ricochet.
  3. **Low Latency by Design:** Lightweight footprint, native Win32 API calls, asynchronous threading.

---

## 🏗️ 2. High-Level Architecture & Tech Stack

```text
GameBooster/
├── assets/
│   └── gamebooster.ico               # Official cyber icon (embedded in EXE & tray)
├── src/
│   ├── Launcher/
│   │   ├── Program.cs                # Native C# single-instance elevated wrapper
│   │   └── app.manifest              # requireAdministrator Win32 manifest
│   ├── Modules/
│   │   ├── CpuOptimizer.ps1          # CPU core affinity, priority, and parking
│   │   ├── GpuManager.ps1            # GPU acceleration protection & whitelist
│   │   ├── LibraryScanner.ps1        # Steam, Epic, Battle.net, GOG, Xbox detector
│   │   ├── MemoryPurge.ps1           # Native Standby RAM & EmptyWorkingSet flush
│   │   ├── PerGameProfiles.ps1       # Game configurations, delays & profiles
│   │   ├── ServerRadar.ps1           # Multi-target ICMP gaming latency engine
│   │   ├── ShaderCleaner.ps1         # DirectX, NVIDIA & AMD shader cache cleaner
│   │   └── SystemTweaks.ps1          # Timer (0.5ms), HAGS, Game Mode, TCP NoDelay, PS7
│   ├── GameBooster.ps1               # Main WPF Dashboard interface (XAML + logic)
│   ├── GameWatcher.ps1               # Background automated game detection daemon
│   ├── TrayBooster.ps1               # Standalone Windows system tray companion
│   ├── InGameOverlay.ps1             # Click-through transparent in-game telemetry OSD
│   ├── Launch_Gaming_HUD.ps1         # Secondary monitor terminal HUD (btop + bottom)
│   ├── Save_Current_HUD_Size.ps1     # Native window snapper & coordinate recorder
│   ├── PingMonitor.ps1               # Lightweight live CLI ping monitor
│   ├── Diagnose_Crash.ps1            # Event Viewer crash diagnostic module
│   └── Export-DebugReport.ps1        # 1-click diagnostic dump for bug reports
├── config.template.json              # Clean default configuration template
├── GameBooster.exe                   # Compiled native launcher binary
├── README.md                         # Main repository presentation & documentation
└── CHANGELOG.md                      # Complete historical release changelog
```

---

## ⚙️ 3. Subsystem Breakdown

### 3.1. Native C# Launcher (`GameBooster.exe` / `Program.cs`)
* **Role:** Single-instance elevated entry point.
* **Administrator Rights:** Uses embedded `app.manifest` with `<requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>` to prevent UAC deadlocks.
* **Single Instance Mutex:** Named `Global\GameBoosterPro_SingleInstance_Mutex`. If already running, brings the existing window to the foreground instead of launching a second instance.
* **PowerShell 7 Auto-Detection:** Prioritizes modern `pwsh.exe` by checking:
  1. `%ProgramFiles%\PowerShell\7\pwsh.exe`
  2. `%ProgramFiles(x86)%\PowerShell\7\pwsh.exe`
  3. `%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe`
  4. Global `%PATH%`
  5. Falls back seamlessly to built-in Windows PowerShell 5.1 (`powershell.exe`).

### 3.2. Main WPF Dashboard (`GameBooster.ps1`)
* **Framework:** WPF rendered directly from embedded XAML strings using `[System.Windows.Markup.XamlReader]::Load()`.
* **Dark Cyberpunk Theme:** `#0B0F19` background, `#10B981` (emerald green) and `#38BDF8` (cyan) accents.
* **Asynchronous Threading:** 
  * Network pings and GitHub update queries run on isolated runspaces/thread pools to prevent WPF UI freezes.
  * Uses `Dispatcher.Invoke` for UI-thread safe element updates.
* **Key Tabs:**
  1. `🚀 Game Mode (Close Apps)`: Multi-process aggregation, memory consumption meters, 1-click boost.
  2. `🎮 Game Library & Auto-Watcher`: Automatic game discovery across 5 stores, per-game companion launcher, auto-restore toggle.
  3. `⚡ Tweaks & Radar`: 0.5ms Multimedia Timer, HAGS, Ultimate Performance power scheme, TCP NoDelay, PowerShell 7 detection, Standby RAM purge, Shader cleaner, Server Latency Radar.
  4. `🖥️ HUD & Overlays`: Terminal HUD docked on secondary displays (`btop4win`), transparent click-through in-game OSD.
  5. `🚀 Companions`: Auto-launching software (Discord, OBS, RTSS) upon game launch.
  6. `🛡️ Protected Apps`: Permanent and session whitelists, GPU driver protection.
  7. `🔄 Session Restore`: Exact snapshot of closed background apps for 1-click restoration.
  8. `🩺 Diagnostics`: Windows Event Log crash analyzer with root-cause identification and 1-click debug report generation.

---

## ⚠️ 4. Hard-Learned Rules & Technical Safeguards

These safeguards **MUST** be respected in v2.0 to prevent severe system instability or bug regressions:

### 1. Operating System & Kernel Safety Blacklist
* **Never terminate:** `csrss`, `services`, `lsass`, `wininit`, `smss`, `svchost`, `fontdrvhost`, `dwm`, `explorer`, `winlogon`, `system`, `idle`, `registry`, `memory compression`.
* **Why:** Terminating any of these causes immediate Windows BugCheck (Blue Screen: `CRITICAL_PROCESS_DIED`).
* **Implementation:** Hardcoded blacklist in `Get-RunningProcessGroups` and `Invoke-GameModeBoost`.

### 2. Peripheral Suites & Active Games Safeguard
* **Never terminate:**
  * Active games (`cod`, `cs2`, `valorant`, `fortnite`, etc.).
  * Hardware peripheral suites (`Razer Synapse`, `Logitech G HUB`, `Corsair iCUE`, `Creative Sound Blaster`, `SteelSeries Engine`).
* **Why:** Gamers lose mouse DPI, keyboard macros, audio profiles, or crash their active match.

### 3. File Encoding (UTF-8 with BOM)
* **Rule:** All `.ps1` files containing Unicode symbols or emojis **must be saved as UTF-8 with BOM (`EF BB BF`)**.
* **Why:** Windows PowerShell 5.1 reads UTF-8 without BOM as Windows-1252 / ANSI, causing parser crashes and corrupted text strings.

### 4. DataGrid In-Cell Editing Protection
* **Rule:** Always set `IsReadOnly="True"`, `CanUserDeleteRows="False"`, `CanUserResizeRows="False"`, and `SelectionUnit="FullRow"` on WPF DataGrids unless explicit cell editing is desired.
* **Why:** Default WPF DataGrid enters edit mode on click, allowing users to accidentally overwrite latency figures, paths, or process names.

### 5. `Start-Process` Argument Syntax
* **Rule:** Always pass `-Wait` as a cmdlet switch: `Start-Process -FilePath "..." -ArgumentList "..." -Wait`.
* **Why:** Passing `"-Wait"` inside `-ArgumentList` passes it to the target application, which causes PowerShell subprocesses to abort with syntax errors.

### 6. Zero Heavy Asset Bloat in Distribution
* **Rule:** Release ZIP packages must never bundle heavy showcase PNG screenshots.
* **Why:** Keeps release download size around **~100 KB** instead of 5-10 MB, enabling instant downloads and smooth in-app auto-updates. Keep only `assets/gamebooster.ico`.

---

## 💾 5. Configuration Schema (`config.json`)

```json
{
  "whitelist": [
    "steam", "discord", "spotify", "obs64"
  ],
  "sessionWhitelist": [],
  "autoRestoreOnGameExit": true,
  "checkForUpdates": true,
  "timerResolutionMs": 1.0,
  "hudPreset": "balanced",
  "hudX": 1920,
  "hudY": 0,
  "hudWidth": 960,
  "hudHeight": 540,
  "companions": [
    {
      "Name": "Discord",
      "Path": "C:\\Users\\...\\Discord.exe",
      "DelaySeconds": 2,
      "Enabled": true
    }
  ],
  "gameProfiles": {
    "cod.exe": {
      "CpuPriority": "High",
      "AffinityMask": 0,
      "CompanionApp": "Discord, obs64",
      "AutoBoostOnLaunch": true
    }
  }
}
```

---

## 🚀 6. Opportunities & Architectural Roadmap for v2.0

If rewriting or majorly upgrading to **v2.0**, consider these high-impact directions:

### 💡 Option A: Modern Native C# / .NET 8/9 WPF (Recommended)
* **Concept:** Port the PowerShell logic into pure C# with compiled WPF (.NET 8/9 or .NET 10).
* **Advantages:**
  * Instant startup time (< 100ms vs ~1.2s for PowerShell runspace boot).
  * Single self-contained `.exe` without requiring PowerShell runspaces or external `.ps1` files.
  * True asynchronous `async/await` and reactive MVVM bindings.
  * Completely eliminates antivirus false positives associated with PowerShell execution.

### 💡 Option B: Lightweight Rust + Tauri / WebView2
* **Concept:** Rust backend for system tweaking, memory purging, and Win32 APIs; modern React/Svelte/HTML UI via WebView2.
* **Advantages:**
  * Modern animated glassmorphic UI.
  * Ultra-low memory usage (< 25MB RAM).
  * Blazing fast process enumeration using Windows Native NT APIs (`NtQuerySystemInformation`).

### 🎯 Key Feature Additions for v2.0:
1. **DirectX/Vulkan In-Game OSD:** Hardware-accelerated overlay using DirectWrite or RTSS integration instead of transparent WPF window.
2. **Bufferbloat & QoS Packet Tagging:** Automatic DSCP packet priority tagging for gaming network sockets.
3. **Automated Game Launch Detection via Event Tracing (ETW):** Near-zero CPU overhead game detection replacing polling loops.
4. **Cloud / Community Game Profiles:** Community-curated optimal CPU/GPU profiles downloaded dynamically per game title.

# ⚡ Game Booster PRO v1.2

<div align="center">

![Release](https://img.shields.io/badge/Release-v1.2.0-emerald?style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Platform](https://img.shields.io/badge/Architecture-x64-black?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Zero Telemetry](https://img.shields.io/badge/Telemetry-ZERO-brightgreen?style=for-the-badge)
![Anti-Cheat Safe](https://img.shields.io/badge/Anti--Cheat-100%25%20Safe%20(No%20DLL%20Hook)-blue?style=for-the-badge)

**The Modern, Autonomous Gaming Performance & Hardware Telemetry Suite for Windows 10 & 11.**  
*Engineered for competitive esports, high-refresh displays, and micro-stutter elimination.*

[Download Latest Release](https://github.com/bigsergio/GameBooster/releases) • [Changelog](CHANGELOG.md) • [Features](#-key-features) • [Screenshots](#-interface--in-game-showcase) • [Anti-Cheat Safety](#️-anti-cheat--security-guarantee) • [Portuguese Guide](assets/infographic_pt.png)

<br>

[![Game Booster PRO Dashboard](assets/dashboard_tweaks.png)](https://github.com/bigsergio/GameBooster/releases)

</div>

---

## 📖 Overview

**Game Booster PRO v1.2** is an open-source, lightweight Windows gaming optimizer designed to maximize gaming performance, lower input latency, reclaim gigabytes of system memory, and provide real-time hardware telemetry without invasive software hooks.

Unlike legacy utilities that rely on fragile `.bat` files or inject intrusive DLLs into game processes, Game Booster PRO is built on native Win32 APIs, modern WPF rendering, and a standalone elevated C# executable launcher (`GameBooster.exe`).

> [!NOTE]
> **What's New in v1.2.0:**
> • **Critical Windows OS Subsystem Protection:** Hardcoded exclusion prevents terminating Windows core subsystems and security services (`csrss`, `services`, Defender, etc.), eliminating unintentional BugCheck reboots.
> • **Crash-Proof Server Ping Radar:** Bounded asynchronous ping engine with robust error isolation across EU datacenters (Valve CS2, Blizzard, Riot, AWS).
> • **TCP NoDelay Universal Activation:** Reliable activation across all active network adapter GUIDs on Windows 10/11.
> • **Custom Taskbar Icon & App Bar Branding:** Explicit `AppUserModelID` and Win32 icon dispatch ensure Windows Taskbar shows the custom Game Booster logo instead of PowerShell.
> • See full details in [`CHANGELOG.md`](CHANGELOG.md).

---

## 📸 Interface & In-Game Showcase

<div align="center">

### ⚡ 1-Click Tweaks, Standby Purge & Server Ping Radar
*Monitor and optimize Windows low-latency subsystems, flush standby memory, clean shader caches, and track server pings.*
![1-Click Tweaks and Radar](assets/dashboard_tweaks.png)

<br>

### 🖥️ Dual-Monitor Terminal HUD & Streamer-Branded In-Game OSD
*Dock full-screen hardware telemetry on secondary monitors (`btop4win` + `bottom` + live ping graph) alongside an unobtrusive, click-through in-game transparent OSD.*
![Hardware HUD and In-Game OSD](assets/hud_osd_showcase.png)

<br>

### 🩺 Windows Event Crash Diagnostics & Health Check
*Inspect application crashes, isolate faulting modules (`ntdll.dll`, `flutter_windows.dll`, graphics drivers), and get instant root-cause analysis.*
![Crash Diagnostics](assets/crash_diagnostics.png)

<br>

### 🚀 Automated Companion Launcher
*Automatically start your favorite companion tools (Discord, OBS, RTSS) when monitored games launch, with custom startup delays.*
![Companions & Auto-Start](assets/companions_autostart.png)

</div>

---

## ✨ Key Features

### 🚀 1. Intelligent Process Management & Grouping
- **Process Aggregation:** Multi-instance applications (such as Brave, Chrome, Edge, and Discord) are grouped into a single unified row showing combined RAM consumption, PID lists, and window titles.
- **1-Click Game Mode Activation:** Closes selected memory-heavy background applications, trims process working sets, purges cached standby memory, and activates the Windows Ultimate Performance power plan.
- **Complete Session Restoration:** Remembers exactly what was closed in the active session and allows 1-click individual or full restoration upon finishing a gaming session.

### 🎮 2. Multi-Platform Library Auto-Detector & Per-Game Profiles
- **Automatic Library Scanner:** Instantly scans and identifies games installed via Steam, Epic Games, Battle.net, GOG Galaxy, and Xbox Game Pass / Windows Store.
- **Hardware Optimizer Profiles:** Set per-game CPU Priority (`High`, `AboveNormal`), Architecture Affinity (bind to Intel P-Cores to prevent E-Core scheduler stutter, or bind to AMD 3D V-Cache CCD), custom game companion launch commands, and auto-OSD launch.
- **Profile Management:** Easily save, reload, or reset profiles to defaults.

### ⚡ 3. 1-Click Low-Latency Windows Subsystems
- **0.5ms High-Resolution Timer:** Forces Windows system timer resolution from the default 15.6ms down to `0.5ms` (`NtSetTimerResolution`), stabilizing frametimes and reducing micro-stuttering.
- **Hardware-Accelerated GPU Scheduling (HAGS):** Verifies and configures HAGS directly in the Windows registry for ultra-fast GPU memory management.
- **Windows Dedicated Game Mode:** Ensures Windows OS Game Mode thread prioritization is active.
- **TCP NoDelay Network Latency Optimizer:** Disables the Nagle packet batching algorithm on active network adapters (`TcpAckFrequency = 1`, `TCPNoDelay = 1`, `TcpDelAckTicks = 0`) to minimize network packet queuing delays in online titles.

### 🧠 4. Native Standby Cache & Working Set Cleaner
- **Real-Time Memory Counter:** Accurately reads Windows Standby Cache via `\Memory\Standby Cache Normal Priority Bytes`.
- **Zero-Dependency Purge:** Uses `NtSetSystemInformation(80)` with elevated `RtlAdjustPrivilege` to immediately flush cached standby pages and working sets without requiring external tools like RAMMap.

### 📦 5. GPU Shader Cache & Pipeline Cleaner
- Safely purges corrupted or bloated shader caches across DirectX, NVIDIA (`DXCache`, `GLCache`), AMD (`DxcCache`), and Intel graphics pipelines.
- Forces games to recompile clean shader caches on next launch, eliminating sudden texture popping and frame drops.

### 🌐 6. Gaming Server Latency Radar
- Real-time ICMP ping grid tracking latency to major game server clusters (Frankfurt, London, Amsterdam, Paris, US East/West, Tokyo, São Paulo, Sydney).
- Optional background auto-ping timer (5s interval) with color-coded quality indicators.

### 🖥️ 7. Secondary Desktop Hardware HUD
- Docks terminal-based system monitors (`btop4win` + `bottom` + live ping graph) onto secondary monitors.
- Supports 3 custom layout presets (`Tri-Pane Balanced`, `Esports Ping Focused`, `Minimal Dual-Pane`).
- Remembers window coordinates, width, height, and geometry across reboots.
- Includes 1-click **Launch**, **Force Restart**, and **Close HUD** controls.

### 🎯 8. 100% Anti-Cheat Safe In-Game Transparent OSD
- **Zero DLL Injection:** Renders an unobtrusive, glass-like telemetry overlay using Win32 `WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW` APIs.
- **Anti-Cheat Safe:** Never touches the game memory or GPU swapchain, making it 100% safe with Valorant (Vanguard), Call of Duty (Ricochet), Fortnite (Easy Anti-Cheat), Rainbow Six (BattlEye), and CS2 (VAC).
- **Customizable Brand/Streamer Tag:** Enter your custom streamer name or clan handle (e.g., `SOFEE`, `GAME BOOSTER`) in the setup field to brand the overlay.
- **Full Hotkey Control:** Press `F10` or use the UI to toggle the overlay on/off anytime.

### 🛡️ 9. Dynamic GPU Driver & Display Daemon Protection
- Automatically detects installed GPU vendor (NVIDIA GeForce, AMD Radeon, Intel Arc).
- Whitelists display driver and GPU hardware acceleration daemons (`nvcontainer`, `nvcplui`, `nvspcaps64`, `amdfendrsr`, `ArcControl`) to prevent driver crashes during cleanup.

### 🩺 10. Crash Diagnostics & Health Check
- Inspects Windows Event Log (Event ID 1000 - Application Error) for recent game crashes.
- Extracts faulting modules (`ntdll.dll`, `d3d12.dll`, graphics drivers), exception codes, and timestamps, presenting in-depth root-cause analysis and remediation steps.

---

## 📂 Architecture & Project Structure

```text
GameBooster/
├── assets/                     # Application branding, screenshots, and media
│   ├── gamebooster.ico
│   ├── dashboard_tweaks.png    # Tweaks & Server Radar screenshot
│   ├── hud_osd_showcase.png    # Live HUD & In-game OSD showcase
│   ├── crash_diagnostics.png   # Event crash diagnostics screenshot
│   ├── companions_autostart.png# Auto-start companion screenshot
│   └── infographic_pt.png      # Portuguese infographic summary
├── src/                        # Core application source code
│   ├── Launcher/               # Elevated C# Native Wrapper
│   │   ├── Program.cs          # Elevated single-instance launcher
│   │   └── app.manifest        # requireAdministrator manifest
│   ├── Modules/                # Modular subsystem engines
│   │   ├── CpuOptimizer.ps1    # CPU affinity & core parking
│   │   ├── GpuManager.ps1      # Dynamic GPU whitelist protection
│   │   ├── LibraryScanner.ps1  # Game detection across stores
│   │   ├── MemoryPurge.ps1     # Native Standby RAM & working set flush
│   │   ├── PerGameProfiles.ps1 # Per-game hardware tuning
│   │   ├── ServerRadar.ps1     # ICMP ping telemetry engine
│   │   ├── ShaderCleaner.ps1   # DirectX / NVIDIA / AMD shader purge
│   │   └── SystemTweaks.ps1    # Timer, HAGS, Game Mode, TCP NoDelay
│   ├── GameBooster.ps1         # Main WPF Dashboard interface
│   ├── InGameOverlay.ps1       # Transparent click-through OSD
│   ├── Launch_Gaming_HUD.ps1   # Terminal HUD launcher & window snapper
│   ├── PingMonitor.ps1         # Live ping telemetry script
│   ├── Save_Current_HUD_Size.ps1 # HUD geometry capture script
│   └── TrayBooster.ps1         # System tray companion & hotkey listener
├── config.template.json        # Clean, sanitized default configuration
├── GameBooster.exe             # Pre-compiled elevated executable
├── LICENSE                     # MIT Open-Source License
└── README.md                   # Complete documentation
```

---

## 🚀 Quick Start Guide

### Option 1: Run the Precompiled Binary (Recommended)
1. Download the latest release from the [GitHub Releases](https://github.com/bigsergio/GameBooster/releases) page.
2. Extract the archive to any folder or drive of your choice (e.g. `C:\Games\GameBooster` or `D:\Tools\GameBooster`).
3. Double-click **`GameBooster.exe`**.
4. Accept the Windows UAC elevation prompt (administrator privileges are required to adjust system timers, flush standby memory, and tune TCP adapters).

### Option 2: Run via PowerShell
You can also launch the dashboard directly using PowerShell 7 or Windows PowerShell 5.1:

```powershell
# Open an elevated PowerShell terminal in the project directory
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\GameBooster.ps1
```

---

## 🛠️ Building the Executable from Source

The `GameBooster.exe` binary is a lightweight C# wrapper compiled with the standard Microsoft C# compiler (`csc.exe`) built into Windows (.NET Framework 4.0+). No external SDK or Visual Studio installation is required.

To recompile:

```cmd
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:winexe /out:GameBooster.exe /win32manifest:src\Launcher\app.manifest /win32icon:assets\gamebooster.ico /reference:System.Windows.Forms.dll,System.Drawing.dll src\Launcher\Program.cs
```

---

## ⚙️ Configuration (`config.json`)

On first launch, Game Booster PRO automatically generates a local `config.json` file from `config.template.json`. Personal settings and local game lists remain entirely on your machine and are never tracked by git.

Key configuration blocks:

```json
{
  "hudSettings": {
    "launchOnBoost": true,
    "layoutPreset": "tri_pane",
    "hudX": 100,
    "hudY": 100,
    "hudWidth": 1200,
    "hudHeight": 650
  },
  "overlaySettings": {
    "enabled": true,
    "position": "TopRight",
    "titleText": "GAME BOOSTER"
  },
  "tweaksSettings": {
    "auto05msTimer": true,
    "autoPurgeStandbyOnBoost": true,
    "autoCpuAffinity": true
  }
}
```

---

## 🛡️ Anti-Cheat & Security Guarantee

- **Zero DLL Injections:** Game Booster PRO **never** injects code or hooks into any third-party game process.
- **Zero Memory Modification:** Game executables run unhindered and unmodified.
- **Standard Windows APIs:** All optimizations use official Microsoft Win32 APIs (`NtSetTimerResolution`, `NtSetSystemInformation`, `EmptyWorkingSet`, and registry subsystem keys).
- **Zero Telemetry:** The application makes **zero** outbound telemetry, diagnostic, or tracking web requests. All source code is inspectable.

---

## 🤝 Contributing

Contributions, feature suggestions, and bug reports are welcome!
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/NewFeature`).
3. Commit your changes (`git commit -m 'Add NewFeature'`).
4. Push to the branch (`git push origin feature/NewFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

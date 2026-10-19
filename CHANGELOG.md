# 📋 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.1] - 2026-10-19

### 🤖 Auto-Watcher & Background Boost Execution Fix
- **`Start-Process -Wait` Syntax Fix:** Fixed an argument placement bug in `GameWatcher.ps1` and `TrayBooster.ps1` where `"-Wait"` was passed inside `-ArgumentList` to `powershell.exe`. This caused PowerShell to abort with an unknown cmdlet error upon game detection, preventing automatic bloat closure from running. `-Wait` is now passed as a switch parameter directly on `Start-Process`, ensuring Auto-Watcher executes Game Mode boost immediately when games start and restores applications when games exit.

### 🛡️ Process Filtering & PowerShell 5.1 Compatibility
- **PowerShell 5.1 Generic HashSet Overload Fix:** Resolved a .NET Framework constructor overload failure (`[HashSet]::new($col, $comparer)`) that silently broke the "All Non-Essential" preset button and Game Mode activation loop. All sets now safely initialize via empty constructors and explicit `.Add()` calls.
- **Active Game Executable Exclusion:** `Reload-ProcessGrid` and `-Boost` now automatically exclude all monitored games, game profiles, and common game binaries (`cod`, `bootstrapper`, `BlackOps6`, `cod24`, `sp24`, `Wow`, `cs2`, etc.) from the process scanning grid and termination list. Running games can never be selected or killed.
- **Windows Services & Peripheral Protection:** Background processes managed by Windows Services (e.g. `Fing.Agent`) are now safely handled via non-blocking `sc.exe stop` / `sc.exe start` and recorded in session state for clean restoration. Gaming hardware peripherals and RGB services (Razer Chroma/Synapse, Logitech G HUB, Corsair iCUE, Creative Sound Blaster, SteelSeries) are explicitly shielded from termination.
- **CLI Interpreter Restore Guard:** Replaced bare interpreter restarts (`node`, `python`, `cmd`, `powershell`) with dedicated skip safeguards during session restoration, preventing interactive console REPL hangs.

### 🎛️ UI & Workflow Enhancements
- **Clickable Tray Companion Status Pill:** Added interactive `Cursor="Hand"`, tooltip, and click-toggle action to `PillTrayStatus` in the top header, allowing users to start and stop the Tray Companion daemon directly from the navigation bar.
- **Dynamic Tab Auto-Refresh:** Added `MainTabs.Add_SelectionChanged` listener and a periodic 4-second background timer to automatically refresh running processes and live daemon status whenever navigating back to the Game Mode dashboard.

---

## [1.2.0] - 2026-10-19

### 🛡️ Critical OS Kernel Subsystem & BugCheck Protection
- **Hardcoded Critical OS Subsystem Blacklist:** Implemented an impenetrable safety guard right at process enumeration and termination. Windows core subsystems and security services (`csrss`, `services`, `lsass`, `wininit`, `smss`, `svchost`, `fontdrvhost`, `dwm`, `explorer`, `winlogon`, `sppsvc`, `SearchIndexer`, `SecurityHealthService`, `SecurityHealthSystray`, `MsMpEng`, `NisSrv`, `MpDefenderCoreService`, `DefenderSessionHelper`, `MoUsoCoreWorker`, `RuntimeBroker`, `StartMenuExperienceHost`, `taskhostw`, `ctfmon`, `SystemSettings`, `TextInputHost`, `ShellHost`, `conhost`, `cmd`, `pwsh`, `powershell`, `wt`, `GameBooster`, `taskmgr`) can NEVER appear in the process grid and can NEVER be terminated, preventing Windows BugCheck (`CRITICAL_PROCESS_DIED`) reboots.
- **Fail-Safe Process Closure Guard:** Added a second-level check inside the `Stop-Process` loop in `Activate-GameMode` that instantly skips any protected OS subsystem or whitelisted process, guaranteeing system stability even in edge cases or corrupted state.

### 🌐 Server Ping Radar Stability & Accuracy
- **Crash-Proof Latency Radar:** Rewrote `Test-GamingRadarPing` with bounded asynchronous task execution (`Task.Wait`), per-endpoint exception isolation, and safe socket cleanup. Network interruptions, DNS resolution failures, or filtered ICMP packets now fail gracefully without freezing or crashing the application.
- **Reliable European Gaming Datacenter Endpoints:** Updated ping cluster targets to responsive, production-tested game server relays: Valve/CS2 Frankfurt (`162.254.197.1`), London (`155.133.248.1`), Stockholm (`155.133.252.1`), Blizzard Europe (`37.244.54.10`), AWS Europe Central (`dynamodb.eu-central-1.amazonaws.com`), AWS Europe West (`dynamodb.eu-west-1.amazonaws.com`), Riot Games EU (`104.160.143.212`), Cloudflare (`1.1.1.1`), and Google (`8.8.8.8`).
- **Fastest Server Metric Correction:** Fixed an issue where offline/timed-out servers (`-1 ms`) were mistakenly selected as the "Fastest Server", ensuring only valid positive roundtrip times (`> 0 ms`) are reported.
- **UI Spam Protection:** Automatically disables the "Ping All Servers Now" button while an asynchronous scan is underway, preventing socket pool exhaustion.

### ⚡ 1-Click Tweaks: TCP NoDelay (Nagle's Algorithm) Fix
- **Universal Network Interface Detection:** `Set-TcpNoDelay` now iterates across all active network adapter interface GUIDs under `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces`. Modern Windows 10/11 network stacks with dynamic DHCP or IPv6 that do not store static string IP properties in root keys are now fully supported, successfully turning the tweak badge to `ACTIVE` (green).

### 🤖 Auto-Watcher & Zero-Click Gaming Daemon
- **Dedicated Auto-Watcher Control Banner:** Added a prominent, dedicated Auto-Watcher control banner in Tab 2 ("Game Library & Profiles") with real-time status indicators (`ACTIVE (Monitoring Games)` / `OFF`) and 1-click `[ ▶ Enable Auto-Watcher ]` toggle.
- **Interactive Header Status Pill:** Added interactive cursor and click support to `PillWatcherStatus` in the top header, allowing instant daemon toggling from any tab.
- **Headless `-Boost` and `-Restore` CLI Handlers:** Implemented complete headless CLI handlers for `-Boost` and `-Restore` in `src/GameBooster.ps1`. When `GameWatcher.ps1` detects any monitored game launch, it activates Game Mode, closes non-essential background apps, logs to `last_session.json`, flushes standby RAM, and applies Ultimate Performance plan without opening a GUI window. When the game exits, it automatically re-launches all closed applications.
- **Process Grid Scope Resolution:** Resolved a variable scope trap in `Reload-ProcessGrid` where pipeline execution caused `InvokeMethodOnNull`, restoring full visibility and listing of active background applications.
- **Universal UTF-8 BOM Integrity:** Applied UTF-8 BOM encoding across all `.ps1` script files to guarantee 100% error-free parsing under Windows PowerShell 5.1.

### 🎨 Windows Taskbar & App Bar Custom Branding
- **Native Taskbar Icon & AppUserModelID:** Resolved an issue where Windows grouped Game Booster under `powershell.exe` with a generic command terminal icon. Registered explicit `AppUserModelID` (`GameBooster.Suite.PRO`) and dispatched Win32 `WM_SETICON` (`ICON_BIG` & `ICON_SMALL`) on window initialization. The Windows Taskbar, Alt+Tab app switcher, and Title Bar now consistently display the custom high-res Game Booster cyber emblem.
- **Recompiled Native C# Launcher:** `GameBooster.exe` recompiled to version 1.2.0.0 with embedded icon and administrator manifest.

---

## [1.1.0] - 2026-10-18

### 🛡️ Critical Anti-Cheat & System Protection
- **89 Essential Gaming & Audio Daemons Whitelisted by Default:** Added comprehensive protection against termination for anti-cheat software, spatial audio engines, graphics display control panels, and hardware monitoring tools.
  - **Anti-Cheat Engines:** Riot Vanguard (`vgc`, `vgk`), Easy Anti-Cheat (`EasyAntiCheat`, `EasyAntiCheat_EOS`), BattlEye (`BEService`), PunkBuster (`PnkBstrA`, `PnkBstrB`), Valve Anti-Cheat (VAC), Call of Duty Ricochet bootstrapper (`cod.exe`), FACEIT (`faceitclient`), FairFight, nProtect GameGuard, and Xigncode3.
  - **Critical Audio Services:** Windows Audio Device Graph Isolation (`audiodg`), Realtek Audio Service & Control Center (`RtkAudUService64`, `RAVCpl64`), Nahimic (`NahimicService`), Dolby Atmos (`DolbyDAX`), DTS Sound Unbound, Creative Sound Blaster, and Waves MaxxAudio.
  - **Hardware Monitors & Streaming Tools:** RTSS (RivaTuner Statistics Server), MSI Afterburner, HWiNFO64, and OBS Studio.
- **Eliminated Kernel Panic / Unexpected Reboots:** Resolved an issue where closing un-whitelisted kernel-level anti-cheats (like Vanguard) caused Windows to force an intentional BSOD / system restart (`SYSTEM_SERVICE_EXCEPTION`).

### ✨ New Features & Improvements
- **Game Mode Right-Click Context Menu:**
  - Added full right-click context menu on `GridProcesses` with automatic visual tree row selection (`PreviewMouseRightButtonDown`).
  - **🛡️ Whitelist for this Session (Keep Open):** Temporarily protects an application from closure for the current session without altering permanent configuration files.
  - **⭐ Whitelist Permanently (Always Protect):** Saves the process to `config.json` permanent whitelist and dynamically updates Tab 6.
  - **❌ Close Application Now:** Immediately terminates selected application with confirmation and logs reclaimed RAM to Session Restore.
  - **📁 Open File Location:** Opens Windows Explorer with the executable highlighted.
- **1-Click Diagnostic & System Crash Reporter:**
  - Added `Export-DebugReport.bat` (1-click double-click launcher for users).
  - Added `src/Export-DebugReport.ps1` and an in-app button (`BtnExportDebugReport`) in Tab 8.
  - Automatically queries Windows Event Logs for Unexpected Reboots (**Kernel-Power Event 41**, **BugCheck Event 1001** with Blue Screen stop codes and faulting `.sys` drivers), Application Errors (Event 1000), `last_session.json`, and `gamebooster.log`, saving a comprehensive debug report to the Desktop and opening it in Notepad.
- **Tab 6 Session Whitelist Management:**
  - Live display of "Session Only" protected processes alongside User Whitelist.
  - Ability to remove session items or permanent items directly from the Whitelist grid.
- **Restore Session Right-Click Support:**
  - Added right-click row selection to Tab 7 (`GridRestoreSession`) for seamless individual application restoration.

### 🐛 Bug Fixes & UI Polish
- **Dark ComboBox Template (High-Contrast Readability):** Replaced default Windows Aero2 light button chrome with a native dark slate ComboBox template. Selected values (such as `All Logical Cores (Default)` and HUD presets) now render in bold, crisp white (`#FFFFFF`) against dark slate (`#1E293B`), completely eliminating pale/invisible text.
- **Eliminated ContextMenu White Icon Gutter:** Applied a custom dark border template to `ContextMenu` and `MenuItem`, removing the default Windows theme's white/light icon column on the left for a seamless, unified dark aesthetic.
- **1-Click Apply All Gaming Tweaks:** Fixed missing alias `Set-TimerResolutionMaximum` in `src/Modules/SystemTweaks.ps1` that previously prevented TCP NoDelay, HAGS, and Windows Game Mode from executing synchronously.
- **Windows PowerShell 5.1 Syntax Compatibility:** Enforced UTF-8 BOM (`EF BB BF`) across all scripts, eliminating 26 parse errors when loaded under legacy Windows PowerShell 5.1 console runtimes.

---

## [1.0.0] - 2026-10-18

### 🚀 Initial Public Release
- **Core Gaming Dashboard:** 8-tab WPF interface with real-time memory and system indicators.
- **Autonomous Game Detection:** Auto-scans Steam, Epic Games, Battle.net, EA App, Ubisoft Connect, and GOG Galaxy.
- **Zero-Dependency Native Standby Purge:** Flushes Windows Standby Cache and trims working sets using `NtSetSystemInformation(80)`.
- **Secondary Desktop Hardware HUD:** Multi-pane terminal hardware monitor (`btop4win` + `bottom` + live ping graph) docking on secondary monitors.
- **Transparent In-Game OSD:** 100% anti-cheat safe click-through transparent telemetry overlay (`WS_EX_TRANSPARENT | WS_EX_LAYERED`).
- **Low-Latency Subsystem Tweaks:** 0.5ms High-Precision Timer, Hardware-Accelerated GPU Scheduling (HAGS), Windows Game Mode, and TCP NoDelay network optimization.
- **Server Latency Radar:** Live ICMP latency monitor tracking ping to major worldwide gaming server datacenters.
- **GPU Shader Cache Cleaner:** Clean purge for DirectX, NVIDIA, AMD, and Intel shader caches.
- **Single-Instance C# Native Launcher:** Standalone elevated `GameBooster.exe` compiled with `csc.exe`.

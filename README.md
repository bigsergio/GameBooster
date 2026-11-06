# ⚡ Game Booster PRO v2.0.0 (Beta)

<div align="center">

![Release](https://img.shields.io/badge/Release-v2.0.0--Beta-emerald?style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Platform](https://img.shields.io/badge/Architecture-x64-black?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Zero Telemetry](https://img.shields.io/badge/Telemetry-ZERO-brightgreen?style=for-the-badge)
![Anti-Cheat Safe](https://img.shields.io/badge/Anti--Cheat-100%25%20Safe%20(No%20DLL%20Hook)-blue?style=for-the-badge)

**The Modern, Autonomous Gaming Performance & Hardware Telemetry Suite for Windows 10 & 11.**  
*Engineered for competitive esports, high-refresh displays, and micro-stutter elimination.*

</div>

---

## 🚀 Quick Start for Beta Testers

1. **Extract the ZIP file** to any folder on your PC (e.g. `C:\Games\GameBooster` or your `Downloads\GameBooster_v2` folder).
2. **Launch the Application:**
   - Double-click **`GameBooster.exe`** (Standalone elevated launcher with automatic `Zone.Identifier` unblocking).
   *(Optional fallback and debug scripts are located in `tools/` for advanced command-line use).*
3. **Engage Game Mode:**
   - Review running background apps in the dashboard.
   - Click **⚡ ENGAGE GAME MODE** to throttle non-gaming tasks, purge cached standby RAM, activate the 0.5ms high-resolution timer, and boost CPU priority.
   - When finished gaming, click **RESTORE SESSION** (or let the **Auto-Watcher** restore everything automatically upon game exit).

---

## ✨ What's New in v2.0.0 (Beta)

### 🎯 1. 100% Anti-Cheat Safe In-Game OSD (On-Screen Display)
- **Zero DLL Injection:** Renders an ultra-fast, click-through hardware telemetry overlay using native Windows layered windows (`WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW`).
- **Rich Telemetry:** Displays live **FPS**, **1% Low Frametimes**, **CPU%**, **RAM Usage**, and **Ping (ms)**.
- **Multi-Monitor Safe:** Dynamic width clamping ensures the overlay never bleeds over onto secondary monitors.
- **Customizable:** Add your own brand or streamer clan tag in settings. Press **Ctrl+Shift+O** or use the dashboard to toggle anytime.

### 🖥️ 2. Secondary Desktop Hardware HUD
- Docks full terminal-based hardware telemetry (`btop4win` + `bottom` + live ping graph) onto your secondary display.
- Multiple presets: **Tri-Pane Balanced**, **Esports Ping Focused**, and **Minimal Dual-Pane**.
- 1-click **Launch**, **Force Restart**, and **Close HUD** from the dashboard.

### 🛡️ 3. Universal Dark Cyberpunk UI & Modals
- Replaced all legacy white Win32 message boxes with custom, high-contrast dark cyberpunk modal dialogs (`#0F172A`) featuring:
  - Color-coded borders based on dialog type (Emerald for Success/Info, Amber for Warning, Rose for Error, Sky Blue for Confirmations).
  - Drag-to-move window interaction, keyboard shortcuts (`Enter` to confirm, `Esc` to cancel).

### 🔄 4. Auto-Watcher & System Tray Companion
- **Autonomous Game Detection:** Detects when monitored games start and exit, automatically applying optimizations and restoring background apps upon closing the game.
- **Tray Companion:** Runs quietly in the notification area with a quick-access right-click menu and hotkey support (`Ctrl+F12`).

### ⚡ 5. Low-Latency Tweaks & Subsystem Optimizations
- **0.5ms System Timer:** Eliminates micro-stutters by locking system timer resolution to `0.5ms` (`NtSetTimerResolution`).
- **Memory Purge:** Flushes Windows Standby Cache and trims bloated process working sets with zero third-party dependencies (`NtSetSystemInformation`).
- **ProBalance & QoS:** Dynamic CPU affinity and EcoQoS throttling for background apps to keep all cores dedicated to your active game.
- **GPU Driver Update Checker:** Detects installed GPU (AMD Radeon / NVIDIA GeForce) and checks for driver updates.

---

## 🔒 100% Anti-Cheat & Privacy Guarantee

- **Zero DLL Injection / Zero Memory Modification:** Game Booster PRO communicates solely through documented Windows Win32 APIs. It does NOT touch game processes, game memory, or GPU swapchains.
- **Fully Anti-Cheat Compatible:** 100% safe to use alongside **Vanguard** (Valorant), **Ricochet** (Call of Duty), **Easy Anti-Cheat** (Fortnite / Apex Legends), **BattlEye** (Rainbow Six Siege), and **VAC** (Counter-Strike 2).
- **Zero Telemetry:** 100% open-source, ad-free, and contains zero trackers, analytics, or background telemetry.

---

## ☕ Support Ongoing Development
If Game Booster PRO smoothed out your frame times or improved your gaming experience, consider leaving a tip to support development!
- ☕ **Ko-Fi:** [https://ko-fi.com/psoferreira](https://ko-fi.com/psoferreira)
- 💳 **PayPal:** [https://www.paypal.com/paypalme/psoferreira](https://www.paypal.com/paypalme/psoferreira)

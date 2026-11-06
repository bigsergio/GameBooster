# 🗺️ Game Booster PRO v2.0 — Implementation Roadmap & Timeline

## 📌 Project Overview
* **Project Name:** Game Booster PRO v2.0
* **Base Architecture:** Upgraded from v1.2.2 architecture (`KNOWLEDGE_TRANSFER.md`)
* **Target Platforms:** Windows 10 & Windows 11 (x64)
* **Core Philosophy:** Zero Bloat, 100% Anti-Cheat Safe, Ultra-Low Latency

---

## 🚀 Development Phases & Milestone Tracker

### Phase 1: Quick Wins & Safety Foundation (Status: ✅ COMPLETED)
- [x] **State Restoration Watchdog (`restore_state.json` / `Watchdog.ps1`):** Automatic crash-recovery for power schemes, display resolutions, and QoS tags.
- [x] **Dynamic Display Refresh & Resolution Switching (`DisplayManager.ps1`):** Win32 `ChangeDisplaySettingsEx` per-game resolution/Hz switching.
- [x] **Working Set Trimming ("Launcher RAM Diet" in `MemoryPurge.ps1`):** Iterative Win32 `EmptyWorkingSet` for heavy background launchers (steamwebhelper, Discord, Epic, Brave, Chrome).
- [x] **Automated Power Plan Switching (`SystemTweaks.ps1`):** Switch to `Ultimate Performance` on launch and revert to baseline on exit.
- [x] **Gaming Key Lockout (`GamingLockout.ps1`):** Low-level keyboard hook (`WH_KEYBOARD_LL`) to disable Windows Key & Sticky Keys while game window is focused.
- [x] **MPO & HAGS Health Check (`SystemTweaks.ps1`):** 1-click toggle for Multiplane Overlay (`OverlayTestMode = 5`) and HAGS diagnostic status.

### Phase 2: Performance & Network Engine (Status: ✅ COMPLETED)
- [x] **User-Configurable Windows Key Lockout (`config.json` & Tab 3 UI):** Windows Key disable is now fully optional (default: OFF / unchecked) with real-time UI toggles for WinKey, StickyKeys, RAM Diet, Reverse Affinity, and Dynamic QoS.
- [x] **ETW Process Event Watcher (`GameWatcher.ps1`):** Transitioned process detection from timer polling to asynchronous kernel event tracing (`Win32_ProcessStartTrace`) for **0.00% idle CPU usage**.
- [x] **Dynamic Gaming QoS (`NetworkQoS.ps1`):** Real-time UDP/TCP packet prioritization using **DSCP 46 (Expedited Forwarding)** for game executables with automatic Watchdog rollback.
- [x] **ProBalance & EcoQoS Throttler (`ProBalance.ps1`):** Native Windows 11 Efficiency Mode (`ProcessPowerThrottling`) + Idle Priority throttling for background CPU spikes.
- [x] **Reverse-Affinity Smart Pinning (`CpuOptimizer.ps1`):** Siloes background apps (Discord, Spotify, Chrome) onto auxiliary threads (e.g. threads 12-15 on Ryzen 5800X3D or E-cores on Intel), leaving primary gaming cores 100% uncontested without touching the game process (bypassing anti-cheat blocks).

### Phase 3: Hardware Diagnostics & Tweaks (Weeks 5-6) (Status: ⏳ NEXT UP)
- [ ] **PCIe MSI Mode & High IRQ Priority:** Enumerate GPU and Network PCIe devices, toggle `MSISupported = 1`, and configure High IRQ priority.
- [ ] **USB Polling Rate & Power-Save Disabler:** Disable `EnhancedPowerManagementEnabled` on mouse, keyboard, and controller HID nodes.
- [ ] **Advanced Shader Cache Manager:** Visual disk size breakdown and 1-click cleaner for DirectX, NVIDIA, AMD, and Steam caches with registry size limits.
- [ ] **Exportable Community Tweak Profiles:** Import/export standardized JSON tweak profiles for individual games.

### Phase 4: Pro Telemetry & Monetization Polish (Weeks 7-8)
- [ ] **1% and 0.1% Lows Telemetry:** Anti-cheat-safe frametime capture via ETW / PresentMon integration on the OSD.
- [ ] **Post-Game "Why Did I Lag?" Stutter Culprit Report:** Circular buffer logging to pinpoint which background process caused a frametime spike.
- [ ] **Supporter System & Hall of Fame:** In-app non-intrusive support modal (Ko-fi, GitHub Sponsors, PayPal) and backer credits.

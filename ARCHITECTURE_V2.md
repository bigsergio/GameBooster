# 🏛️ Game Booster PRO v2.0 — Architecture & Subsystem Specification

## 1. System Vision
Game Booster PRO v2.0 transitions the tool into an elite, lightweight, anti-cheat safe gaming optimization suite. It implements core commercial features (Process Lasso Pro balance, ISLC standby clearing, ExitLag QoS packet tagging, PresentMon 1% low metrics) with zero bloat, zero telemetry, and zero kernel tampering.

```
GameBooster_v2/
├── assets/
│   └── gamebooster.ico
├── src/
│   ├── Core/                         # Core execution engine
│   │   ├── Launcher/Program.cs       # Native C# elevated single-instance wrapper
│   │   └── Watchdog.ps1              # Crash-safe rollback & state validation
│   ├── Modules/                      # Feature modules
│   │   ├── CpuOptimizer.ps1          # CPU core affinity, parking & reverse-affinity siloing
│   │   ├── DisplayManager.ps1        # Dynamic display resolution, refresh rate & vibrance
│   │   ├── GamingLockout.ps1         # Windows key & StickyKeys lockout (WH_KEYBOARD_LL)
│   │   ├── GpuManager.ps1            # GPU protection, MPO toggle & HAGS health
│   │   ├── HardwareTweaks.ps1        # PCIe MSI Mode, IRQ priority & USB polling power
│   │   ├── LibraryScanner.ps1        # Multi-launcher game detector
│   │   ├── MemoryPurge.ps1           # Standby RAM & EmptyWorkingSet launcher diet
│   │   ├── NetworkQoS.ps1            # DSCP 46 UDP QoS tagging & TCP NoDelay
│   │   ├── PerGameProfiles.ps1       # Per-game presets, companions & community profiles
│   │   ├── ProBalance.ps1            # CPU delta detection & Windows 11 EcoQoS throttling
│   │   ├── ServerRadar.ps1           # Multi-target ICMP latency engine
│   │   ├── ShaderCleaner.ps1         # DX/NVIDIA/AMD/Steam shader cache manager
│   │   └── SystemTweaks.ps1          # 0.5ms Timer, Ultimate Power Plan automation
│   ├── Telemetry/
│   │   ├── FrameMetrics.ps1          # ETW / PresentMon 1% and 0.1% low frametime engine
│   │   └── StutterReporter.ps1       # Post-game "Why Did I Lag?" root-cause analyzer
│   ├── GameBooster.ps1               # WPF Cyberpunk Dashboard
│   ├── GameWatcher.ps1               # ETW event-driven game detection daemon
│   ├── InGameOverlay.ps1             # Anti-cheat-safe transparent click-through OSD
│   ├── Launch_Gaming_HUD.ps1         # Secondary monitor terminal HUD
│   └── TrayBooster.ps1               # System tray companion
├── config.json                       # Active configuration
├── config.template.json              # Clean default configuration template
├── ROADMAP_V2.md                     # Phased milestone tracker
└── ARCHITECTURE_V2.md                # System specification
```

---

## 2. Anti-Cheat Safety Principles (Uncompromising)
1. **Zero DLL Injection:** Never inject `.dll` files into game memory or address space.
2. **Zero API Hooking on Game Functions:** Never hook `Present()`, `DirectX`, or game graphics calls inside the game process.
3. **OS-Level Kernel Tracing Only:** Telemetry relies solely on OS-level Event Tracing for Windows (`Microsoft-Windows-DxgKrnl`) and Windows Performance Counters.
4. **Reverse-Affinity Approach:** When anti-cheats (e.g. Vanguard, EAC) restrict process access, manipulate uncontested background processes (Discord, Steam, Chrome) instead of tampering with the game executable.

---

## 3. Subsystem Breakdown & Win32 Integration

| Subsystem | Underlying Win32 / OS API | Purpose |
|---|---|---|
| **DisplayManager** | `ChangeDisplaySettingsExW`, `EnumDisplaySettingsW` | Dynamic resolution & max refresh rate switching |
| **GamingLockout** | `SetWindowsHookExW` (`WH_KEYBOARD_LL`), `SystemParametersInfoW` | Blocks accidental Windows Key & Sticky Keys prompts |
| **NetworkQoS** | `New-NetQosPolicy` (PowerShell NetQoS), Group Policy | DSCP 46 expedited queueing for gaming UDP packets |
| **ProBalance** | `GetProcessTimes`, `SetPriorityClass`, `SetProcessInformation(ProcessPowerThrottling)` | Background process CPU throttling and EcoQoS (Efficiency Mode) |
| **MemoryPurge** | `NtSetSystemInformation` (`SystemMemoryListInformation`), `EmptyWorkingSet` | Standby RAM purge + Active launcher RAM trimming |
| **HardwareTweaks**| `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\...`, `Win32_USBHub` | Message Signaled Interrupts (MSI) & USB power-save lockout |
| **Watchdog** | Atomic JSON journaling (`restore_state.json`) | Immediate rollback if system reboots or game crashes unexpectedly |

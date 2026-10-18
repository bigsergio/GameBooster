# ============================================================================
# Game Booster v1.0 - Module: Game Library Auto-Detector
# Automatically discovers installed games from Steam, Battle.net, Epic, Game Pass, GOG
# ============================================================================

function Get-InstalledGamesList {
    $foundGames = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seenProcesses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # 1. STEAM SCANNER
    try {
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
        if (-not $steamPath) { $steamPath = "C:\Program Files (x86)\Steam" }
        $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"

        $libraryDirs = @()
        if (Test-Path $vdf) {
            $vdfContent = Get-Content -Path $vdf -Raw -ErrorAction SilentlyContinue
            $matches = [regex]::Matches($vdfContent, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $p = $m.Groups[1].Value -replace '\\\\', '\'
                if (Test-Path $p) { $libraryDirs += $p }
            }
        }
        if ($libraryDirs.Count -eq 0 -and (Test-Path $steamPath)) { $libraryDirs += $steamPath }

        foreach ($lib in ($libraryDirs | Select-Object -Unique)) {
            $appsDir = Join-Path $lib "steamapps"
            if (Test-Path $appsDir) {
                $manifests = Get-ChildItem -Path $appsDir -Filter "appmanifest_*.acf" -ErrorAction SilentlyContinue
                foreach ($mf in $manifests) {
                    $txt = Get-Content -Path $mf.FullName -Raw -ErrorAction SilentlyContinue
                    if ($txt -match '"name"\s+"([^"]+)"' -and $txt -match '"installdir"\s+"([^"]+)"') {
                        $gameTitle = $matches[1]
                        # Re-match for name specifically
                        $titleMatch = [regex]::Match($txt, '"name"\s+"([^"]+)"')
                        $dirMatch = [regex]::Match($txt, '"installdir"\s+"([^"]+)"')
                        $gameTitle = if ($titleMatch.Success) { $titleMatch.Groups[1].Value } else { "Steam Game" }
                        $gameDir = if ($dirMatch.Success) { $dirMatch.Groups[1].Value } else { "" }

                        # Filter out runtimes / tools
                        if ($gameTitle -match "Redistributables|SteamVR|Dedicated Server") { continue }

                        $fullGameDir = Join-Path (Join-Path $appsDir "common") $gameDir
                        $exeName = ""
                        $exePath = ""
                        if (Test-Path $fullGameDir) {
                            $exes = Get-ChildItem -Path $fullGameDir -Filter "*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                                    Where-Object { $_.Name -notmatch "unins|crash|report|setup|update|helper|redist|easyanticheat|battleye" } |
                                    Sort-Object Length -Descending
                            if ($exes -and $exes.Count -gt 0) {
                                $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exes[0].Name)
                                $exePath = $exes[0].FullName
                            }
                        }
                        if (-not $exeName) { $exeName = $gameDir -replace '\s+', '' }

                        if (-not $seenProcesses.Contains($exeName)) {
                            $seenProcesses.Add($exeName) | Out-Null
                            $foundGames.Add([PSCustomObject]@{
                                Title       = $gameTitle
                                ProcessName = $exeName
                                Platform    = "Steam"
                                ExePath     = $exePath
                            })
                        }
                    }
                }
            }
        }
    } catch {}

    # 2. EPIC GAMES SCANNER
    try {
        $epicDir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
        if (Test-Path $epicDir) {
            $manifests = Get-ChildItem -Path $epicDir -Filter "*.item" -ErrorAction SilentlyContinue
            foreach ($mf in $manifests) {
                try {
                    $json = Get-Content -Raw -Path $mf.FullName | ConvertFrom-Json
                    if ($json.DisplayName -and $json.LaunchExecutable) {
                        $exeName = [System.IO.Path]::GetFileNameWithoutExtension($json.LaunchExecutable)
                        $fullExe = Join-Path $json.InstallLocation $json.LaunchExecutable
                        if (-not $seenProcesses.Contains($exeName)) {
                            $seenProcesses.Add($exeName) | Out-Null
                            $foundGames.Add([PSCustomObject]@{
                                Title       = $json.DisplayName
                                ProcessName = $exeName
                                Platform    = "Epic Games"
                                ExePath     = $fullExe
                            })
                        }
                    }
                } catch {}
            }
        }
    } catch {}

    # 3. BATTLE.NET SCANNER
    try {
        $bnetReg = "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment"
        if (Test-Path $bnetReg) {
            $subKeys = Get-ChildItem -Path $bnetReg -ErrorAction SilentlyContinue
            foreach ($k in $subKeys) {
                $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                if ($p.InstallPath -and (Test-Path $p.InstallPath)) {
                    $title = $k.PSChildName
                    $exes = Get-ChildItem -Path $p.InstallPath -Filter "*.exe" -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -notmatch "unins|setup|update|helper|launcher|crash" } |
                            Sort-Object Length -Descending
                    if ($exes -and $exes.Count -gt 0) {
                        $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exes[0].Name)
                        if (-not $seenProcesses.Contains($exeName)) {
                            $seenProcesses.Add($exeName) | Out-Null
                            $foundGames.Add([PSCustomObject]@{
                                Title       = $title
                                ProcessName = $exeName
                                Platform    = "Battle.net"
                                ExePath     = $exes[0].FullName
                            })
                        }
                    }
                }
            }
        }
    } catch {}

    # 4. GOG GALAXY SCANNER
    try {
        $gogReg = "HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games"
        if (Test-Path $gogReg) {
            $subKeys = Get-ChildItem -Path $gogReg -ErrorAction SilentlyContinue
            foreach ($k in $subKeys) {
                $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                if ($p.gameName -and $p.path) {
                    $title = $p.gameName
                    $exePath = if ($p.exe) { Join-Path $p.path $p.exe } else { "" }
                    $exeName = if ($exePath) { [System.IO.Path]::GetFileNameWithoutExtension($exePath) } else { "" }
                    if ($exeName -and -not $seenProcesses.Contains($exeName)) {
                        $seenProcesses.Add($exeName) | Out-Null
                        $foundGames.Add([PSCustomObject]@{
                            Title       = $title
                            ProcessName = $exeName
                            Platform    = "GOG"
                            ExePath     = $exePath
                        })
                    }
                }
            }
        }
    } catch {}

    # 5. XBOX GAME PASS / MS STORE SCANNER (Real Games Only)
    try {
        $utilityPattern = "Windows|Bing|Office|YourPhone|Todos|SecHealthUI|GetHelp|MSPaint|Zune|Cortana|Edge|People|ScreenSketch|PowerAutomate|StickyNotes|DesktopAppInstaller|WidgetsPlatformRuntime|StartExperiencesApp|SysinternalsSuite|PowerShell|Terminal|Calculator|Camera|Photos|Alarms|SoundRec|WindowsStore|Outlook|FeedbackHub"

        $xboxPackages = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
            $_.SignatureKind -eq "Store" -and
            ($_.PackageFamilyName -like "*Gaming*" -or $_.PackageFamilyName -like "*Xbox*" -or $_.InstallLocation -like "*GamingRoot*") -and
            $_.Name -notmatch $utilityPattern
        }
        foreach ($pkg in $xboxPackages) {
            if ($pkg.InstallLocation -and (Test-Path $pkg.InstallLocation)) {
                $manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
                if (Test-Path $manifest) {
                    $rawXml = Get-Content -Path $manifest -Raw -ErrorAction SilentlyContinue
                    if ($rawXml -match 'Executable="([^"]+\.exe)"') {
                        $exeRel = $matches[1]
                        $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exeRel)
                        if ($exeName -and -not $seenProcesses.Contains($exeName) -and $exeName -notmatch "Calculator|Terminal|Widget|Phone|SecHealth|Paint|Snipping") {
                            $seenProcesses.Add($exeName) | Out-Null
                            $foundGames.Add([PSCustomObject]@{
                                Title       = ($pkg.Name -replace 'Microsoft\.', '' -replace '\.', ' ')
                                ProcessName = $exeName
                                Platform    = "Xbox / Store"
                                ExePath     = (Join-Path $pkg.InstallLocation $exeRel)
                            })
                        }
                    }
                }
            }
        }
    } catch {}

    return @($foundGames | Sort-Object Title)
}


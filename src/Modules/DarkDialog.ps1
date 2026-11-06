# ============================================================================
# Game Booster PRO v2.0 - Module: Dark Cyberpunk Modal Dialogs
# Universal high-contrast dark WPF dialogs matching Tip Jar styling
# ============================================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction SilentlyContinue

function Show-DarkModal {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        $Arg0,
        [Parameter(Position = 1)]
        $Arg1,
        [Parameter(Position = 2)]
        $Arg2,
        [Parameter(Position = 3)]
        $Arg3,
        [Parameter(Position = 4)]
        $Arg4
    )

    # If called with PowerShell parentheses & commas, e.g. Show-DarkModal("msg", "title"),
    # PowerShell bundles comma-separated arguments into an array in $Arg0. Unpack them:
    if ($Arg0 -is [System.Collections.IList] -and -not ($Arg0 -is [string])) {
        $rawList = $Arg0
        $Arg0 = if ($rawList.Count -gt 0) { $rawList[0] } else { $null }
        $Arg1 = if ($rawList.Count -gt 1) { $rawList[1] } else { $null }
        $Arg2 = if ($rawList.Count -gt 2) { $rawList[2] } else { $null }
        $Arg3 = if ($rawList.Count -gt 3) { $rawList[3] } else { $null }
        $Arg4 = if ($rawList.Count -gt 4) { $rawList[4] } else { $null }
    }

    # Discriminate whether first argument is an Owner Window or Message
    if ($Arg0 -is [System.Windows.Window]) {
        $Owner   = $Arg0
        $Message = if ($null -ne $Arg1) { [string]$Arg1 } else { "" }
        $Title   = if ($null -ne $Arg2 -and [string]$Arg2 -ne "") { [string]$Arg2 } else { "Game Booster PRO" }
        $Buttons = if ($null -ne $Arg3) { $Arg3 } else { [System.Windows.MessageBoxButton]::OK }
        $Icon    = if ($null -ne $Arg4) { $Arg4 } else { [System.Windows.MessageBoxImage]::Information }
    } else {
        $Owner   = $null
        $Message = if ($null -ne $Arg0) { [string]$Arg0 } else { "" }
        $Title   = if ($null -ne $Arg1 -and [string]$Arg1 -ne "") { [string]$Arg1 } else { "Game Booster PRO" }
        $Buttons = if ($null -ne $Arg2) { $Arg2 } else { [System.Windows.MessageBoxButton]::OK }
        $Icon    = if ($null -ne $Arg3) { $Arg3 } else { [System.Windows.MessageBoxImage]::Information }
    }

    # Auto-resolve owner window if not explicitly provided
    if (-not $Owner) {
        try {
            $wVar = Get-Variable -Name "window" -Scope Global,Script,Local -ErrorAction SilentlyContinue
            if ($wVar -and $wVar.Value -and ($wVar.Value -is [System.Windows.Window]) -and $wVar.Value.IsVisible) {
                $Owner = $wVar.Value
            }
        } catch {}
    }

    $btnStr  = $Buttons.ToString()
    $iconStr = $Icon.ToString()

    # Determine theme accent colors & icons
    $accentColor = "#38BDF8"  # Sky Blue default
    $iconSymbol  = [char]0x2139  # Information ℹ

    if ($iconStr -match "Error|Stop|Hand") {
        $accentColor = "#EF4444"  # Rose Red
        $iconSymbol  = [char]0x26D4  # No Entry ⛔
    } elseif ($iconStr -match "Warning|Exclamation") {
        $accentColor = "#F59E0B"  # Amber
        $iconSymbol  = [char]0x26A0  # Warning ⚠️
    } elseif ($iconStr -match "Question") {
        $accentColor = "#38BDF8"  # Sky Blue
        $iconSymbol  = "?"
    } elseif ($iconStr -match "Information|Asterisk") {
        $accentColor = "#10B981"  # Emerald
        $iconSymbol  = [char]0x26A1  # High Voltage ⚡
    }

    $dlg = New-Object System.Windows.Window
    $dlg.Title = $Title
    $dlg.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $dlg.MinWidth = 440
    $dlg.MaxWidth = 620
    $dlg.MinHeight = 180
    $dlg.MaxHeight = 650
    $dlg.WindowStyle = [System.Windows.WindowStyle]::None
    $dlg.AllowsTransparency = $true
    $dlg.Background = [System.Windows.Media.Brushes]::Transparent
    $dlg.ResizeMode = [System.Windows.ResizeMode]::NoResize

    if ($Owner -and $Owner.IsVisible) {
        $dlg.Owner = $Owner
        $dlg.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    } else {
        $dlg.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    }

    # Button layout generation
    $btnGridXaml = ""
    switch -Regex ($btnStr) {
        "YesNoCancel" {
            $btnGridXaml = @"
            <Grid Grid.Row="2" Margin="0,18,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Button Name="BtnYes" Grid.Column="0" Content="Yes" Background="#10B981" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" Height="36" Margin="0,0,6,0" Cursor="Hand"/>
                <Button Name="BtnNo" Grid.Column="1" Content="No" Background="#334155" Foreground="#F8FAFC" FontWeight="Bold" FontSize="12" Height="36" Margin="0,0,6,0" Cursor="Hand"/>
                <Button Name="BtnCancel" Grid.Column="2" Content="Cancel" Background="#1E293B" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12" Height="36" Cursor="Hand"/>
            </Grid>
"@
        }
        "YesNo" {
            $btnGridXaml = @"
            <Grid Grid.Row="2" Margin="0,18,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Button Name="BtnYes" Grid.Column="0" Content="Yes" Background="#10B981" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" Height="36" Margin="0,0,6,0" Cursor="Hand"/>
                <Button Name="BtnNo" Grid.Column="1" Content="No" Background="#334155" Foreground="#F8FAFC" FontWeight="Bold" FontSize="12" Height="36" Margin="6,0,0,0" Cursor="Hand"/>
            </Grid>
"@
        }
        "OKCancel" {
            $btnGridXaml = @"
            <Grid Grid.Row="2" Margin="0,18,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Button Name="BtnOK" Grid.Column="0" Content="OK" Background="#0284C7" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" Height="36" Margin="0,0,6,0" Cursor="Hand"/>
                <Button Name="BtnCancel" Grid.Column="1" Content="Cancel" Background="#1E293B" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12" Height="36" Margin="6,0,0,0" Cursor="Hand"/>
            </Grid>
"@
        }
        default {
            # Standard OK
            $btnGridXaml = @"
            <Grid Grid.Row="2" Margin="0,18,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="120"/>
                </Grid.ColumnDefinitions>
                <Button Name="BtnOK" Grid.Column="1" Content="OK" Background="#0284C7" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" Height="36" Cursor="Hand"/>
            </Grid>
"@
        }
    }

    $safeTitle = [System.Security.SecurityElement]::Escape($Title.ToUpper())
    $safeMsg = [System.Security.SecurityElement]::Escape($Message)

    $xaml = @"
    <Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Background="#0F172A" BorderBrush="$accentColor" BorderThickness="1.5" CornerRadius="12" Padding="22">
        <Border.Effect>
            <DropShadowEffect Color="#000000" BlurRadius="25" ShadowDepth="0" Opacity="0.85"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <Grid Grid.Row="0" Margin="0,0,0,14">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="$iconSymbol" FontSize="18" FontWeight="Bold" Margin="0,0,10,0" Foreground="$accentColor" VerticalAlignment="Center"/>
                    <TextBlock Text="$safeTitle" FontSize="14" FontWeight="ExtraBold" Foreground="$accentColor" VerticalAlignment="Center"/>
                </StackPanel>
                <Button Name="BtnCloseModal" Grid.Column="1" Content="✕" Background="Transparent" Foreground="#94A3B8" BorderThickness="0" FontSize="14" FontWeight="Bold" Width="26" Height="26" Cursor="Hand"/>
            </Grid>

            <!-- Message Body -->
            <ScrollViewer Grid.Row="1" MaxHeight="450" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                <TextBlock Text="$safeMsg" Foreground="#E2E8F0" FontSize="12.5" FontWeight="Normal" TextWrapping="Wrap" LineHeight="20"/>
            </ScrollViewer>

            <!-- Action Buttons -->
            $btnGridXaml
        </Grid>
    </Border>
"@

    $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
    $content = [System.Windows.Markup.XamlReader]::Load($reader)
    $dlg.Content = $content

    $btnClose  = $content.FindName("BtnCloseModal")
    $btnOK     = $content.FindName("BtnOK")
    $btnYes    = $content.FindName("BtnYes")
    $btnNo     = $content.FindName("BtnNo")
    $btnCancel = $content.FindName("BtnCancel")

    $script:modalDlgResult = [System.Windows.MessageBoxResult]::None

    if ($btnClose) {
        $btnClose.Add_Click({
            $script:modalDlgResult = if ($btnStr -match "YesNo") { [System.Windows.MessageBoxResult]::No } else { [System.Windows.MessageBoxResult]::Cancel }
            $dlg.Close()
        })
    }
    if ($btnOK) {
        $btnOK.Add_Click({
            $script:modalDlgResult = [System.Windows.MessageBoxResult]::OK
            $dlg.Close()
        })
    }
    if ($btnYes) {
        $btnYes.Add_Click({
            $script:modalDlgResult = [System.Windows.MessageBoxResult]::Yes
            $dlg.Close()
        })
    }
    if ($btnNo) {
        $btnNo.Add_Click({
            $script:modalDlgResult = [System.Windows.MessageBoxResult]::No
            $dlg.Close()
        })
    }
    if ($btnCancel) {
        $btnCancel.Add_Click({
            $script:modalDlgResult = [System.Windows.MessageBoxResult]::Cancel
            $dlg.Close()
        })
    }

    # Enable window dragging from the background
    $content.Add_MouseLeftButtonDown({
        try { $dlg.DragMove() } catch {}
    })

    # Keyboard shortcuts: Escape to dismiss/cancel, Enter to confirm
    $dlg.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            $script:modalDlgResult = if ($btnStr -match "YesNo") { [System.Windows.MessageBoxResult]::No } else { [System.Windows.MessageBoxResult]::Cancel }
            $dlg.Close()
        } elseif ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $script:modalDlgResult = if ($btnStr -match "YesNo") { [System.Windows.MessageBoxResult]::Yes } else { [System.Windows.MessageBoxResult]::OK }
            $dlg.Close()
        }
    })

    $dlg.ShowDialog() | Out-Null
    return $script:modalDlgResult
}

using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace GameBoosterLauncher
{
    static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        private const int SW_RESTORE = 9;

        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                // Single-Instance Window Focus Check (unless CLI arguments are passed)
                if (args.Length == 0)
                {
                    IntPtr existingWnd = IntPtr.Zero;
                    EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
                    {
                        StringBuilder sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, 256);
                        string title = sb.ToString();
                        if (title.StartsWith("Game Mode Booster", StringComparison.OrdinalIgnoreCase))
                        {
                            existingWnd = hWnd;
                            return false;
                        }
                        return true;
                    }, IntPtr.Zero);

                    if (existingWnd != IntPtr.Zero)
                    {
                        ShowWindow(existingWnd, SW_RESTORE);
                        SetForegroundWindow(existingWnd);
                        return;
                    }
                }

                // Determine Base Directory
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(baseDir, "src", "GameBooster.ps1");
                if (!File.Exists(scriptPath))
                {
                    scriptPath = Path.Combine(baseDir, "GameBooster.ps1");
                }

                if (!File.Exists(scriptPath))
                {
                    MessageBox.Show(
                        "Unable to find GameBooster.ps1 in the application directory:\n" + scriptPath,
                        "Game Booster - File Not Found",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }

                // Locate preferred PowerShell host (PowerShell 7 if installed, else Windows PowerShell)
                string psHost = "powershell.exe";
                string pwshPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                    "PowerShell", "7", "pwsh.exe"
                );
                if (File.Exists(pwshPath))
                {
                    psHost = pwshPath;
                }
                else
                {
                    string sysPowerShell = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.System),
                        "WindowsPowerShell", "v1.0", "powershell.exe"
                    );
                    if (File.Exists(sysPowerShell))
                    {
                        psHost = sysPowerShell;
                    }
                }

                // Build argument string
                StringBuilder sbArgs = new StringBuilder();
                sbArgs.Append("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ");
                sbArgs.Append("\"").Append(scriptPath).Append("\"");

                if (args.Length > 0)
                {
                    for (int i = 0; i < args.Length; i++)
                    {
                        sbArgs.Append(" ").Append(args[i]);
                    }
                }

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = psHost,
                    Arguments = sbArgs.ToString(),
                    WorkingDirectory = baseDir,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    UseShellExecute = false
                };

                Process.Start(psi);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Error launching Game Booster:\n" + ex.Message,
                    "Game Booster Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}

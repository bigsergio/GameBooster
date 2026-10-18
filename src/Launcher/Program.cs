using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("Game Booster PRO")]
[assembly: AssemblyProduct("Game Booster PRO")]
[assembly: AssemblyDescription("Autonomous Gaming Performance & Hardware Telemetry Suite for Windows")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

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

        [DllImport("kernel32.dll", EntryPoint = "DeleteFileW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool DeleteFile(string lpFileName);

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        private const int SW_RESTORE = 9;

        private static void UnblockFiles(string dir)
        {
            try
            {
                if (!Directory.Exists(dir)) return;
                string[] files = Directory.GetFiles(dir, "*.*", SearchOption.AllDirectories);
                foreach (string f in files)
                {
                    DeleteFile(f + ":Zone.Identifier");
                }
            }
            catch { }
        }

        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                // Single-Instance Window Focus Check (exact title only to avoid matching browser tabs or folders)
                if (args.Length == 0)
                {
                    IntPtr existingWnd = IntPtr.Zero;
                    EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
                    {
                        StringBuilder sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, 256);
                        string title = sb.ToString();
                        if (title.StartsWith("Game Mode Booster", StringComparison.OrdinalIgnoreCase) ||
                            title.StartsWith("Game Booster PRO", StringComparison.OrdinalIgnoreCase))
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

                // Determine Base Directory (supports any drive C:, D:, E:, etc.)
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

                // Auto-unblock any downloaded files from Windows Mark of the Web
                UnblockFiles(baseDir);

                // Locate preferred PowerShell host (PowerShell 7 if installed, else Windows PowerShell 5.1)
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
                    UseShellExecute = false,
                    RedirectStandardError = true
                };

                Process proc = Process.Start(psi);
                if (proc != null)
                {
                    // Check if process crashed immediately on startup
                    if (proc.WaitForExit(1500) && proc.ExitCode != 0)
                    {
                        string err = proc.StandardError.ReadToEnd();
                        if (string.IsNullOrWhiteSpace(err))
                        {
                            err = "Process exited with code " + proc.ExitCode;
                        }
                        MessageBox.Show(
                            "Game Booster encountered an issue during startup:\n\n" + err,
                            "Game Booster - Startup Error",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Error
                        );
                    }
                }
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

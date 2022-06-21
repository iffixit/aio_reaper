#Seems that Powershell does not guarantee avaliability of the required asseblies.
$Types = @(
    "System.Management.Automation.PSObject", `
        "System.DateTime", `
        "System.IO.FileMode", `
        "System.IO.FileAccess", `
        "System.IO.FileStream", `
        "System.Net.ServicePointManager", `
        "System.Text.Encoding", `
        "System.Net.Http", `
        "System.Xml.XmlDocument", `
        "System.Console", `
        "System.Security.Principal", `
        "System.Environment", `
        "System.Diagnostics"
)
foreach ($Type in $Types) {
    Write-Host "Loading $Type";
    try {
        [System.Reflection.Assembly]::Load([System.Reflection.AssemblyName]::new("$Type"));
        Add-Type -AssemblyName $Type | Out-Null;
    }
    catch {
        Out-Null;
    }
}
Clear-Host;

# DO REMEMBER CTRL+C breaks the pipeline!
[System.Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
[System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");

# THIS IS WINDOWS 7 WORKAROUND. DO NOT MESS WITH IT
$Code = @'
using System;
using System.Runtime.InteropServices;

public static class ConsoleHelper
{
    private const int FixedWidthTrueType = 54;
    private const int StandardOutputHandle = -11;

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern IntPtr GetStdHandle(int nStdHandle);

    [return: MarshalAs(UnmanagedType.Bool)]
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool MaximumWindow, ref FontInfo ConsoleCurrentFontEx);

    [return: MarshalAs(UnmanagedType.Bool)]
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern bool GetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool MaximumWindow, ref FontInfo ConsoleCurrentFontEx);


    private static readonly IntPtr ConsoleOutputHandle = GetStdHandle(StandardOutputHandle);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FontInfo
    {
        internal int cbSize;
        internal int FontIndex;
        internal short FontWidth;
        public short FontSize;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        //[MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.wc, SizeConst = 32)]
        public string FontName;
    }

    public static FontInfo[] SetCurrentFont(string font, short fontSize = 0)
    {
        Console.WriteLine("Set Current Font: " + font);

        FontInfo before = new FontInfo
        {
            cbSize = Marshal.SizeOf<FontInfo>()
        };

        if (GetCurrentConsoleFontEx(ConsoleOutputHandle, false, ref before))
        {

            FontInfo set = new FontInfo
            {
                cbSize = Marshal.SizeOf<FontInfo>(),
                FontIndex = 0,
                FontFamily = FixedWidthTrueType,
                FontName = font,
                FontWeight = 400,
                FontSize = fontSize > 0 ? fontSize : before.FontSize
            };

            // Get some settings from current font.
            if (!SetCurrentConsoleFontEx(ConsoleOutputHandle, false, ref set))
            {
                var ex = Marshal.GetLastWin32Error();
                Console.WriteLine("Set error " + ex);
                throw new System.ComponentModel.Win32Exception(ex);
            }

            FontInfo after = new FontInfo
            {
                cbSize = Marshal.SizeOf<FontInfo>()
            };
            GetCurrentConsoleFontEx(ConsoleOutputHandle, false, ref after);

            return new[] { before, set, after };
        }
        else
        {
            var er = Marshal.GetLastWin32Error();
            Console.WriteLine("Get error " + er);
            throw new System.ComponentModel.Win32Exception(er);
        }
    }
}
'@
$IsWindows7 = $false;
$WinVer = [System.Environment]::OSVersion.Version
if ($Winver.Major -lt 10) {
    if ($Winver.Minor -lt 2) {
        $IsWindows7 = $true;
    }
}
if (-not ([System.Management.Automation.PSTypeName]'ConsoleHelper').Type) {
    Add-Type -TypeDefinition $Code -Language CSharp;
}
if ($IsWindows7) {
    [ConsoleHelper]::SetCurrentFont("Consolas", 16) | Out-Null;
}
#END OF WINDOWS 7 WORKAROUND

# WebClient is outdated. Use HttpClient instead.
if (-not ([System.Management.Automation.PSTypeName]"System.Net.Http").Type ) {
    Add-Type -AssemblyName System.Net.Http;
}


[xml]$XMLConfig = Get-Content -Path (".\\settings.xml");
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
try{
    $host.UI.RawUI.BufferSize.Width = 150 | Out-Null;
    $host.UI.RawUI.WindowSize.Width = 149 | Out-Null;
    $host.UI.RawUI.MaxWindowSize.Width = 149 | Out-Null;
    [System.Console]::bufferwidth = 150 | Out-Null;
}
catch {
    Out-Null
}
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent());
$IsAdmin = $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator);
if ($IsAdmin) {
    [Console]::Beep();
    $Message = $XMLConfig.config.messages.runningadmin;
    Write-Host $Message;
    Read-Host "Press enter to exit";
    exit
}

$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\\" + $InstallFolder;
Set-Location $RootDir;
. $("$RootDir\\functions.ps1");
$PwshDir = $("$RootDir\\$($XMLConfig.config.folders.posh)\\");
$PwshExe = $("$PwshDir\\pwsh.exe");
$UpdateCheckTime = $XMLConfig.config.timers.main;
$FreeMem = Get-FreeRamGB;
$RamLimit = $XMLConfig.config.limits.RAM
$LiteMode = $false
if ($FreeMem -lt $RamLimit) {
    $LiteMode = $true;
}
$RunnerURL = $XMLConfig.config.links.runner;
$NewStartRequired = $true;
$TitleStarted = $XMLConfig.config.titles.started;
$TitleOK = $XMLConfig.config.titles.ok;
$TitleRestart = $XMLConfig.config.titles.restart;
$TitleError = $XMLConfig.config.titles.error;
$TitleExiting = $XMLConfig.config.titles.exiting;
$TitleCompleted = $XMLConfig.config.titles.completed;
$host.UI.RawUI.WindowTitle = $TitleStarted;
Get-File $RunnerURL $("$RootDir\\runner.ps1") | Out-Null
Get-File $UpdaterURL $("$RootDir\\updater.ps1") | Out-Null
try {
    while ($true) {
        if ($NewStartRequired) {
            $UpdaterProc = Start-Process -FilePath $PwshExe `
                -ArgumentList "$RootDir\\updater.ps1" `
                -NoNewWindow -PassThru -WorkingDirectory $RootDir -Wait;
            if ($LiteMode) {
                $RunnerProc = Start-Process -FilePath $PwshExe `
                    -ArgumentList "$RootDir\\runner.ps1 -args '-lite'" `
                    -NoNewWindow -PassThru -WorkingDirectory $RootDir;
                $NewStartRequired = $false
            }
            else {
                $RunnerProc = Start-Process -FilePath $PwshExe `
                    -ArgumentList "$RootDir\\runner.ps1" `
                    -NoNewWindow -PassThru -WorkingDirectory $RootDir;
                $NewStartRequired = $false
            }
            $RunnerProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
        }
        while ($null -eq $RunnerProc.Id) {
            Start-Sleep -Seconds 1;
        }
        $Now = [System.DateTime]::Now;
        $NextCheck = $Now.AddMinutes($UpdateCheckTime);
        while ($Now -lt $NextCheck -and -not $NewStartRequired) {
            $host.UI.RawUI.WindowTitle = $TitleOK;
            if ($RunnerProc.HasExited) {
                $NewStartRequired = $true;
                $host.UI.RawUI.WindowTitle = $TitleRestart;
            }
            $testRunnerProc = Get-Process -Id $RunnerProc.Id;
            if (-not $testRunnerProc) {
                $NewStartRequired = $true;
                $host.UI.RawUI.WindowTitle = $TitleRestart;
            }
            Start-Sleep -Seconds 1;
        }
        if ($NewStartRequired) {
            Stop-Tree $RunnerProc.Id;
            $UpdaterURL = $XMLConfig.config.links.updater;
            $TitleUpdating = $XMLConfig.config.title.updating;
            $host.UI.RawUI.WindowTitle = $TitleUpdating
            $UpdaterProc = Start-Process -FilePath $PwshExe `
                -ArgumentList "$RootDir\\updater.ps1" `
                -NoNewWindow -PassThru -WorkingDirectory $RootDir -Wait;
        }
        Get-File $RunnerURL $("$RootDir\\runner_new.ps1");
        $Now = [System.DateTime]::Now;
        $File = Get-Item $("$RootDir\\runner.ps1");
        $File.LastWriteTime = $Now;
        $File = Get-Item $("$RootDir\\runner_new.ps1");
        $File.LastWriteTime = $Now;
        $GotNewVersion = FilesAreEqual $("$RootDir\\runner.ps1") $("$RootDir\\runner_new.ps1");
        if ($GotNewVersion) {
            $NewStartRequired = $true;
            Stop-Tree $RunnerProc.Id;
            Remove-Item -Path $("$RootDir\\runner.ps1") -Force;
            Rename-Item -Path $("$RootDir\\runner_new.ps1") -NewName $("$RootDir\\runner.ps1");
        }
    }
}
catch {
    $host.UI.RawUI.WindowTitle = $TitleError;
    Write-Host "Error: $($_.Exception.Message)";
    Write-Host "$($_.StackTrace)";
    Stop-Tree $RunnerProc.Id -Force;
}
finally {
    $host.UI.RawUI.WindowTitle = $TitleExiting;
    Stop-Tree $RunnerProc.Id -Force;
    Remove-Item -Path $("$RootDir\\runner.ps1") -Force;
    Clear-Host;
    $host.UI.RawUI.WindowTitle = $TitleCompleted;
    $Message = $XMLConfig.config.messages.endrun;
    Write-Host "$Message";
    $Message = $XMLConfig.config.messages.pressenter;
    Read-Host "$Message"
}
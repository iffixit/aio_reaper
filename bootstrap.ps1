#Requires -Version 5
function Clear-Line ([String] $Message) {
    [int] $Width = $Host.UI.RawUI.WindowSize.Width;
    $Line = " " * $($Width - 1);
    Write-Host "$Line`r" -NoNewline;
    Write-Host "$([System.DateTime]::Now) $Message`r" -NoNewline;
}

function Get-File ($URL, [String] $FileName) {
    $httpClient = New-Object System.Net.Http.HttpClient;
    $httpClient.DefaultRequestHeaders.Add("Cache-Control", "no-cache");
    $Response = $httpClient.GetAsync($URL);
    $Response.Wait();
    $FileStream = New-Object System.IO.FileStream($FileName, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write);
    $DownloadTask = $Response.Result.Content.CopyToAsync($FileStream);
    $DownloadTask.Wait();
    $FileStream.Close();
    $httpClient.Dispose();
}

################################################################################
# WINDOWS 7 Workaround
################################################################################
# THIS IS WINDOWS 7 WORKAROUND. DO NOT MESS WITH IT
$Code = @'using System;
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
}'@
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
    [ConsoleHelper]::SetCurrentFont("Consolas", 16);
}
#END OF WINDOWS 7 WORKAROUND

################################################################################
# Settings
################################################################################

# We need this because default PoSH network protocol is outdated.
try {
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
}
catch {
    $p = [Enum]::ToObject([System.Net.SecurityProtocolType], 3072);
    [System.Net.ServicePointManager]::SecurityProtocol = $p;
}
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http;

#TODO: Somehow move that into better place
$SettingsLink = "https://raw.githubusercontent.com/ahovdryk/aio_reaper/main/settings.xml";
$XMLConfig = New-Object System.Xml.XmlDocument;
$XMLConfig.Load($SettingsLink);

$ActionPreference = $XMLConfig.config.erroraction;
$ErrorActionPreference = $ActionPreference;
$ProgressPreference = $ActionPreference;
$WarningPreference = $ActionPreference;

$InstallFolder = $XMLConfig.config.folders.install;
$SoftwareName = $XMLConfig.config.name;

# Setting up UI
$host.ui.RawUI.WindowTitle = "Installing $SoftwareName.";
$host.ui.RawUI.BackgroundColor = 'Black';
$host.ui.RawUI.ForegroundColor = 'Green';
Clear-Host

# Locations
$GitStandalone32 = $XMLConfig.config.links.git;
$PythonStandalone32 = $XMLConfig.config.links.py32;
$PythonStandalone64 = $XMLConfig.config.links.py64;
$PythonStandaloneWin7 = $XMLConfig.config.links.pywin7;
$PwshStandalone32 = $XMLConfig.config.links.posh32;
$PwshStandalone64 = $XMLConfig.config.links.posh64;
$Is64bit = $false;
$IsWindows7 = $false;
$IconLink = $XMLConfig.config.links.icon;
$KickstartURL = $XMLConfig.config.links.kickstart;

################################################################################
# Script logic
################################################################################

# Since system drive is the only one MUST be in the users system, we use system drive.
# Installing somewhere else would ruin the unattended idea.
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$FreeSpace = [Int64] ((Get-CimInstance win32_logicaldisk | Where-Object "Caption" -eq "$SystemDrive" | Select-Object -ExpandProperty FreeSpace) / 1Gb);
$Message = "[Placeholder]"
[Int]$Lowdisk = $XMLConfig.config.limits.lowdisk;
if ($FreeSpace -lt $Lowdisk) {
    $Message = $XMLConfig.config.messages.lowdiskspace;
    Write-Host $Message;
    [Console]::Beep();
    #TODO: Add article launch about risks of using low system drive space.
    #TODO: Add article launch about how to free up space.
}
[Int]$DiskLimit = $XMLConfig.config.limits.disk
if ($FreeSpace -lt $DiskLimit) {
    [System.Console]::Beep();
    $Message = $XMLConfig.config.messages.insufficientspace;
    Write-Host $Message;
    Read-Host -Prompt "Press Enter to exit";
    exit;
}
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());
$IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
if ($IsAdmin) {
    [Console]::Beep();
    $Message = $XMLConfig.config.messages.runningadmin;
    Write-Host $Message;
    Read-Host "Press enter to exit";
    exit
}

if ((Get-CimInstance Win32_OperatingSystem | Select-Object OSArchitecture).OSArchitecture -eq "64-bit") {
    $Is64bit = $true;
}

# Creating software root folder
$RootDir = $SystemDrive + "\" + $InstallFolder;
if (!(Test-Path $RootDir)) {
    New-Item -ItemType Directory -Path $RootDir | Out-Null;
}
if (Test-Path $RootDir) {
    Set-Location $RootDir;
} # TODO Error checking here


$GitPath = $XMLConfig.config.folders.git;
if (!(Test-Path "$RootDir\\$GitPath")) {
    $Message = $XMLConfig.config.messages.downloading;
    Clear-Line $("$Message git...");
    $Message = $XMLConfig.config.messages.unpacking
    Get-File $GitStandalone32 "$RootDir\\gitinst.exe";
    Clear-Line $("$Message git...");
    Start-Process -FilePath "gitinst.exe" -ArgumentList "-o `"$RootDir\\$GitPath`" -y" -WindowStyle Hidden -Wait;
}
$GitExe = $("$RootDir\\$GitPath\\bin\\git.exe");
if (Test-Path "$RootDir\\gitinst.exe") {
    Remove-Item "$RootDir\\gitinst.exe" -Force;
}
$PyString = "[placeholder]";
$PyPath = $XMLConfig.config.folders.python;
if (!(Test-Path "$RootDir\$PyPath")) {
    $Message = $XMLConfig.config.messages.downloading;
    Clear-Line $("$Message Python...");
    if ($IsWindows7) {
        Get-File $PythonStandaloneWin7 "$RootDir\\python.zip";
        $PyString = "python38";
    }
    elseif ($Is64bit) {
        Get-File $PythonStandalone64 "$RootDir\\python.zip";
        $PyString = "python310";
    }
    else {
        Get-File $PythonStandalone32 "$RootDir\\python.zip";
        $PyString = "python310";
    }
    $Message = $XMLConfig.config.messages.unpacking;
    Clear-Line "$Message Python...";
    Expand-Archive -Path "python.zip" -DestinationPath "$RootDir\\$PyPath";
    $PythonFolder = $("$RootDir\\$PyPath")
    $PythonExe = $PythonFolder + "\\" + "python.exe";

    Set-Location $PythonFolder;
    $Message = $XMLConfig.config.messages.pythonmodule;
    Clear-Line "$Message pip...";
    $Strings = "$PyString.zip`r`n" + `
        ".`r`n" + `
        "..\$($XMLConfig.config.folders.load)`r`n" + `
        "`r`n" + `
        "# Uncomment to run site.main() automatically`r`n" + `
        "import site`r`n"
    $Strings | Set-Content -Path "$PythonFolder\\$PyString._pth";
    $PipInstaller = "https://bootstrap.pypa.io/get-pip.py";
    Get-File $PipInstaller "$PythonFolder\\get-pip.py";
    Start-Process -FilePath $PythonExe -ArgumentList "$PythonFolder\\get-pip.py" -WindowStyle Hidden -Wait;
    Start-Process -FilePath $PythonExe -ArgumentList "-m pip install --upgrade pip" -WindowStyle Hidden -Wait;
}
Set-Location $RootDir;
if (Test-Path "$RootDir\\python.zip") {
    Remove-Item "$RootDir\\python.zip" -Force;
}
$PythonFolder = $("$RootDir\\$PyPath")
$PythonExe = $PythonFolder + "\\" + "python.exe";

$PoshPath = $XMLConfig.config.folders.posh;
if (!(Test-Path "$RootDir\\$PoshPath")) {
    $Message = $XMLConfig.config.messages.downloading;
    Clear-Line $("$Message PowerShell Core...");
    if ($Is64bit) {
        Get-File $PwshStandalone64 "$RootDir\\pwsh.zip";
    }
    else {
        Get-File $PwshStandalone32 "$RootDir\\pwsh.zip";
    }
    $Message = $XMLConfig.config.messages.unpacking;
    Clear-Line $("$Message PowerShell Core...");
    Expand-Archive -Path "pwsh.zip" -DestinationPath "$RootDir\\$PoshPath";
}
if (Test-Path "$RootDir\\pwsh.zip") {
    Remove-Item "$RootDir\\pwsh.zip" -Force;
}

Set-Location $RootDir;
$Message = $XMLConfig.config.messages.unpacking;
$LoadURL = $XMLConfig.config.links.load;
$LoadPath = $RootDir + "\\" + $XMLConfig.config.folders.load + "\\";
Clear-Line $("$Message load")
$GitArgs = "clone $LoadURL $LoadPath";
Start-Process -FilePath $GitExe -ArgumentList $GitArgs -Wait -WindowStyle Hidden;

Set-Location $LoadPath;
Clear-Line $("$Message requirements.txt")
$PyArgs = "-m pip install -r requirements.txt";
Start-Process -FilePath $PythonExe -ArgumentList $PyArgs -WindowStyle Hidden -Wait;

$PwshExe = $RootDir + "\\" + $PoshPath + "\\pwsh.exe";
Get-File $IconLink "$RootDir\\1984PC.ico";
Get-File $KickstartURL "$RootDir\\kickstart.ps1";
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$ShortcutPath = $("$DesktopPath\$SoftwareName.lnk");
$WScriptShell = New-Object -ComObject WScript.Shell;
$Shortcut = $WScriptShell.CreateShortCut($ShortcutPath);
$Shortcut.TargetPath = $PwshExe;
$Shortcut.IconLocation = "$RootDir\\1984PC.ico";
$Shortcut.Arguments = "-NoLogo -NoProfile -Command $RootDir\\kickstart.ps1";
$Shortcut.WorkingDirectory = "$RootDir";
$Shortcut.Save();

$Message = $XMLConfig.config.messages.installcomplete;
Clear-Line "$Message`n";
$Message = $XMLConfig.config.messages.pressenter;
Read-Host "$Message"
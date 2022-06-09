function Clear-Line ([String] $Message) {
    [int] $Width = $Host.UI.RawUI.WindowSize.Width;
    $Line = " " * $($Width - 1);
    Write-Host "$Line`r" -NoNewline;
    Write-Host "$([System.DateTime]::Now) $Message`r" -NoNewline;
}

function Get-File ($URL, [String] $FileName) {
    $httpClient = New-Object System.Net.Http.HttpClient;
    $Response = $httpClient.GetAsync($URL);
    $Response.Wait();
    $FileStream = New-Object System.IO.FileStream($FileName, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write);
    $DownloadTask = $Response.Result.Content.CopyToAsync($FileStream);
    $DownloadTask.Wait();
    $FileStream.Close();
    $httpClient.Dispose();
}


################################################################################
# Settings
################################################################################

# We need this because default PoSH network protocol is outdated.
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
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
$PythonStandalone32 = $XMLConfig.config.links.py32
$PythonStandalone64 = $XMLConfig.config.links.py64
$PwshStandalone32 = $XMLConfig.config.links.posh32
$PwshStandalone64 = $XMLConfig.config.links.posh64
$Is64bit = $false;

$FunctionsURL = $XMLConfig.config.links.funclib;

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

$PyPath = $XMLConfig.config.folders.python;
if (!(Test-Path "$RootDir\$PyPath")) {
    $Message = $XMLConfig.config.messages.downloading;
    Clear-Line $("$Message Python...");
    if ($Is64bit) {
        Get-File $PythonStandalone64 "$RootDir\\python.zip";
    }
    else {
        Get-File $PythonStandalone32 "$RootDir\\python.zip";
    }
    $Message = $XMLConfig.config.messages.unpacking;
    Clear-Line "$Message Python...";
    Expand-Archive -Path "python.zip" -DestinationPath "$RootDir\\$PyPath";
    $PythonFolder = $("$RootDir\\$PyPath")
    $PythonExe = $PythonFolder + "\\" + "python.exe";

    Set-Location $PythonFolder;
    $Message = $XMLConfig.config.messages.pythonmodule;
    Clear-Line "$Message pip...";
    @'
python310.zip
.

# Uncomment to run site.main() automatically
import site
'@ | Set-Content -Path "$PythonFolder\\python310._pth";
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

$Message = $XMLConfig.config.messages.installcomplete;
Clear-Line $Message
$PwshExe = $RootDir + "\\" + $PoshPath + "\\pwsh.exe";
$MainScriptUrl = $XMLConfig.config.links.main;
Get-File $MainScriptUrl "$RootDir\\main.ps1";
Get-File $SettingsLink "$RootDir\\settings.xml";
Get-File $FunctionsURL "$RootDir\\functions.ps1";
$Proc = Start-Process -FilePath $PwshExe -ArgumentList "-NoLogo -NoProfile -NoExit -Command $RootDir\\main.ps1" -WorkingDirectory $RootDir -PassThru;
$Proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
exit
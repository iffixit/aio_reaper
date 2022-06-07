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
Get-File $SettingsLink "settings.xml";
[xml]$XMLConfig = Get-Content -Path ("settings.xml");

$ActionPreference = $XMLConfig.config.erroraction.'#text';
$ErrorActionPreference = $ActionPreference;
$ProgressPreference = $ActionPreference;
$WarningPreference = $ActionPreference;

$InstallFolder = $XMLConfig.config.name.'#text';
$SoftwareName = $XMLConfig.config.folders.install.'#text';

# Setting up UI
$host.ui.RawUI.WindowTitle = "Installing $SoftwareName.";
$host.ui.RawUI.BackgroundColor = 'Black';
$host.ui.RawUI.ForegroundColor = 'Green';
# Locations
$GitStandalone32 = Get-URLContent $($XMLConfig.config.links.git.'#text');
$PythonStandalone32 = $XMLConfig.config.links.py32.'#text'
$PythonStandalone64 = $XMLConfig.config.links.py64.'#text'
$PwshStandalone32 = $XMLConfig.config.links.posh32.'#text'
$PwshStandalone64 = $XMLConfig.config.links.posh64.'#text'
$Is64bit = $false;

$FunctionsURL = $XMLConfig.config.links.funclib.'#text';

################################################################################
# Script logic
################################################################################

# Since system drive is the only one MUST be in the users system, we use system drive.
# Installing somewhere else would ruin the unattended idea.
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$FreeSpace = [Int64] ((Get-CimInstance win32_logicaldisk | Where-Object "Caption" -eq "$SystemDrive" | Select-Object -ExpandProperty FreeSpace) / 1Gb);
$Message = "[Placeholder]"
$Lowdisk = $XMLConfig.config.limits.lowdisk.'#text';
if ($FreeSpace -lt 10) {
    $Message = $XMLConfig.config.messages.lowdiskspace.'#text';
    Write-Host $Message -ForegroundColor 'Red';
    [Console]::Beep();
    #TODO: Add article launch about risks of using low system drive space.
    #TODO: Add article launch about how to free up space.
}
[Int]$DiskLimit = $XMLConfig.config.limits.disk.'#text'
if ($FreeSpace -lt ) {
    [System.Console]::Beep();
    $Message = $XMLConfig.config.messages.insufficientspace.'#text';
    Write-Host $Message;
    Read-Host -Prompt "Press Enter to exit";
    exit;
}
if ((Get-CimInstance Win32_OperatingSystem | Select-Object OSArchitecture).OSArchitecture -eq "64-bit") {
    $Is64bit = $true;
}

# Creating software root folder
$RootDir = $RootDir = $SystemDrive + "\" + $InstallFolder;
if (!(Test-Path $RootDir)) {
    New-Item -ItemType Directory -Path $RootDir | Out-Null;
}
if (Test-Path $RootDir){
    Set-Location $RootDir;
} # TODO Error checking here
$GitPath = $XMLConfig.config.folders.git.'#text';
if (!(Test-Path "$RootDir\\$GitPath")) {
    $Message = $XMLConfig.config.messages.downloading.'#text';
    Clear-Line $("$Message git...");
    if (Test-Path "$RootDir\\gitinst.exe") {
        Remove-Item "$RootDir\\gitinst.exe" -Force;
    }
    $Message = $XMLConfig.config.messages.unpacking.'#text'
    Get-File $GitStandalone32 "$RootDir\gitinst.exe";
    Clear-Line $("$Message git...");
    Start-Process -FilePath "gitinst.exe" -ArgumentList "-o `"$RootDir\\$GitPath`" -y" -WindowStyle 'Hidden' -Wait;
}
$GitPath = $RootDir + "\\" + $GitPath + "\\";
$GitExe = $GitPath + "git.exe";
$PyPath = $XMLConfig.config.folders.python.'#text';
if (!(Test-Path "$RootDir\$PyPath")) {
    $Message = $XMLConfig.config.messages.downloading.'#text';
    Clear-Line $("$Message Python...");
    if (Test-Path "$RootDir\\python.zip") {
        Remove-Item "$RootDir\\python.zip" -Force;
    }
    if ($Is64bit) {
        Get-File $PythonStandalone64 "$RootDir\\python.zip";
    }
    else {
        Get-File $PythonStandalone32 "$RootDir\\python.zip";
    }
    $Message = $XMLConfig.config.messages.unpacking.'#text';
    Clear-Line "$Message Python...";
    Expand-Archive -Path "python.zip" -DestinationPath "$RootDir\\$PyPath";
}
$PyPath = $RootDir + "\\" + $PyPath + "\\";
$PythonExe = $PyPath + "python.exe";
$PoshPath = $XMLConfig.config.folders.posh.'#text';
if (!(Test-Path "$RootDir\\$PoshPath")) {
    $Message = $XMLConfig.config.messages.downloading.'#text';
    Clear-Line $("$Message PowerShell Core...");
    if (Test-Path "$RootDir\\pwsh.zip") {
        Remove-Item "$RootDir\\pwsh.zip" -Force;
    }
    if ($Is64bit) {
        Get-File $PwshStandalone64 "$RootDir\\pwsh.zip";
    }
    else {
        Get-File $PwshStandalone32 "$RootDir\\pwsh.zip";
    }
    $Message = $XMLConfig.config.messages.unpacking.'#text';
    Clear-Line $("$Message PowerShell Core...");
    Expand-Archive -Path "pwsh.zip" -DestinationPath "$RootDir\\$PoshPath";
}



Set-Location $RootDir;
$Message = $XMLConfig.config.messages.unpacking.'#text';
$mhddos_proxy_URL = $XMLConfig.config.links.load.'#text';
Clear-Line $("$Message mhddos_proxy")
$GitArgs = "update $mhddos_proxy_URL $PSScriptRoot";
Start-Process -FilePath $GitExe -ArgumentList $GitArgs -Wait -WindowStyle Hidden;

Set-Location $PyPath;
$Message = $XMLConfig.config.messages.pythonmodule.'#text';
Clear-Line "$Message pip...";
Start-Process -FilePath "python.exe" -ArgumentList "-m ensurepip --upgrade";

$MhddosPath =$PSScriptRoot + "\\" + $XMLConfig.config.folders.load.'#text' + "\\";
Set-Location $MhddosPath;
Clear-Line $("$Message requirements.txt")
$PyArgs = "-m pip install -r requirements.txt";
Start-Process -FilePath $PythonExe -ArgumentList $PyArgs -Wait -WindowStyle Hidden;

Get-File $FunctionsURL "functions.ps1";
$Message = $XMLConfig.config.messages.installcomplete.'#text'
Clear-Line $Message
Read-Host "Debug script stop."
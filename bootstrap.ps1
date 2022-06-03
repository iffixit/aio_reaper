function Clear-Line ([String] $Message) {
    [int] $Width = $Host.UI.RawUI.WindowSize.Width;
    $Line = " " * $($Width - 1);
    Write-Host "$Line`r" -NoNewline;
    Write-Host "$([System.DateTime]::Now) $Message`r" -NoNewline;
}

function Get-URLContent ($URL) {
    try {
        $Response = ((Invoke-WebRequest -Headers @{"Cache-Control" = "no-cache" } -UseBasicParsing -Uri $URL ).Content);
    }
    catch {
        $Response = "";
    }
    while ($Response.Length -eq 0) {
        try {
            $Response = ((Invoke-WebRequest -Headers @{"Cache-Control" = "no-cache" } -UseBasicParsing -Uri $URL ).Content);
        }
        catch {
            $Response = "";
        }
    }
    return $Response;
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
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http

$ErrorActionPreference = "SilentlyContinue";
$ProgressPreference = "SilentlyContinue";
$WarningPreference = "SilentlyContinue";

$InstallFolder = "AIOReaper";
$SoftwareName = "Ukrainian Reaper";
# Setting up UI
$host.ui.RawUI.WindowTitle = "Installing $SoftwareName.";
$host.ui.RawUI.BackgroundColor = 'Black';
$host.ui.RawUI.ForegroundColor = 'Green';
# Locations
$GitStandalone32 = Get-URLContent "https://raw.githubusercontent.com/git-for-windows/git-for-windows.github.io/main/latest-32-bit-portable-git.url";
$PythonStandalone32 = "https://www.python.org/ftp/python/3.10.4/python-3.10.4-embed-win32.zip"
$PythonStandalone64 = "https://www.python.org/ftp/python/3.10.4/python-3.10.4-embed-amd64.zip"
$PwshStandalone32 = "https://github.com/PowerShell/PowerShell/releases/download/v7.2.4/PowerShell-7.2.4-win-x86.zip"
$PwshStandalone64 = "https://github.com/PowerShell/PowerShell/releases/download/v7.2.4/PowerShell-7.2.4-win-x64.zip"
$Is64bit = $false;

$FunctionsURL = "https://raw.githubusercontent.com/ahovdryk/aio_reaper/main/functions.ps1";

################################################################################
# Script logic
################################################################################

# Since system drive is the only one MUST be in the users system? we use sustem drive.
# Installing somewhere else would ruin the unattended idea.
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$FreeSpace = [Int64] ((Get-CimInstance win32_logicaldisk | Where-Object "Caption" -eq "$SystemDrive" | Select-Object -ExpandProperty FreeSpace) / 1Gb);
if ($FreeSpace -lt 10) {
    [System.Console]::Beep();
    $host.ui.RawUI.WindowTitle = "Error installing $SoftwareName.";
    Write-Host "Not enough free disk space!`n $SoftwareName needs at least 10Gb free space.";
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

Set-Location $RootDir;

if (!(Test-Path "$RootDir\\Git")) {
    Clear-Line "Downloading Git...";
    if (Test-Path "$RootDir\\gitinst.exe") {
        Remove-Item "$RootDir\\gitinst.exe" -Force;
    }
    Get-File $GitStandalone32 "$RootDir\gitinst.exe";
    Clear-Line "Unpacking Git...";
    Start-Process -FilePath "gitinst.exe" -ArgumentList "-o `"$RootDir\Git`" -y" -WindowStyle 'Hidden' -Wait;
}
if (!(Test-Path "$RootDir\Python")) {
    Clear-Line "Downloading Python...";
    if (Test-Path "$RootDir\\python.zip") {
        Remove-Item "$RootDir\\python.zip" -Force;
    }
    if ($Is64bit) {
        Get-File $PythonStandalone64 "$RootDir\\python.zip";
    }
    else {
        Get-File $PythonStandalone32 "$RootDir\\python.zip";
    }
    Clear-Line "Unpacking Python...";
    Expand-Archive -Path "python.zip" -DestinationPath "$RootDir\\Python";
}
if (!(Test-Path "$RootDir\\PowerShell")) {
    Clear-Line "Downloading PowerShell Core...";
    if (Test-Path "$RootDir\\pwsh.zip") {
        Remove-Item "$RootDir\\pwsh.zip" -Force;
    }
    if ($Is64bit) {
        Get-File $PwshStandalone64 "$RootDir\\pwsh.zip";
    }
    else {
        Get-File $PwshStandalone32 "$RootDir\\pwsh.zip";
    }
    Clear-Line "Unpacking PowerShell Core...";
    Expand-Archive -Path "pwsh.zip" -DestinationPath "$RootDir\\PowerShell";
}
Set-Location "$RootDir\\Python";
Clear-Line "Installing/Upgrading Python pip...";
.\python.exe -m ensurepip --upgrade;
Set-Location $RootDir

Get-URLContent $FunctionsURL | Out-File "functions.ps1" -Encoding utf8;


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

# We need this because default PoSH network protocol is outdated.
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http;
$host.ui.RawUI.BackgroundColor = 'Black';
$host.ui.RawUI.ForegroundColor = 'Green';
Clear-Host;

$SettingsLink = "https://raw.githubusercontent.com/ahovdryk/aio_reaper/main/settings.xml";
$XMLConfig = New-Object System.Xml.XmlDocument;
$XMLConfig.Load($SettingsLink);

[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\" + $InstallFolder;

$MainScriptUrl = $XMLConfig.config.links.main;
$FunctionsURL = $XMLConfig.config.links.funclib;
$PoshPath = $XMLConfig.config.folders.posh;

if (Test-Path "$RootDir\\main.ps1") {
    Remove-Item "$RootDir\\main.ps1" -Force;
}
if (Test-Path "$RootDir\\settings.xml") {
    Remove-Item "$RootDir\\settings.xml" -Force;
}
if (Test-Path "$RootDir\\functions.ps1") {
    Remove-Item "$RootDir\\functions.ps1" -Force;
}
Get-File $MainScriptUrl "$RootDir\\main.ps1";
Get-File $SettingsLink "$RootDir\\settings.xml";
Get-File $FunctionsURL "$RootDir\\functions.ps1";

if(-not Test-Path -Path "$Rootdir\\SpeedTest\\speedtest.exe")
{
    $Message = $XMLConfig.config.messages.downloading;
    Clear-Line $("$Message speedtest")
    $SpeedTestURL = $XMLConfig.config.links.speedtest;
    Get-File $SpeedTestURL "$Rootdir\\speedtest.zip"
    $SpeedTestPath = $("$RootDir\$($XMLConfig.config.folders.speedtest)\");
    Expand-Archive -Path "speedtest.zip" -DestinationPath "$SpeedTestPath" | Out-Null;
}
if (Test-Path "$RootDir\\speedtest.zip") {
    Remove-Item "$RootDir\\speedtest.zip" -Force;
}


$PwshExe = $RootDir + "\\" + $PoshPath + "\\pwsh.exe";

$Proc = Start-Process -FilePath $PwshExe -ArgumentList "-NoLogo -NoProfile -Command $RootDir\\main.ps1" -WorkingDirectory $RootDir -PassThru;
$Proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
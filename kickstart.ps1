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
$host.ui.RawUI.BackgroundColor = 'Black';
$host.ui.RawUI.ForegroundColor = 'Green';
Clear-Host;

$XMLConfig = New-Object System.Xml.XmlDocument;
$XMLConfig.Load($SettingsLink);

[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\" + $InstallFolder;

$SettingsLink = "https://raw.githubusercontent.com/ahovdryk/aio_reaper/main/settings.xml";
$MainScriptUrl = $XMLConfig.config.links.main;
$FunctionsURL = $XMLConfig.config.links.funclib;

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

$Proc = Start-Process -FilePath $PwshExe -ArgumentList "-NoLogo -NoProfile -Command $RootDir\\main.ps1" -WorkingDirectory $RootDir -PassThru;
$Proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
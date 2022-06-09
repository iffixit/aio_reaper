# DO REMEMBER CTRL+C breaks the pipeline!
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http;
[xml]$XMLConfig = Get-Content -Path (".\\settings.xml");
.\functions.ps1
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\" + $InstallFolder;
$PwshDir = $("$RootDir\\$($XMLConfig.config.folders.posh)\\");
$PwshExe = $("$PwshDir\\pwsh.exe");
$UpdateCheckTime = $XMLConfig.config.timers.main;
$FreeMem = GetFreeRamGB;
$RamLimit = $XMLConfig.config.limits.RAM
$LiteMode = $false
if ($FreeMem -lt $RamLimit) {
    $LiteMode = $true;
}
$RunnerURL = $XMLConfig.config.links.runner;
Get-File $RunnerURL $("$RootDir\\runner.ps1")
while ($true) {
    $Now = [System.DateTime]::Now;
    if ($LiteMode) {
        $RunnerProc = Start-Process -FilePath $PwshExe -ArgumentList "$RootDir\\runner.ps1" -NoNewWindow
    }
    
}

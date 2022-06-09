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
$NewStartRequired = $true;
$TitleStarted = $XMLConfig.config.titles.started;
$TitleOK = $XMLConfig.config.titles.ok;
$TitleRestart = $XMLConfig.config.titles.restart;
$TitleError = $XMLConfig.config.titles.error;
$TitleDied = $XMLConfig.config.titles.died;
$TitleExiting = $XMLConfig.config.titles.exiting;
$TitleCompleted = $XMLConfig.config.titles.completed;
while ($true) {
    if ($NewStartRequired) {
        if ($LiteMode) {
            $RunnerProc = Start-Process -FilePath $PwshExe -ArgumentList "$RootDir\\runner.ps1 -lite" -NoNewWindow -PassThru -WorkingDirectory $RootDir;
        }
        else {
            $RunnerProc = Start-Process -FilePath $PwshExe -ArgumentList "$RootDir\\runner.ps1" -NoNewWindow -PassThru -WorkingDirectory $RootDir;
        }
    }
    while ($null -eq $RunnerProc.Id) {
        Start-Sleep -Seconds 1;
    }
    $Now = [System.DateTime]::Now;
    $NextCheck = $Now.AddMinutes($UpdateCheckTime);
    while ($Now -lt $NextCheck -and -not $NewStartRequired) {
        if ($RunnerProc.HasExited) {
            $NewStartRequired = $true;
        }
        $testRunnerProc = Get-Process -Id $RunnerProc.Id;
        if (-not $testRunnerProc) {
            $NewStartRequired = $true;
        }
    }
    if ($NewStartRequired) {
        Stop-Tree $RunnerProc.Id;
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

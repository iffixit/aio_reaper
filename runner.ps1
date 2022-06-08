[console]::TreatControlCAsInput = $true
$host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
$host.UI.RawUI.ForegroundColor = [ConsoleColor]::Green

[xml]$XMLConfig = Get-Content -Path ("settings.xml");
$ActionPreference = $XMLConfig.config.erroraction;
$ErrorActionPreference = $ActionPreference;
$ProgressPreference = $ActionPreference;
$WarningPreference = $ActionPreference;
.\functions.ps1
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\\" + $InstallFolder;

$PythonPath = $("$RootDir\\$($XMLConfig.config.folders.python)\\");
$PythonExe = $PythonPath + "python.exe";
$LoadPath = $("$RootDir\\$($XMLConfig.config.folders.load)\\");
$TargetsURI = $XMLConfig.config.links.targets
$LiteBlockSize = 50;
$BlockSize = $LiteBlockSize * 4;
$MinutesPerBlock = 60;

$RunnerVersion = "1.0.0 Alpha / Winged ratel";
if ($args -like "*-lite*") {
    $RunningLite = $true;
}
else {
    $RunningLite = $false;
}


Clear-Host;
$BannerURL = $XMLConfig.config.links.banner;
$Banner = Get-Banner $BannerURL;
Write-Host $Banner;
$StartupMessage = "Бігунець версії $RunnerVersion";
if ($RunningLite) {
    $StartupMessage = $StartupMessage + " Lite";
}
Clear-Line $StartupMessage;
Set-Location $RootDir;

$Runners = Get-ProcByCmdline "$LoadPath";
$Runners += Get-ProcByPath "$PythonExe";
$Runners = $Runners | Sort-Object -Unique;;
foreach ($ProcessID in $Runners) {
    Stop-Tree $ProcessID | Out-Null;
}

Clear-Line "Отримуємо список цілей...";
$TargetList = Get-Targets $TargetsURI $RunningLite;
$StopRequested = $false;
$StartTask = $true;
[System.Collections.ArrayList]$IDList = @();

while (-not $StopRequested) {
    if ($StartTask -and (-not $RunningLite)) {
        $Targets = $TargetList | Spit-Array -size $BlockSize;
        foreach ($Target in $Targets) {
            if ($Target.Count -gt 0) {
                $TargetString = $Target -join ' ';
                $RunnerArgs = $('runner.py ' + $TargetString);
                $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $WorkDir -ArgumentList $RunnerArgs -WindowStyle Hidden -PassThru;
                $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
                $IDList += $PyProcess.Id;
            }
        }
    }
    if ($StartTask -and $RunningLite) {
        $Targets = $TargetList | Spit-Array -size $LiteBlockSize;
        foreach ($Target in $Targets) {
            if ($Target.Count -gt 0) {
                $TargetString = $Target -join ' ';
                $Runner_args = $('runner.py ' + $TargetString);
                $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $WorkDir -ArgumentList $Runner_args -WindowStyle Hidden -PassThru;
                # We REALLY do not want our system to hang.
                $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
                $StartedBlockJob = [System.DateTime]::Now;
                $StopBlockJob = $StartedBlockJob.AddMinutes($MinutesPerBlock);
                while (($PyProcess.HasExited -eq $false) -and ($StopBlockJob -gt [System.DateTime]::Now)) {
                    $BlockJobLeft = [int] $($StopBlockJob - [System.DateTime]::Now).TotalMinutes;
                    Clear-Line "$BlockJobLeft хвилин братерства на $($Target.Count) цілей";
                    Start-Sleep -Seconds 5;
                }
                Stop-Tree $PyProcess.Id;
                Clear-Line "Відпрацювали $($Target.Count) цілей. Беремо наступний блок";
            }
        }
    }
    if (!$RunningLite) {
        $Now = [System.DateTime]::Now;
        $StopCycle = $Now.AddMinutes($MinutesPerBlock);
        while ($([System.DateTime]::Now) -lt $StopCycle) {

        }
    }
}

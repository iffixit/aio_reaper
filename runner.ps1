[console]::TreatControlCAsInput = $true
$host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
$host.UI.RawUI.ForegroundColor = [ConsoleColor]::Green

[xml]$XMLConfig = Get-Content -Path ("settings.xml");
$ActionPreference = $XMLConfig.config.erroraction;
$ErrorActionPreference = $ActionPreference;
$ProgressPreference = $ActionPreference;
$WarningPreference = $ActionPreference;
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\\" + $InstallFolder;
Set-Location $RootDir;
. "$RootDir\\functions.ps1";

$PythonPath = $("$RootDir\\$($XMLConfig.config.folders.python)\\");
$PythonExe = $PythonPath + "python.exe";
$LoadPath = $("$RootDir\\$($XMLConfig.config.folders.load)\\");
$LoadFileName = $XMLConfig.config.mainloadfile;
$TargetsURI = $XMLConfig.config.links.targets;
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
$Runners = $Runners | Sort-Object -Unique; ;
foreach ($ProcessID in $Runners) {
    Stop-Tree $ProcessID | Out-Null;
}

Clear-Line "Отримуємо список цілей...";
$TargetList = Get-Targets $TargetsURI $RunningLite;
Write-Host "$TargetList"
$StopRequested = $false;
$StartTask = $true;
[System.Collections.ArrayList]$IDList = @();

while (-not $StopRequested) {
    if ($StartTask -and (-not $RunningLite)) {
        $Targets = $TargetList | Split-Array $BlockSize;
        foreach ($Target in $Targets) {
            if ($Target.Count -gt 0) {
                $TargetString = $Target -join ' ';
                $RunnerArgs = $("$LoadFileName $TargetString");
                $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -ArgumentList $RunnerArgs -WindowStyle Hidden -PassThru;
                $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
                $IDList += $PyProcess.Id;
            }
        }
    }
    if ($StartTask -and $RunningLite) {
        $Targets = $TargetList | Split-Array $LiteBlockSize;
        foreach ($Target in $Targets) {
            if ($Target.Count -gt 0) {
                $TargetString = $Target -join ' ';
                $RunnerArgs = $("$LoadFileName $TargetString");
                $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath`
                -ArgumentList $RunnerArgs -WindowStyle Hidden -PassThru;
                $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
                $StartedBlockJob = [System.DateTime]::Now;
                $StopBlockJob = $StartedBlockJob.AddMinutes($MinutesPerBlock);
                while (($PyProcess.HasExited -eq $false) -and ($StopBlockJob -gt [System.DateTime]::Now)) {
                    $BlockJobLeft = [int] $($StopBlockJob - [System.DateTime]::Now).TotalMinutes;
                    $Message = $XMLConfig.config.messages.targets + `
                        ": $($Target.Count) " + `
                        $XMLConfig.config.messages.cpu + `
                        ": $(Get-CpuLoad)`% " + `
                        $XMLConfig.config.messages.memory + `
                        ": $(Get-FreeRamPercent)`% " + `
                        $XMLConfig.config.messages.tillupdate + `
                        ": $BlockJobLeft" + `
                        $XMLConfig.config.messages.minutes;
                    Clear-Line $Message;
                    Start-Sleep -Seconds 5;
                }
                Stop-Tree $PyProcess.Id;
                $Message = $XMLConfig.config.messages.litedone;
                Clear-Line $("$($Target.Count) $Message");
            }
        }
    }
    if (-not $RunningLite) {
        $Now = [System.DateTime]::Now;
        $StopCycle = $Now.AddMinutes($MinutesPerBlock);
        while ($([System.DateTime]::Now) -lt $StopCycle) {
            $BlockJobLeft = [int] $($StopCycle - [System.DateTime]::Now).TotalMinutes;
            $Message = $XMLConfig.config.messages.targets + `
                ": $($TargetList.Count) " + `
                $XMLConfig.config.messages.cpu + `
                ": $(Get-CpuLoad)`% " + `
                $XMLConfig.config.messages.memory + `
                ": $(Get-FreeRamPercent)`% " + `
                $XMLConfig.config.messages.tillupdate + `
                ": $BlockJobLeft " + `
                $XMLConfig.config.messages.minutes;
            Clear-Line $Message;
        }
        $NewTargetList = Get-Targets $TargetsURI $RunningLite;
        if ($TargetList -eq $NewTargetList) {
            $StartTask = $false;
        }
        else {
            $TargetList = $NewTargetList;
            $StartTask = $true;
        }
    }
    if ($RunningLite) {
        $TargetList = Get-Targets $TargetsURI $RunningLite;
    }
}

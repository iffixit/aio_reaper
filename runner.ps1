#[console]::TreatControlCAsInput = $true
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
$RootDir = $SystemDrive + "\" + $InstallFolder;
Set-Location $RootDir;
. "$RootDir\\functions.ps1";

$PythonPath = $("$RootDir\$($XMLConfig.config.folders.python)\");
$PythonExe = $PythonPath + "python.exe";
$LoadPath = $("$RootDir\$($XMLConfig.config.folders.load)\");
$LoadFileName = $LoadPath + $($XMLConfig.config.mainloadfile);
$BogusInitPyPath = $LoadPath + "src\__init__.py";
if (Test-Path $BogusInitPyPath) {
    Remove-Item $BogusInitPyPath -Force | Out-Null;
}
$TargetsURI = $XMLConfig.config.links.targets;
$LiteBlockSize = [Int] $XMLConfig.config.liteblocksize;
$MinutesPerBlock = $XMLConfig.config.timers.minutesperblock;
#[Sytem.Environment]::SetEnvironmentVariable('PYTHONPATH', $("$PythonPath; $LoadPath"), [System.EnvironmentVariableTarget]::Process);
#[System.Environment]::SetEnvironmentVariable('PYTHONHOME', $PythonPath, [System.EnvironmentVariableTarget]::Process);


$RunnerVersion = "1.0.10 Alpha / Winged ratel";


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
Write-Host $StartupMessage;
Set-Location $RootDir;

[System.Collections.ArrayList] $Runners = @()
$Runners += Get-ProcByCmdline "$LoadPath";
$Runners += Get-ProcByPath "$PythonExe";
$Runners = $Runners | Sort-Object -Unique; ;
foreach ($ProcessID in $Runners) {
    Stop-Tree $ProcessID | Out-Null;
}

$TargetList = @()
$TargetList = Get-Targets $TargetsURI $RunningLite;
$StopRequested = $false;
$StartTask = $true;
[System.Collections.ArrayList]$IDList = @();
[System.Collections.ArrayList]$ProcessList = @();
$Targets = @()
$Globalargs = $XMLConfig.config.baseloadargs;
Set-Location $LoadPath;


while (-not $StopRequested) {
    if ($StartTask -and (-not $RunningLite)) {
        $TargetList -join "`r`n" | Out-File -Encoding UTF8 -FilePath "$LoadPath\targets.txt" -Force | Out-Null;
        $TargetString = $("-c $LoadPath\targets.txt");
        $RunnerArgs = $("$LoadFileName $Globalargs $TargetString");
        $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -WindowStyle Hidden -ArgumentList $RunnerArgs -PassThru;
        $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
        $ProcessList += $PyProcess;
        $IDList += $PyProcess.Id;
        $StartTask = $false;
    }

    if ($StartTask -and $RunningLite) {
        Write-Host "Запускаємо бігунець в лайт-режимі";
        $Targets = Get-SlicedArray $TargetList $LiteBlockSize;
        foreach ($Target in $Targets) {
            if ($Target.Count -gt 0) {
                $TargetString = $Target -join ' ';
                $RunnerArgs = $("$LoadFileName $Globalargs $TargetString");

                $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -WindowStyle Hidden -ArgumentList $RunnerArgs -PassThru;
                $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
                $StartedBlockJob = [System.DateTime]::Now;
                $StopBlockJob = $StartedBlockJob.AddMinutes($MinutesPerBlock);
                $Now = [System.DateTime]::Now;
                while (($PyProcess.HasExited -eq $false) -and ($StopBlockJob -gt $Now)) {
                    $Now = [System.DateTime]::Now;
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
        $StartTask = $false;
    }
    if (!$RunningLite) {
        Write-Host "Output cycle $MinutesPerBlock"
        $StopCycle = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
        while ($StopCycle -gt $Now) {
            $Now = [System.DateTime]::Now;
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
        if ($TargetList.Count -eq $NewTargetList.Count) {
            $StartTask = $false;
        }
        else {
            $TargetList = $NewTargetList;
            $Runners = Get-ProcByCmdline "$LoadPath";
            $Runners += Get-ProcByPath "$PythonExe";
            $Runners = $Runners | Sort-Object -Unique;
            foreach ($ProcessID in $Runners) {
                Stop-Tree $ProcessID | Out-Null;
            }
            $StartTask = $true;
        }
    }
    $NewProcessList = $ProcessList;
    $NewIDList = $IDList;
    foreach ($Process in $ProcessList) {
        if ($Process.HasExited) {
            Write-Host "$($Process.StandardError.ReadToEnd())";
            Write-Host "$($Process.StandardOutput.ReadToEnd())";
            $NewProcessList.Remove($Process);
            $NewIDList.Remove($Process.Id);
        }
    }
    $ProcessList = $NewProcessList;
    $IDList = $NewIDList;
    Read-Host "...";
    if ($RunningLite) {
        $TargetList = Get-Targets $TargetsURI $RunningLite;
        $Runners = Get-ProcByCmdline "$LoadPath";
        $Runners += Get-ProcByPath "$PythonExe";
        $Runners = $Runners | Sort-Object -Unique; ;
        foreach ($ProcessID in $Runners) {
            Stop-Tree $ProcessID | Out-Null;
        }
    }
}

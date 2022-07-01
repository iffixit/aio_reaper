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
# Seems to be needed on certain configurations.
$BogusInitPyPath = $LoadPath + "src\__init__.py";
if (Test-Path $BogusInitPyPath) {
    Remove-Item $BogusInitPyPath -Force | Out-Null;
}
$LiteBlockSize = [Int] $XMLConfig.config.liteblocksize;
$MinutesPerBlock = $XMLConfig.config.timers.minutesperblock;
# DO NOT DO THAT and do not propose that!
#[Sytem.Environment]::SetEnvironmentVariable('PYTHONPATH', $("$PythonPath; $LoadPath"), [System.EnvironmentVariableTarget]::Process);
#[System.Environment]::SetEnvironmentVariable('PYTHONHOME', $PythonPath, [System.EnvironmentVariableTarget]::Process);


$RunnerVersion = "1.0.1 beta / Trident rhinoceros";

if ($args -like "*-lite*") {
    $RunningLite = $true;
}
else {
    $RunningLite = $false;
}

Stop-Runners $LoadPath $PythonExe;

$TargetList = @()
$TargetList = MakeTargetlist $RunningLite;
$StopRequested = $false;
$StartTask = $true;
$Targets = @()
$Globalargs = $XMLConfig.config.baseloadargs;
Set-Location $LoadPath;


while (-not $StopRequested) {
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
    if ($StartTask) {
        Write-Host "$($XMLConfig.config.messages.everythingfine)"
    }
    #TODO: split BIG load to a smaller ones
    #TODO: think out condition when to do that
    if ($StartTask -and (-not $RunningLite)) {
        $TargetList -join "`r`n" | Out-File -Encoding UTF8 -FilePath "$LoadPath\targets.txt" -Force | Out-Null;
        $TargetString = $("-c $LoadPath\targets.txt");
        $RunnerArgs = $("$LoadFileName $Globalargs $TargetString");
        $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -WindowStyle Hidden -ArgumentList $RunnerArgs -PassThru;
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
    if (!$RunningLite) {
        $StopCycle = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
        $StopNow = $false;
        while ($StopCycle -gt $Now and $StopNow -eq $false ) {
            $Now = [System.DateTime]::Now;
            $BlockJobLeft = [int] $($StopCycle - [System.DateTime]::Now).TotalMinutes;
            if ($BlockJobLeft -lt 0){
                # The very appearance of this code block is a proof of mysterious nature of .NET way to interpret the time concept
                $StopNow = $true;
            }
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
        $NewTargetList = MakeTargetlist $RunningLite;
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
        $TargetList = MakeTargetlist $RunningLite;
        Stop-Runners $LoadPath $PythonExe;
    }
}
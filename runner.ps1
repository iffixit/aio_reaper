function IsIpAddress ([string] $Target) {
    if ($null -eq $Target) {
        return $false;
    }
    $IsIP = $True
    $Prefix = $Target.Substring(0, 4)
    if ($Prefix -eq "http") {
        return $false;
    }
    $Prefix = $Target.Substring(0, 3)
    if ($Prefix -eq "tcp") {
        return $false;
    }
    $Parts = $Target.Split("://");
    $Target = $Parts[-1];
    $Parts = $Target.Split(":");
    $Target = $Parts[0];
    try {
        [System.Net.IPAddress] $Target;
    }
    catch {
        $IsIP = $false;
    }
    return $IsIP;
}

function TargetHasPrefix ([string] $Target) {
    if ($null -eq $Target) {
        return $false;
    }
    $Parts = $Target.Split("://");
    if ($Parts.Count -eq 1) {
        return $false;
    }
    else {
        return $true;
    }
}

function CreateTargetList([bool] $RunningLite) {
    # Adding targets from simple lists.
    [xml]$XMLConfigLocal = Get-Content -Path ("$PSScriptRoot\\settings.xml");
    $ExtraDirtyList = @();
    $Targets = @();
    $ITArmyTargets = @();
    $TargetLists = $XMLConfigLocal.config.targets.targetlist.entry;
    foreach ($TargetList in $TargetLists) {
        $TempFilePath = $PSScriptRoot + "\\temp.txt";
        Get-File $TargetList $TempFilePath;
        $ExtraDirtyList += [System.IO.File]::ReadAllLines("$TempFilePath");
        Remove-Item -Force -Path $TempFilePath | Out-Null;
    }
    foreach ($Target in $ExtraDirtyList) {
        if (-not(TargetHasPrefix $Target)) {
            $Targets += "tcp://$Target";
        }
        else {
            $Targets += $Target;
        }
    }
    # Adding targets from IT ARMY
    $ItArmyJSON = $XMLConfigLocal.config.targets.json.itarmy.link;
    Get-File $ItArmyJSON $TempFilePath;
    $JsonData = Get-Content -Path $TempFilePath | ConvertFrom-Json;
    Remove-Item -Force -Path $TempFilePath | Out-Null;
    $Jobs = $JsonData.jobs;
    foreach ($Job in $Jobs) {
        $Paths = $XMLConfigLocal.config.targets.json.itarmy.path.entry;
        foreach ($Path in $Paths) {
            $SafePath = $Path -replace '(`)*\$', '$1$1`$$';
            # Generally iex should be avoided. THIS is a rare exception.
            $Val = Invoke-Expression "`$Job.$SafePath"
            if ($null -eq $Val) {
                Out-Null;
            }
            else {
                if ($(IsIpAddress $Val)) {
                    $ITArmyTargets += "tcp://$Val";
                }
                else {
                    $ITArmyTargets += $Val;
                }
            }
        }
    }
    $Targets += $ITArmyTargets;
    # Cleanup
    $Targets = $Targets -join " ";
    $Targets = $Targets -replace '`n', ' ';
    $Targets = $Targets -replace '`r', ' ';
    $Targets = $Targets -replace '`t', ' ';
    $Targets = $Targets -replace ',', ' ';
    $Targets = $Targets -replace '  ', ' ';
    $Targets = $Targets.Replace("tcp)", "tcp");
    $Targets = $Targets -split " ";
    Remove-Variable $XMLConfigLocal;
    foreach ($Target in $Targets) {
        $Prefix = $Target.Substring(0, 4)
        if ($Prefix -eq "http") {
            continue;
        }
        $Prefix = $Target.Substring(0, 3)
        if ($Prefix -eq "tcp") {
            continue;
        }
        
    }
    if (-not $RunningLite) {
        $TargetsCleaned = $Targets | Select-Object -Unique | Sort-Object;
    }
    else {
        $TargetsCleaned = $ITArmyTargets;
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
$WindowStyle = "Hidden"
if (Test-Path -Path "$Rootdir\\debug") {
    Set-PSDebug -Trace 1;
    $WindowStyle = "Normal"
}
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
#$LiteBlockSize = [Int] $XMLConfig.config.liteblocksize;
$MinutesPerBlock = $XMLConfig.config.timers.minutesperblock;
# DO NOT DO THAT and do not propose that! Anyway this shall not work.
#[Sytem.Environment]::SetEnvironmentVariable('PYTHONPATH', $("$PythonPath; $LoadPath"), [System.EnvironmentVariableTarget]::Process);
#[System.Environment]::SetEnvironmentVariable('PYTHONHOME', $PythonPath, [System.EnvironmentVariableTarget]::Process);


$RunnerVersion = "1.4.3 beta / Swinedog stampede";

if ($args -like "*-lite*") {
    $RunningLite = $true;
}
else {
    $RunningLite = $false;
}

Stop-Runners $PythonPath;

$TargetList = @()
do {
    $TargetList = CreateTargetList $RunningLite;
} while ($TargetList.Count -le 0)
$StopRequested = $false;
$StartTask = $true;
$Targets = @()
$Globalargs = $XMLConfig.config.baseloadargs;
Set-Location $LoadPath;
$Results = Get-Content -Path "$Rootdir\\speedtest.result" | ConvertFrom-Json;
[PSCustomObject]$SpeedTestResults = @{
    downloadspeed = [math]::Round($Results.download.bandwidth / 1000000 * 8, 2)
    uploadspeed   = [math]::Round($Results.upload.bandwidth / 1000000 * 8, 2)
    packetloss    = [math]::Round($Results.packetLoss)
    isp           = $Results.isp
    ExternalIP    = $Results.interface.externalIp
    InternalIP    = $Results.interface.internalIp
    UsedServer    = $Results.server.host
    URL           = $Results.result.url
    Jitter        = [math]::Round($Results.ping.jitter)
    Latency       = [math]::Round($Results.ping.latency)
}
$ISP = "$($XMLConfig.config.messages.isp) $($SpeedTestResults.isp)";
$Ul = "$($XMLConfig.config.messages.ulspeed) $($SpeedTestResults.uploadspeed)";
$DL = "$($XMLConfig.config.messages.dlspeed) $($SpeedTestResults.downloadspeed)";
$MyIP = "$($XMLConfig.config.messages.externalip) $($SpeedTestResults.ExternalIP)";


while (-not $StopRequested) {
    Clear-Host;
    $BannerURL = $XMLConfig.config.links.banner;
    $Banner = Get-Banner $BannerURL;
    Write-Host $Banner;
    $StartupMessage = "$($XMLConfig.config.messages.runnerstart) $RunnerVersion";
    if ($RunningLite) {
        $StartupMessage = $StartupMessage + " Lite";
        $RunningLiteMessage = $XMLConfig.config.messages.runninglite;
        Write-Host $RunningLiteMessage;
    }
    Write-Host $StartupMessage;
    Write-Host "$ISP`n$MyIP`n$UL`n$DL`n";
    Write-Host "$($XMLConfig.config.messages.presstoexit)"
    Set-Location $RootDir;
    Write-Host "$($XMLConfig.config.messages.everythingfine)"

    if ($StartTask -and (-not $RunningLite)) {
        $TargetList -join "`r`n" | Out-File -Encoding UTF8 -FilePath "$LoadPath\targets.txt" -Force | Out-Null;
        $TargetString = $("-c $LoadPath\targets.txt");
        $RunnerArgs = $("$LoadFileName $Globalargs $TargetString");
        $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -WindowStyle $WindowStyle -ArgumentList $RunnerArgs -PassThru;
        $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
        $StartTask = $false;
    }

    if ($StartTask -and $RunningLite) {
        if ($TargetList.Count -gt 0) {
            $TargetString = $TargetList -join ' ';
            $RunnerArgs = $("$LoadFileName $Globalargs $TargetString");
            $PyProcess = Start-Process -FilePath $PythonExe -WorkingDirectory $LoadPath -WindowStyle $WindowStyle -ArgumentList $RunnerArgs -PassThru;
            $PyProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle;
            $EndJob = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
            $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob
            while (($PyProcess.HasExited -eq $false) -and ($TillEnd -gt 0)) {
                $RandomTarget = Get-Random $TargetList
                $RandomTarget = $RandomTarget[0..40] -join ""
                $Message = $XMLConfig.config.messages.targets + `
                    ": $($TargetList.Count) " + `
                    $XMLConfig.config.messages.tillupdate + `
                    ": $($TillEnd.Minutes) " + `
                    $XMLConfig.config.messages.minutes + " " + `
                    $XMLConfig.config.messages.randtargets + `
                $(" $RandomTarget");
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    switch ($key.key) {
                        F12 { $EndJob = [System.DateTime]::Now; }
                    }
                }
                Clear-Line $Message;
                Start-Sleep -Seconds 5;
                $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob;
            }
            Stop-Tree $PyProcess.Id;
        }
        $StartTask = $false;
    }
    if (!$RunningLite) {
        $EndJob = [System.DateTime]::Now.AddMinutes($MinutesPerBlock);
        $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob;
        while ($TillEnd -gt 0) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                switch ($key.key) {
                    F12 { $EndJob = [System.DateTime]::Now; }
                }
            }
            if ($PyProcess.HasExited -eq $true) {
                $StartTask = $true;
                break;
            }
            $RandomTarget = Get-Random $TargetList;
            $RandomTarget = $RandomTarget[0..40] -join ""
            $Message = $XMLConfig.config.messages.targets + `
                ": $($TargetList.Count) " + `
                $XMLConfig.config.messages.tillupdate + `
                ": $($TillEnd.Minutes) " + `
                $XMLConfig.config.messages.minutes + " " + `
                $XMLConfig.config.messages.randtargets + `
            $(" $RandomTarget");
            Clear-Line $Message;
            $TillEnd = New-Timespan $([System.DateTime]::Now) $EndJob;
            Start-Sleep -Seconds 1;
        }
    }
    $Message = $XMLConfig.config.messages.gettingtargets;
    Clear-Line $Message;
    $TargetList = CreateTargetList $RunningLite;
    $PyProcess.Kill();
    Stop-Runners $PythonPath;
    $StartTask = $true;
}
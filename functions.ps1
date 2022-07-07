# This could be called from Windows Poweshell.
# Therefore no cyrillic characters are allowed.
function Clear-Line ([String] $Message) {
    [int] $Width = $Host.UI.RawUI.WindowSize.Width;
    $Line = " " * $($Width - 1);
    $NowStr = Get-Date -format "HH:mm:ss";
    Write-Host "$Line`r" -NoNewline;
    Write-Host "$NowStr $Message`r" -NoNewline;
}

function Get-URLContent ($URL) {
    try {
        $Response = ((Invoke-WebRequest -Headers @{"Cache-Control" = "no-cache" } -UseBasicParsing -Uri $URL ).Content);
    }
    catch {
        $Response = "";
    }
    while ($Response.Length -eq 0) {
        try {
            $Response = ((Invoke-WebRequest -Headers @{"Cache-Control" = "no-cache" } -UseBasicParsing -Uri $URL ).Content);
        }
        catch {
            $Response = "";
        }
    }
    return $Response;
}

function Get-Banner ([String] $BannerURL) {
    $Response = "";
    while ($Response -eq "") {
        try {
            $Response = $(Invoke-WebRequest -Headers @{"Cache-Control" = "no-cache" } -UseBasicParsing -Uri $BannerURL).Content;
        }
        catch {
            $Response = "";
        }
    }
    return $Response;
}

function Get-File ($URL, [String] $FileName) {
    $httpClient = New-Object System.Net.Http.HttpClient;
    $httpClient.DefaultRequestHeaders.Add("Cache-Control", "no-cache");
    $Response = $httpClient.GetAsync($URL);
    $Response.Wait();
    $FileStream = New-Object System.IO.FileStream($FileName, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write);
    $DownloadTask = $Response.Result.Content.CopyToAsync($FileStream);
    $DownloadTask.Wait();
    $FileStream.Close();
    $httpClient.Dispose();
}


#From: https://keestalkstech.com/2013/01/comparing-files-with-powershell/
function FilesAreEqual {
    param(
        [System.IO.FileInfo] $first,
        [System.IO.FileInfo] $second,
        [uint32] $bufferSize = 524288)

    if ( $first.Length -ne $second.Length ) { return $false }
    if ( $bufferSize -eq 0 ) { $bufferSize = 524288 }

    $fs1 = $first.OpenRead()
    $fs2 = $second.OpenRead()

    $one = New-Object byte[] $bufferSize
    $two = New-Object byte[] $bufferSize
    $equal = $true

    do {
        $bytesRead = $fs1.Read($one, 0, $bufferSize)
        $fs2.Read($two, 0, $bufferSize) | out-null

        if ( -Not [System.Linq.Enumerable]::SequenceEqual($one, $two)) {
            $equal = $false
        }

    } while ($equal -and $bytesRead -eq $bufferSize)

    $fs1.Close()
    $fs2.Close()

    return $equal
}

# From https://stackoverflow.com/a/55942155
function Stop-Tree {
    Param([int]$ppid)
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ppid } | ForEach-Object { Stop-Tree $_.ProcessId }
    Stop-Process -Id $ppid -Force -ErrorAction SilentlyContinue
}

function Get-SlicedArray ($Array, $SliceSize) {
    [int]$i = 1;
    $SlicedArray = @();
    $EndReached = $false;
    [int]$Bingo = 0;
    foreach ($Item in $Array) {
        if ($i -eq $Array.Count) {
            $EndReached = $true;
        }
        if ($i % $SliceSize -eq 0) {
            $SlicedArray += , ($Array[$Bingo..($i - 1)]);
            $Bingo = $i;
        }
        if ($EndReached) {
            $SlicedArray += , ($Array[$Bingo..$i]);
        }
        $i++;
    }
    return $SlicedArray;
}

function Get-ProcByCmdline ($Cmdline) {
    $Ret = Get-CimInstance win32_process | `
        Where-Object { $_.CommandLine -like "*$Cmdline*" } | `
        Select-Object -ExpandProperty ProcessId
    return $Ret
}

function Get-ProcByPath ($Path) {
    $Ret = Get-CimInstance win32_process | `
        Where-Object { $_.Path -like "*$Path*" } | `
        Select-Object -ExpandProperty ProcessId
    return $Ret
}
function Get-FreeRamPercent {
    $FreeRAM = ($(Get-CIMInstance Win32_OperatingSystem | Select-Object -Expandproperty FreePhysicalMemory) / 1Mb);
    $TotalRAM = ($(Get-CIMInstance Win32_OperatingSystem | Select-Object -Expandproperty TotalVisibleMemorySize) / 1Mb);
    return [System.Math]::Round($FreeRAM / $TotalRAM * 100);
}

function Get-FreeRamGB {
    return [System.Math]::Round($(Get-CIMInstance Win32_OperatingSystem | Select-Object -Expandproperty FreePhysicalMemory) / 1Mb)
}

function Get-CpuLoad {
    return $(Get-CimInstance -ClassName win32_processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average)
}

function Get-CpuSpeed {
    Get-CimInstance Win32_Processor | Select-Object -Expand MaxClockSpeed
}

function Measure-Bandwith {
    $startTime = get-date
    $endTime = $startTime.AddSeconds(5)
    $timeSpan = new-timespan $startTime $endTime
    $count = 0
    $totalBandwidth = 0
    while ($timeSpan -gt 0) {
        # Get an object for the network interfaces, excluding any that are currently disabled.
        $colInterfaces = Get-CimInstance -class Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue | Select-Object BytesTotalPersec, CurrentBandwidth, PacketsPersec | Where-Object { $_.PacketsPersec -gt 0 }
        foreach ($interface in $colInterfaces) {
            $bitsPerSec = $interface.BytesTotalPersec * 8
            $totalBits = $interface.CurrentBandwidth
            # Exclude Nulls (any WMI failures)
            if ($totalBits -gt 0) {
                $result = (( $bitsPerSec / $totalBits) * 100)
                $totalBandwidth = $totalBandwidth + $result
                $count++
            }
        }
        Start-Sleep -milliseconds 100
        # recalculate the remaining time
        $timeSpan = new-timespan $(Get-Date) $endTime
    }
    if ($count -eq 0) {
        $averageBandwidth = 0
    }
    else {
        $averageBandwidth = $totalBandwidth / $count
    }
    $value = "{0:N2}" -f $averageBandwidth
    return "$value `%"
}

function Stop-Runners ($LoadPath, $PythonExe) {
    foreach ($result in $(Get-ProcByCmdline "$LoadPath"; )) {
        Stop-Tree $result.Id;
    }
    foreach ($result in $(Get-ProcByPath "$PythonExe"; )) {
        Stop-Tree $result.Id;
    }
}

function Get-JSON {
    $GotData = $false;
    do {
        try {
            $JsonData = Invoke-RestMethod -Uri https://raw.githubusercontent.com/db1000n-coordinators/LoadTestConfig/main/config.v0.7.json -Method Get
        }
        catch {
            Out-Null;
        }
        if ($null -eq $JsonData.jobs) {
            $GotData = $false;
        }
        else {
            $GotData = $true;
        }
    } while ($GotData -eq $false)
    return $JsonData;
}

function ConvertToTargets {
    $JsonData = Get-JSON;
    $jobs = $JsonData.jobs;
    $TargetList = @()
    foreach ($job in $jobs) {
        if ($null -eq $job.args.request.path) {
            Out-Null;
        }
        else {
            $TargetList += $job.args.request.path;
        }
        if ($null -eq $job.args.client.static_host.addr) {
            Out-Null;
        }
        else {
            $TargetList += $job.args.client.static_host.addr;
        }
        if ($null -eq $job.args.request.path) {
            Out-Null
        }
        else {
            $TargetList += $job.args.request.path
        }
        if ($null -eq $job.args.connection.args.address) {
            Out-Null
        }
        else {
            $TargetList += $job.args.connection.args.address
        }
    }
    $CleanTargets = @()
    foreach ($Target in $TargetList) {
        if ($Target -like "tcp://") {
            continue;
        }
        if ($Target -like "*null*") {
            continue;
        }
        $CleanTargets += $Target
    }
    return $CleanTargets;
}

function MakeTargetlist([bool] $RunningLite) {
    $TempFilePath = "$PSScriptRoot\part1.txt"
    Get-File https://raw.githubusercontent.com/alexnest-ua/targets/main/special/archive/all.txt "$TempFilePath"
    $Targets = [System.IO.File]::ReadAllLines("$TempFilePath");
    Remove-Item -Force -Path $TempFilePath | Out-Null
    $Targets += ConvertToTargets;
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
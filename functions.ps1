# This could be called from Windows Poweshell.
# Therefore no cyrillic characters are allowed.
function Clear-Line ([String] $Message) {
    [int] $Width = $Host.UI.RawUI.WindowSize.Width;
    $Line = " " * $($Width - 1);
    Write-Host "$Line`r" -NoNewline;
    Write-Host "$([System.DateTime]::Now) $Message`r" -NoNewline;
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

function Get-Banner {
    $BannerURL = "https://raw.githubusercontent.com/ahovdryk/mhddos_powershell/master/banner";
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
# Зупинка процесу з усіма дочірніми
function Stop-Tree {
    Param([int]$ppid)
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ppid } | ForEach-Object { Stop-Tree $_.ProcessId }
    Stop-Process -Id $ppid -Force -ErrorAction SilentlyContinue
}

# From https://stackoverflow.com/a/53304601
# Розбивка масиву на задану кількість елементів по заданому розміру.
function Split-Array {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String[]] $InputObject
        ,
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Size = 10
    )
    begin { $items = New-Object System.Collections.Generic.List[object] }
    process { $items.AddRange($InputObject) }
    end {
        $chunkCount = [Math]::Floor($items.Count / $Size)
        foreach ($chunkNdx in 0..($chunkCount - 1)) {
            , $items.GetRange($chunkNdx * $Size, $Size).ToArray()
        }
        if ($chunkCount * $Size -lt $items.Count) {
            , $items.GetRange($chunkCount * $Size, $items.Count - $chunkCount * $Size).ToArray()
        }
    }
}

function Get-Targets ($TargetsURI, $RunningLite) {
    do {
        $DirtyTargets = Get-URLContent $TargetsURI;
        $DirtyTargets = $DirtyTargets -join ' ';
        $DirtyTargets = $DirtyTargets -replace '`n', ' ';
        $DirtyTargets = $DirtyTargets -replace '`r', ' ';
        $DirtyTargets = $DirtyTargets -replace '`t', ' ';
        $DirtyTargets = $DirtyTargets -replace ',', ' ';
        $DirtyTargets = $DirtyTargets -replace '  ', ' ';
        $Targets = @()
        foreach ($Target in $DirtyTargets) {
            if ($Target -like "*null*") {
                continue;
            }
            elseif ($Target -like "tcp://") {
                continue;
            }
            else {
                $Targets += $Target
            }
        }
        if ($RunningLite) {
            $TargetList = $Targets | Select-Object -Unique | Sort-Object { Get-Random }
        }
        else {
            $TargetList = $Targets | Select-Object -Unique | Sort-Object;
        }
    } while ($TargetList.Length -eq 0)
    return $TargetList;
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
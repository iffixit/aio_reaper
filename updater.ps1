[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http;
[xml]$XMLConfig = Get-Content -Path (".\\settings.xml");
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\\" + $InstallFolder;
Set-Location $RootDir;
. $("$RootDir\\functions.ps1");
$Message = $XMLConfig.config.messages.unpacking;
$LoadPath = $RootDir + "\\" + $XMLConfig.config.folders.load + "\\";

Start-Sleep -Seconds 1;
do {
    if (Test-Path $LoadPath) {
        $null = Remove-Item -Path $LoadPath -Recurse -Force | Out-Null;
    }
    Clear-Line $("$Message mhddos_proxy")
    $Message = $XMLConfig.config.messages.unpacking;
    $LoadURL = $XMLConfig.config.links.load;
    Clear-Line $("$Message mhddos_proxy")
    $GitArgs = "clone $LoadURL $LoadPath";
    $GitPath = $XMLConfig.config.folders.git;
    $GitExe = $("$RootDir\\$GitPath\\bin\\git.exe");
    Start-Process -FilePath $GitExe -ArgumentList $GitArgs -WindowStyle Hidden -Wait;

    $PyPath = $XMLConfig.config.folders.python;
    $PythonFolder = $("$RootDir\\$PyPath")
    $PythonExe = $PythonFolder + "\\" + "python.exe";
    Set-Location $LoadPath;
    Clear-Line $("$Message requirements.txt")
    $PyArgs = "-m pip install -r requirements.txt";
    Start-Process -FilePath $PythonExe -ArgumentList $PyArgs -WindowStyle Hidden -Wait;
} while (-not (Test-Path $("$LoadPath\\runner.py")))
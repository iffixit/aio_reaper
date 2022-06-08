[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http;
[xml]$XMLConfig = Get-Content -Path (".\\settings.xml");
.\functions.ps1
[string] $SystemDrive = $(Get-CimInstance Win32_OperatingSystem | Select-Object SystemDirectory).SystemDirectory;
$SystemDrive = $SystemDrive.Substring(0, 2);
$InstallFolder = $XMLConfig.config.folders.install;
$RootDir = $SystemDrive + "\" + $InstallFolder;

$Message = $XMLConfig.config.messages.unpacking;
$mhddos_proxy_URL = $XMLConfig.config.links.load;
$MhddosPath = $RootDir + "\\" + $XMLConfig.config.folders.load + "\\";
$null = Remove-Item -Path $MhddosPath -Recurse -Force;
Clear-Line $("$Message mhddos_proxy")
$GitArgs = "clone $mhddos_proxy_URL $MhddosPath";
Start-Process -FilePath $GitExe -ArgumentList $GitArgs -Wait -WindowStyle Hidden;
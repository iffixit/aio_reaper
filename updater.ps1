[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF-8");
# WebClient is outdated. Use HttpClient instead.
Add-Type -AssemblyName System.Net.Http;
[xml]$XMLConfig = Get-Content -Path (".\\settings.xml");
.\functions.ps1

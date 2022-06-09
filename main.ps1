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
$PwshDir = $("$RootDir\\$($XMLConfig.config.folders.posh)\\");
$PwshExe = $("$PwshDir\\pwsh.exe");
$UpdateCheckTime = $XMLConfig.config.timers.main;
#Write-Host "$([System.DateTime]::Now) Для виходу із програми натисніть Ctrl + C.";
try {
    $NewStartRequired = $True;
    while ($True) {
        $StopTime = [datetime]::now.AddMinutes($UpdateCheckTime);
        if ($NewStartRequired) {
            #$host.ui.RawUI.WindowTitle = "💀 [Старт]";
            #Get-Runner $ScriptURL | Out-File -FilePath "$PSScriptRoot\runner.ps1" -Encoding UTF8
            #Unblock-File "$PSScriptRoot\runner.ps1"
            #Clear-Line "Запуск навантаження...";
            $Runner = Start-Process -FilePath "pwsh" -ArgumentList "$PSScriptRoot\runner.ps1" -NoNewWindow -PassThru
            while ($null -eq $Runner.Id) {
                #Clear-Line "Запуск навантаження...";
                Start-Sleep -Seconds 1
            }
            $RunnerID = $Runner.Id
            #$host.UI.RawUI.WindowTitle = "💀 [Пішло]";
            $NewStartRequired = $False;
        }
        while (([datetime]::now -le $StopTime) -and ($NewStartRequired -eq $False) -and ($RunnerID -ne -1)) {
            Start-Sleep -Seconds 1;
            $ProcCheck = Get-Process -Id $RunnerID -ErrorAction SilentlyContinue
            if ($null -eq $ProcCheck) {
                #Clear-Line "Процес завершився. Наша пісня гарна й нова!";
                $NewStartRequired = $True;
            }
            elseif ( $ProcCheck.HasExited -eq $True ) {
                #Clear-Line "Процес завершився. Наша пісня гарна й нова!";
                $NewStartRequired = $True;
            }
            if ($ProcCheck) {
                #$host.UI.RawUI.WindowTitle = "💀 [Ok]";
            }
        }
        #Get-Runner $ScriptURL | Out-File -FilePath "$PSScriptRoot\runner_new.ps1" -Encoding UTF8
        #Unblock-File "$PSScriptRoot\runner_new.ps1"
        $Now = [datetime]::now
        #$File = get-item "$PSScriptRoot\runner.ps1"
        #$File.LastWriteTime = $Now
        #$File = get-item "$PSScriptRoot\runner_new.ps1"
        #$File.LastWriteTime = $Now
        if (!$(FilesAreEqual -first "$PSScriptRoot\runner.ps1" -second "$PSScriptRoot\runner_new.ps1")) {
            #$host.UI.RawUI.WindowTitle = "💀 [Перезапуск!]";
            Stop-Tree $RunnerID
            while ($(Get-Process -Id $RunnerID -ErrorAction SilentlyContinue)) {
                #Clear-Line "Закриваємо процес бігунця з id $($RunnerID)";
                Start-Sleep -Seconds 1;
            }
            $NewStartRequired = $True;
            #Remove-Item "$PSScriptRoot\runner.ps1" -Force
            #Rename-Item "$PSScriptRoot\runner_new.ps1" -NewName "$PSScriptRoot\runner.ps1"
        }
        else {
            Remove-Item "$PSScriptRoot\runner_new.ps1" -Force
        }
    }
    Write-Host "$([System.DateTime]::Now) Вийшли з головного циклу. Цього в принципі не повинно відбуватись."
}
catch {
    #$host.UI.RawUI.WindowTitle = "💀. [Помилка]";
    #Write-Host "$([System.DateTime]::Now) Помилка при роботі скрипту...";
    #Write-Host "$([System.DateTime]::Now) Помилка: $($_.ScriptStackTrace)"
    #Write-Host "Про це варто повідомити. `n`n`n"

}
finally {
    #$host.UI.RawUI.WindowTitle = "💀. [Виходимо]";
    Get-Process -Id $RunnerID | Stop-Process
    Cleanup
    Remove-Item $Lockfile -Force
    Remove-Item "$PSScriptRoot\runner.ps1" -Force
    Remove-Item "$PSScriptRoot\runner_new.ps1" -Force
    Remove-Item "$PSScriptRoot\auto_reap.ps1" -Force
    $ToDeleteDir = $PSScriptRoot
    Remove-Item $ToDeleteDir -Recurse -Force -ErrorAction SilentlyContinue
    #$host.UI.RawUI.WindowTitle = "💀. [Закінчено]";
    #Write-Host "$([System.DateTime]::Now) Завершено. Дякуємо за використання нашої програми!"
    Read-Host -Prompt "Press Enter to exit"
}
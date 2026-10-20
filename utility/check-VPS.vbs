Set WshShell = CreateObject("WScript.Shell")

' Path to your PowerShell script in the utility folder
Dim scriptPath
scriptPath = "C:\Scripts\surfacebook_scripts\utility\health-check.ps1"

' Run using style 7 (minimized/background) so Windows Explorer provides a valid shell handle for the tray icon
WshShell.Run "pwsh.exe -ExecutionPolicy Bypass -NonInteractive -File """ & scriptPath & """", 7, True
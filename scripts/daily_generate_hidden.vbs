' Runs scripts\daily_generate.ps1 with NO visible window (window style 0).
' Windows Terminal ignores powershell's -WindowStyle Hidden, a VBScript launcher
' does not. Used by the scheduled task from scripts\install_daily_task.ps1.
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & folder & "\daily_generate.ps1""", 0, True

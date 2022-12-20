@echo off
cd %~dp0
powershell.exe -ExecutionPolicy RemoteSigned %~dp0src\Mp3TagsTool.ps1
pause
@echo on

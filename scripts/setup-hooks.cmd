@echo off
REM ============================================================
REM  Git Hooks Setup (setup-hooks.cmd)
REM  Runs the PowerShell setup script from a normal CMD shell
REM ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0setup-hooks.ps1"
pause


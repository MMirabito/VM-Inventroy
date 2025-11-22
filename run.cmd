@echo off
REM ============================================================
REM  VM-Inventory launcher (run.cmd)
REM  Runs the PowerShell script from a normal CMD shell
REM ============================================================


powershell -ExecutionPolicy Bypass -File "%~dp0vm-inventory.ps1"


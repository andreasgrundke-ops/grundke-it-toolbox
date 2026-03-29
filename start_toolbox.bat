@echo off
REM =============================================================================
REM   Titel       : start_toolbox.bat
REM   Version     : 1.0.0
REM   Autor       : Andreas Grundke | grundke-IT.de
REM   Datum       : 2026-03-23
REM   Beschreibung: Startet die Grundke IT Toolbox als Administrator.
REM   Aenderungen : 1.0.0 - Initiale Version
REM =============================================================================

cd /d "%~dp0"
PowerShell -ExecutionPolicy Bypass -File "%~dp0toolbox.ps1"

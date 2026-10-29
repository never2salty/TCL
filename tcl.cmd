@echo off
rem Startet tcl.sh aus CMD oder per Doppelklick. Braucht Git fuer Windows (Git Bash).
setlocal
cd /d "%~dp0"
set "BASH="
for %%B in ("%ProgramFiles%\Git\bin\bash.exe" "%ProgramFiles(x86)%\Git\bin\bash.exe" "%LocalAppData%\Programs\Git\bin\bash.exe") do if exist %%B if not defined BASH set "BASH=%%~B"
if not defined BASH (
  echo Git fuer Windows fehlt. Installieren: https://git-scm.com/download/win
  pause
  exit /b 1
)
if "%~1"=="" (
  "%BASH%" tcl.sh --help
  pause
  exit /b 0
)
"%BASH%" tcl.sh %*

@echo off
REM ---------------------------------------------------------------------------
REM  Lance tools\tester_telephone.sh sous Git Bash (le script est en bash).
REM
REM    tools\tester_telephone.bat              export + installation + test
REM    tools\tester_telephone.bat --no-build   réutilise build\guerriere_debug.apk
REM    tools\tester_telephone.bat --seconds 600
REM
REM  Git Bash est installé avec Git for Windows. S'il est ailleurs, pose le
REM  chemin complet dans la variable BASH ci-dessous.
REM ---------------------------------------------------------------------------
setlocal
set "SCRIPT=%~dp0tester_telephone.sh"
set "BASH=C:\Program Files\Git\bin\bash.exe"

if exist "%BASH%" goto run
set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if exist "%BASH%" goto run

REM Repli : cherche bash.exe fourni par Git (et non celui de WSL, qui échoue).
for /d %%D in ("C:\Program Files\Git*") do (
  if exist "%%D\bin\bash.exe" (
    set "BASH=%%D\bin\bash.exe"
    goto run
  )
)

echo.
echo [tester] Git Bash introuvable.
echo [tester] Installe Git for Windows : https://git-scm.com/download/win
echo [tester] puis relance ce fichier, ou ouvre un terminal Git Bash et lance :
echo [tester]     bash tools/tester_telephone.sh
echo.
exit /b 1

:run
echo [tester] bash : "%BASH%"
"%BASH%" "%SCRIPT%" %*
set "CODE=%ERRORLEVEL%"
echo [tester] code de sortie : %CODE%
exit /b %CODE%

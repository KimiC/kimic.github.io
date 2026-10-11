@echo off
setlocal enabledelayedexpansion
rem ===================================================================
rem  deploy-github.bat  --  publish this folder to GitHub in one step
rem
rem  Usage:   deploy-github.bat  [repository-url]
rem  Default: https://github.com/KimiC/kimic.github.io.git
rem
rem  First run creates the local git repo and pushes everything.
rem  Run it again after you edit the site: it commits and pushes.
rem  Nothing here is destructive, it never deletes your local files.
rem ===================================================================

set "REPO=%~1"
if "%REPO%"=="" set "REPO=https://github.com/KimiC/kimic.github.io.git"

cd /d "%~dp0"
set "FIRSTPUB=0"

echo.
echo ============================================================
echo   Kimi Chen homepage  --^>  GitHub
echo   remote: %REPO%
echo ============================================================
echo.

rem ---------- locate git ----------
where git >nul 2>nul
if not errorlevel 1 goto havegit

rem try the usual install locations before asking
for %%D in ("%ProgramFiles%" "%LOCALAPPDATA%\Programs") do (
  if exist "%%~fD\Git\cmd\git.exe" set "PATH=%%~fD\Git\cmd;!PATH!"
)
where git >nul 2>nul
if not errorlevel 1 goto havegit

echo [WARN] "git" was not found in PATH.
echo        If Git is installed, type the FULL path of the folder
echo        that contains git.exe - usually the "cmd" folder inside
echo        the Git install folder, for example:
echo            C:\Program Files\Git\cmd
echo        Press Enter with nothing typed to abort.
echo.
set "GITDIR="
set /p "GITDIR=Git cmd folder: "
if not defined GITDIR goto nogit
set "PATH=%GITDIR%;%PATH%"
where git >nul 2>nul
if errorlevel 1 goto nogit
echo.

:havegit
echo --- 1/6  git repository -------------------------------
if exist ".git" goto isrepo
echo     creating repository in this folder
git init
if errorlevel 1 goto fail
set "FIRSTPUB=1"
goto identity

:isrepo
echo     already a git repository, skipping init
goto identity

:identity
echo --- 2/6  commit identity, this repo only --------------
git config user.name >nul 2>nul
if errorlevel 1 git config user.name "Kimi Chen"
git config user.email >nul 2>nul
if errorlevel 1 git config user.email "kimic@users.noreply.github.com"

echo --- 3/6  staging files --------------------------------
git add -A
if errorlevel 1 goto fail

echo --- 4/6  commit ---------------------------------------
git commit -m "deploy: publish site"
if errorlevel 1 echo     nothing new to commit, that is fine

echo --- 5/6  remote origin -------------------------------
git remote get-url origin >nul 2>nul
if errorlevel 1 goto addremote
git remote set-url origin "%REPO%"
if errorlevel 1 goto fail
goto setbranch

:addremote
git remote add origin "%REPO%"
if errorlevel 1 goto fail

:setbranch
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 goto unborn

set "CURBRANCH="
for /f "delims=" %%B in ('git symbolic-ref --short HEAD 2^>nul') do set "CURBRANCH=%%B"
if /i "!CURBRANCH!"=="main" goto push
git branch -M main >nul 2>nul
if errorlevel 1 goto fail
goto push

:unborn
git symbolic-ref HEAD refs/heads/main
if errorlevel 1 goto fail

:push
echo --- 6/6  push -----------------------------------------
echo     If Git asks for a password, paste a Personal Access
echo     Token, NOT your GitHub login password.
echo.
set "PUSHARGS="
git ls-remote --exit-code --heads origin main >nul 2>nul
if errorlevel 1 goto dopush
if not "%FIRSTPUB%"=="1" goto warnremote
echo     NOTE: branch main already exists on the remote, and this
echo           folder has its own fresh history. This is the first
echo           publish from here, so this folder becomes the new
echo           truth on GitHub and the old commit is replaced.
set "PUSHARGS=--force"
goto dopush

:warnremote
echo     NOTE: remote branch main already exists, pushing an update.

:dopush
git push -u origin main %PUSHARGS%
if errorlevel 1 goto pushfail

echo.
echo ============================================================
echo   DONE.  https://github.com/KimiC/kimic.github.io
echo ============================================================
echo   GitHub Pages is already live: https://kimic.github.io/
echo.
echo   Next step, on the server:
echo     ssh root@47.82.233.199
echo     git clone https://github.com/KimiC/kimic.github.io.git /var/www/kimic
echo     bash /var/www/kimic/deploy/setup-server.sh
echo.
pause
exit /b 0

:nogit
echo.
echo [ERR] Git was not found. Install it from
echo       https://git-scm.com/download/win
echo       and keep "Add Git to PATH" checked, then run this again.
echo.
pause
exit /b 1

:pushfail
echo.
echo [ERR] The push failed. Read the message above.
echo.
echo   - Authentication failed or cancelled:
echo       run this script again and enter a Personal Access Token.
echo   - Rejected, the remote already has commits:
echo       git pull --rebase origin main
echo       then run this script again.
echo   - Still rejected and you do not need whatever is on the
echo     remote, this repo is yours so overwriting it is safe:
echo       git push -u origin main --force
echo.
pause
exit /b 1

:fail
echo.
echo [ERR] The command above failed. Fix it and run this script again.
echo.
pause
exit /b 1

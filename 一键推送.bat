@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: AlphaCore Push Script v3.0 - safe dual-repository workflow
:: The script root is resolved from this file, never from the caller's cwd.

set "SCRIPT_ROOT=%~dp0"
if "%SCRIPT_ROOT:~-1%"=="\" set "SCRIPT_ROOT=%SCRIPT_ROOT:~0,-1%"
set "QD_DIR=%SCRIPT_ROOT%\quant_dashboard"
set "NEWS_DIR=%SCRIPT_ROOT%"
set "PUSH_COUNT=0"
set "FAIL_COUNT=0"
set "QD_STATUS=NOT_RUN"
set "NEWS_STATUS=NOT_RUN"
set "QD_MSG="

echo.
echo  ========================================
echo    AlphaCore Push v3.0 - Safe Mode
echo  ========================================
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git not found
    set "FAIL_COUNT=1"
    goto :SUMMARY
)

call :PROCESS_REPO "quant_dashboard" "%QD_DIR%" "origin" "main" "QD"
call :PROCESS_REPO "NEWS" "%NEWS_DIR%" "git@github.com-terryzhoo-max/NEWS.git" "main" "NEWS"
goto :SUMMARY

:: ============================================================
:: Process one repository without affecting the other repository.
:: Arguments: name, directory, remote, branch, result key
:: ============================================================
:PROCESS_REPO
set "REPO_NAME=%~1"
set "REPO_DIR=%~2"
set "REMOTE=%~3"
set "BRANCH=%~4"
set "REPO_KEY=%~5"
set "REPO_ACTIVE=false"
set "CURRENT_BRANCH="
set "AHEAD=0"
set "BEHIND=0"
set "RELATION_FOUND=false"
set "NEEDS_PUSH=0"
set "LOCAL_HEAD="
set "REMOTE_HEAD="

echo ----------------------------------------
echo  !REPO_NAME!
echo ----------------------------------------

if not exist "!REPO_DIR!\.git" (
    echo   [FAIL] Not a Git repository: !REPO_DIR!
    goto :PROCESS_REPO_FAIL
)

pushd "!REPO_DIR!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Cannot enter: !REPO_DIR!
    goto :PROCESS_REPO_FAIL
)
set "REPO_ACTIVE=true"

for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%B"
if /I not "!CURRENT_BRANCH!"=="!BRANCH!" (
    echo   [BLOCKED] Expected branch !BRANCH!, current: !CURRENT_BRANCH!
    goto :PROCESS_REPO_FAIL
)

git remote get-url "!REMOTE!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Remote not found: !REMOTE!
    goto :PROCESS_REPO_FAIL
)

echo   Checking remote state...
git fetch --prune "!REMOTE!" "!BRANCH!"
if errorlevel 1 (
    echo   [FAIL] Fetch failed; local files were not staged or committed
    goto :PROCESS_REPO_FAIL
)

git rev-parse --verify "!REMOTE!/!BRANCH!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Remote branch not found: !REMOTE!/!BRANCH!
    goto :PROCESS_REPO_FAIL
)

for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...!REMOTE!/!BRANCH! 2^>nul') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
    set "RELATION_FOUND=true"
)
if /I not "!RELATION_FOUND!"=="true" (
    echo   [FAIL] Cannot compare local and remote history
    goto :PROCESS_REPO_FAIL
)

if !AHEAD! gtr 0 if !BEHIND! gtr 0 (
    echo   [DIVERGED] local ahead !AHEAD!, behind !BEHIND!
    echo   Resolve manually; no rebase, stash, reset, or force push was attempted
    goto :PROCESS_REPO_FAIL
)

if !BEHIND! gtr 0 (
    echo   Remote is ahead by !BEHIND! commit(s); applying fast-forward only...
    git merge --ff-only !REMOTE!/!BRANCH!
    if errorlevel 1 (
        echo   [BLOCKED] Fast-forward failed; local work was preserved
        goto :PROCESS_REPO_FAIL
    )
    set "AHEAD=0"
)

if !AHEAD! gtr 0 set "NEEDS_PUSH=1"

git add -A
if errorlevel 1 (
    echo   [FAIL] git add failed
    goto :PROCESS_REPO_FAIL
)

git diff --cached --quiet
if errorlevel 1 (
    echo   Changed files:
    git --no-pager diff --cached --stat
    echo.

    set "COMMIT_MSG="
    if /I "!REPO_KEY!"=="QD" (
        set /p "COMMIT_MSG=  Commit message (Enter=daily update): "
        if "!COMMIT_MSG!"=="" set "COMMIT_MSG=update: daily update"
        set "QD_MSG=!COMMIT_MSG!"
    ) else (
        if defined QD_MSG echo   Hint: last msg = "!QD_MSG!"
        set /p "COMMIT_MSG=  Commit message (Enter=reuse last): "
        if "!COMMIT_MSG!"=="" set "COMMIT_MSG=!QD_MSG!"
        if "!COMMIT_MSG!"=="" set "COMMIT_MSG=update: daily update"
    )

    git commit -m "!COMMIT_MSG!"
    if errorlevel 1 (
        echo   [FAIL] Commit failed
        goto :PROCESS_REPO_FAIL
    )
    set "NEEDS_PUSH=1"
)

if "!NEEDS_PUSH!"=="0" (
    echo   [OK] No changes; already synchronized
    set "!REPO_KEY!_STATUS=NO_CHANGES"
    goto :PROCESS_REPO_DONE
)

echo.
echo   Pushing !REPO_NAME!...
git push "!REMOTE!" "HEAD:!BRANCH!"
if errorlevel 1 (
    echo   [FAIL] Push failed
    goto :PROCESS_REPO_FAIL
)

git fetch --prune "!REMOTE!" "!BRANCH!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Push completed but verification fetch failed
    goto :PROCESS_REPO_FAIL
)

for /f "delims=" %%H in ('git rev-parse HEAD 2^>nul') do set "LOCAL_HEAD=%%H"
for /f "delims=" %%H in ('git rev-parse !REMOTE!/!BRANCH! 2^>nul') do set "REMOTE_HEAD=%%H"
if not defined LOCAL_HEAD (
    echo   [FAIL] Cannot resolve local HEAD after push
    goto :PROCESS_REPO_FAIL
)
if not defined REMOTE_HEAD (
    echo   [FAIL] Cannot resolve remote HEAD after push
    goto :PROCESS_REPO_FAIL
)
if /I not "!LOCAL_HEAD!"=="!REMOTE_HEAD!" (
    echo   [FAIL] Post-push verification mismatch
    goto :PROCESS_REPO_FAIL
)

echo   [OK] !REPO_NAME! push verified at !LOCAL_HEAD:~0,7!
set "!REPO_KEY!_STATUS=PUSHED"
set /a PUSH_COUNT+=1
goto :PROCESS_REPO_DONE

:PROCESS_REPO_FAIL
set "!REPO_KEY!_STATUS=FAILED"
set /a FAIL_COUNT+=1

:PROCESS_REPO_DONE
if /I "!REPO_ACTIVE!"=="true" popd
echo.
exit /b 0

:: ============================================================
:: Final summary. A repository failure returns a non-zero code,
:: but never prevents the other repository from being processed.
:: ============================================================
:SUMMARY
echo.
echo ========================================
echo  quant_dashboard: !QD_STATUS!
echo  NEWS:            !NEWS_STATUS!
echo  pushed: !PUSH_COUNT!  errors: !FAIL_COUNT!
echo ========================================
echo.

if /I "!QD_STATUS!"=="PUSHED" (
    echo  Deploy on Alibaba Cloud:
    echo  cd /root/quant_dashboard/quant_dashboard ^&^& bash update.sh
    echo.
)

set "FINAL_EXIT=0"
if not "!FAIL_COUNT!"=="0" set "FINAL_EXIT=1"
if not defined ALPHACORE_PUSH_NO_PAUSE pause
exit /b !FINAL_EXIT!

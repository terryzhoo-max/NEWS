@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title AlphaCore Push v4.1

REM ============================================================
REM AlphaCore Push Script v4.1
REM v4.1 (2026-11-03): quant_dashboard runs a pre-push check before commit:
REM   quant_dashboard\_dev_tools\pre_push_check.py (file confirmation + tests
REM   on the staged snapshot). Emergency skip (logged, commit tagged):
REM     set ALPHACORE_SKIP_TESTS=1
REM     set "ALPHACORE_SKIP_REASON=<reason>"
REM   The NEWS repo flow is unchanged.
REM   Keep this file CRLF: cmd can mis-locate labels in LF-only batch files.
REM ============================================================

REM ---- Resolve script root ----
set "SCRIPT_ROOT=%~dp0"
if "!SCRIPT_ROOT:~-1!"=="\" set "SCRIPT_ROOT=!SCRIPT_ROOT:~0,-1!"

REM ---- Directories ----
set "QD_DIR=!SCRIPT_ROOT!\quant_dashboard"
set "NEWS_DIR=!SCRIPT_ROOT!"
set "LOG_DIR=!SCRIPT_ROOT!\.push-logs"

REM ---- Counters ----
set "PUSH_COUNT=0"
set "FAIL_COUNT=0"
set "REPO_COUNT=2"
set "QD_STATUS=NOT_RUN"
set "NEWS_STATUS=NOT_RUN"

REM ---- Configurable ----
set "DEFAULT_COMMIT_MSG=update: daily update"
if defined ALPHACORE_COMMIT_MSG set "DEFAULT_COMMIT_MSG=!ALPHACORE_COMMIT_MSG!"

REM ---- ISO 8601 timestamp ----
call :GET_TIMESTAMP
set "RUN_ID=!TIMESTAMP_COMPACT!"

REM ---- Log file ----
if not exist "!LOG_DIR!" (
    mkdir "!LOG_DIR!" >nul 2>&1
)
set "LOG_FILE=!LOG_DIR!\push-!RUN_ID!.log"

REM ---- Mutex lock ----
set "LOCK_FILE=%TEMP%\AlphaCore-push.lock"
if exist "!LOCK_FILE!" (
    echo.
    echo  [BLOCKED] Another push process is running
    echo  Lock file: !LOCK_FILE!
    echo.
    echo  Delete the lock file if no other process is running.
    echo.
    goto :WAIT_AND_EXIT
)
echo !RUN_ID! >"!LOCK_FILE!"

REM ---- Banner ----
echo.
echo  ========================================
echo    AlphaCore Push v4.1 - Safe Mode
echo    !TIMESTAMP_DISPLAY!
echo  ========================================
echo.
call :LOG "===== AlphaCore Push v4.1 started ====="
call :LOG "Script root: !SCRIPT_ROOT!"

REM ---- Pre-flight ----
where git >nul 2>&1
if errorlevel 1 (
    echo  [FATAL] git not found in PATH
    call :LOG "[FATAL] git not found in PATH"
    set "FAIL_COUNT=2"
    goto :CLEANUP
)
for /f "delims=" %%V in ('git --version 2^>nul') do set "GIT_VERSION=%%V"
echo  Git: !GIT_VERSION!
call :LOG "Git: !GIT_VERSION!"
echo.

REM ---- Process repositories ----
call :PROCESS_REPO "quant_dashboard" "!QD_DIR!" "origin" "main" "QD"
echo.
call :PROCESS_REPO "NEWS" "!NEWS_DIR!" "git@github.com-terryzhoo-max/NEWS.git" "main" "NEWS"
goto :CLEANUP

REM ============================================================
REM :PROCESS_REPO  name  directory  remote  branch  result_key
REM ============================================================
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

echo  ----------------------------------------
echo   Repo: !REPO_NAME!
echo   Path: !REPO_DIR!
echo  ----------------------------------------
call :LOG "--- Processing: !REPO_NAME! ---"

if not exist "!REPO_DIR!\.git" (
    echo   [FAIL] Not a Git repo: !REPO_DIR!
    call :LOG "[FAIL] !REPO_NAME!: Not a Git repo"
    goto :PROCESS_REPO_FAIL
)

pushd "!REPO_DIR!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Cannot enter: !REPO_DIR!
    call :LOG "[FAIL] !REPO_NAME!: Cannot enter directory"
    goto :PROCESS_REPO_FAIL
)
set "REPO_ACTIVE=true"

for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%B"
if /I not "!CURRENT_BRANCH!"=="!BRANCH!" (
    echo   [FAIL] Expected branch !BRANCH!, current: !CURRENT_BRANCH!
    call :LOG "[FAIL] !REPO_NAME!: Wrong branch !CURRENT_BRANCH!"
    goto :PROCESS_REPO_FAIL
)
echo   Branch: !CURRENT_BRANCH!  OK

git remote get-url "!REMOTE!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Remote not found: !REMOTE!
    call :LOG "[FAIL] !REPO_NAME!: Remote not found"
    goto :PROCESS_REPO_FAIL
)
echo   Remote: !REMOTE!  OK

echo   Fetching remote...
git fetch --prune "!REMOTE!" "!BRANCH!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Fetch failed. Check network and SSH/HTTPS config.
    call :LOG "[FAIL] !REPO_NAME!: Fetch failed"
    goto :PROCESS_REPO_FAIL
)

git rev-parse --verify "!REMOTE!/!BRANCH!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Remote branch not found: !REMOTE!/!BRANCH!
    call :LOG "[FAIL] !REPO_NAME!: Remote branch not found"
    goto :PROCESS_REPO_FAIL
)

for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD..."!REMOTE!/!BRANCH!" 2^>nul') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
    set "RELATION_FOUND=true"
)
if /I not "!RELATION_FOUND!"=="true" (
    echo   [FAIL] Cannot compare local and remote history
    call :LOG "[FAIL] !REPO_NAME!: Cannot compare history"
    goto :PROCESS_REPO_FAIL
)

if !AHEAD! gtr 0 (
    if !BEHIND! gtr 0 (
        echo   [DIVERGED] Local ahead !AHEAD!, behind !BEHIND!
        echo   Resolve manually. No rebase or force push attempted.
        call :LOG "[FAIL] !REPO_NAME!: Diverged ahead=!AHEAD! behind=!BEHIND!"
        goto :PROCESS_REPO_FAIL
    )
)

if !BEHIND! gtr 0 (
    echo   Remote ahead by !BEHIND! commits. Fast-forwarding...
    git merge --ff-only "!REMOTE!/!BRANCH!"
    if errorlevel 1 (
        echo   [FAIL] Fast-forward failed. Local work preserved.
        call :LOG "[FAIL] !REPO_NAME!: FF merge failed"
        goto :PROCESS_REPO_FAIL
    )
    echo   Fast-forward done  OK
    set "AHEAD=0"
)

if !AHEAD! gtr 0 set "NEEDS_PUSH=1"

REM quant_dashboard: pre-push check (replaces "git add -A"; tests the staged snapshot)
if /I "!REPO_KEY!"=="QD" (
    call :QD_PRE_PUSH
    if errorlevel 1 goto :PROCESS_REPO_FAIL
    goto :STAGE_DONE
)

git add -A
if errorlevel 1 (
    echo   [FAIL] git add failed
    call :LOG "[FAIL] !REPO_NAME!: git add failed"
    goto :PROCESS_REPO_FAIL
)

:STAGE_DONE

git diff --cached --quiet
if errorlevel 1 (
    echo.
    echo   Changed files:
    git --no-pager diff --cached --stat
    echo.

    set "COMMIT_MSG=!DEFAULT_COMMIT_MSG!"
    set "USE_MSG_FILE=0"
    if /I "!REPO_KEY!"=="QD" if exist "!MSG_FILE!" (
        set "USE_MSG_FILE=1"
        set /p COMMIT_MSG=<"!MSG_FILE!"
    )
    echo   Commit: "!COMMIT_MSG!"
    call :LOG "!REPO_NAME!: Committing: !COMMIT_MSG!"

    if "!USE_MSG_FILE!"=="1" (
        git commit -F "!MSG_FILE!"
    ) else (
        git commit -m "!COMMIT_MSG!"
    )
    if errorlevel 1 (
        echo   [FAIL] Commit failed
        call :LOG "[FAIL] !REPO_NAME!: Commit failed"
        goto :PROCESS_REPO_FAIL
    )
    echo   Commit done  OK
    set "NEEDS_PUSH=1"
)

if "!NEEDS_PUSH!"=="0" (
    echo   [OK] No changes. Already synchronized.
    set "!REPO_KEY!_STATUS=NO_CHANGES"
    call :LOG "!REPO_NAME!: No changes"
    goto :PROCESS_REPO_DONE
)

echo.
echo   Pushing !REPO_NAME!...
git push "!REMOTE!" "HEAD:!BRANCH!"
if errorlevel 1 (
    echo   [FAIL] Push failed
    call :LOG "[FAIL] !REPO_NAME!: Push failed"
    goto :PROCESS_REPO_FAIL
)

git fetch --prune "!REMOTE!" "!BRANCH!" >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Push OK but verification fetch failed
    call :LOG "[FAIL] !REPO_NAME!: Post-push fetch failed"
    goto :PROCESS_REPO_FAIL
)

for /f "delims=" %%H in ('git rev-parse HEAD 2^>nul') do set "LOCAL_HEAD=%%H"
for /f "delims=" %%H in ('git rev-parse "!REMOTE!/!BRANCH!" 2^>nul') do set "REMOTE_HEAD=%%H"

if not defined LOCAL_HEAD (
    echo   [FAIL] Cannot resolve local HEAD after push
    call :LOG "[FAIL] !REPO_NAME!: Cannot resolve local HEAD"
    goto :PROCESS_REPO_FAIL
)
if not defined REMOTE_HEAD (
    echo   [FAIL] Cannot resolve remote HEAD after push
    call :LOG "[FAIL] !REPO_NAME!: Cannot resolve remote HEAD"
    goto :PROCESS_REPO_FAIL
)
if /I not "!LOCAL_HEAD!"=="!REMOTE_HEAD!" (
    echo   [FAIL] Post-push mismatch: local=!LOCAL_HEAD:~0,7! remote=!REMOTE_HEAD:~0,7!
    call :LOG "[FAIL] !REPO_NAME!: Post-push mismatch"
    goto :PROCESS_REPO_FAIL
)

echo   [OK] !REPO_NAME! pushed. Verified at !LOCAL_HEAD:~0,7!
set "!REPO_KEY!_STATUS=PUSHED"
set /a PUSH_COUNT+=1
call :LOG "!REPO_NAME!: PUSHED at !LOCAL_HEAD:~0,7!"
goto :PROCESS_REPO_DONE

:PROCESS_REPO_FAIL
set "!REPO_KEY!_STATUS=FAILED"
set /a FAIL_COUNT+=1

:PROCESS_REPO_DONE
if /I "!REPO_ACTIVE!"=="true" popd
exit /b 0

REM ============================================================
REM :QD_PRE_PUSH - quant_dashboard pre-push check (exit 1 = abort)
REM   Confirms files left out of the commit, then runs CI-equivalent
REM   tests on the staged snapshot. See _dev_tools\pre_push_check.py.
REM ============================================================
:QD_PRE_PUSH
set "QD_APP=!REPO_DIR!\quant_dashboard"
set "PP_SCRIPT=!QD_APP!\_dev_tools\pre_push_check.py"
set "PP_PY=!QD_APP!\.venv\Scripts\python.exe"
set "MSG_FILE=%TEMP%\AlphaCore\commit-msg-!RUN_ID!.txt"
if exist "!MSG_FILE!" del /q "!MSG_FILE!" >nul 2>&1
if not exist "!PP_SCRIPT!" (
    echo   [FAIL] Pre-push check not found: !PP_SCRIPT!
    call :LOG "[FAIL] !REPO_NAME!: pre_push_check.py not found"
    exit /b 1
)
if not exist "!PP_PY!" (
    where python >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] Python not found: !PP_PY!
        call :LOG "[FAIL] !REPO_NAME!: Python not found for pre-push check"
        exit /b 1
    )
    set "PP_PY=python"
)
if "!ALPHACORE_SKIP_TESTS!"=="1" call :LOG "!REPO_NAME!: ALPHACORE_SKIP_TESTS=1 set"
call :LOG "!REPO_NAME!: pre-push check started"
"!PP_PY!" "!PP_SCRIPT!" --repo "!REPO_DIR!" --remote "!REMOTE!" --branch "!BRANCH!" --log "!LOG_FILE!" --skip-log "!LOG_DIR!\skipped-tests.log" --msg "!DEFAULT_COMMIT_MSG!" --msg-out "!MSG_FILE!"
if errorlevel 1 (
    echo.
    echo   [FAIL] Pre-push check failed. Nothing committed or pushed for !REPO_NAME!.
    call :LOG "[FAIL] !REPO_NAME!: pre-push check failed"
    exit /b 1
)
call :LOG "!REPO_NAME!: pre-push check passed"
exit /b 0

REM ============================================================
REM :CLEANUP - Summary, log, lock release
REM ============================================================
:CLEANUP
echo.
echo  ========================================
echo           PUSH RESULT SUMMARY
echo  ========================================
echo   quant_dashboard: !QD_STATUS!
echo   NEWS:            !NEWS_STATUS!
echo   Pushed: !PUSH_COUNT!   Errors: !FAIL_COUNT!
echo  ========================================
echo.

if /I "!QD_STATUS!"=="PUSHED" (
    echo  [Deploy] Alibaba Cloud:
    echo  cd /root/quant_dashboard/quant_dashboard ^&^& bash update.sh
    echo.
)

set "FINAL_EXIT=0"
if not "!FAIL_COUNT!"=="0" set "FINAL_EXIT=1"
if "!FAIL_COUNT!"=="!REPO_COUNT!" set "FINAL_EXIT=2"

call :LOG "quant_dashboard: !QD_STATUS!"
call :LOG "NEWS: !NEWS_STATUS!"
call :LOG "Pushed: !PUSH_COUNT!  Errors: !FAIL_COUNT!  Exit: !FINAL_EXIT!"
call :LOG "===== AlphaCore Push v4.1 finished ====="

if exist "!LOG_FILE!" (
    echo  Log saved: !LOG_FILE!
    echo.
)

call :WRITE_RESULT

REM ---- Release lock ----
if exist "!LOCK_FILE!" del /q "!LOCK_FILE!" >nul 2>&1
if defined MSG_FILE if exist "!MSG_FILE!" del /q "!MSG_FILE!" >nul 2>&1

REM ---- Clean old logs (keep last 30) ----
call :CLEAN_OLD_LOGS

goto :WAIT_AND_EXIT

REM ============================================================
REM :WAIT_AND_EXIT - Keep window open
REM ============================================================
:WAIT_AND_EXIT
echo.
if not defined ALPHACORE_PUSH_NO_PAUSE (
    echo  Press any key to close...
    pause >nul
)
exit /b !FINAL_EXIT!

REM ============================================================
REM Utility functions
REM ============================================================

:LOG
if not defined LOG_FILE exit /b 0
>>"!LOG_FILE!" echo [!TIMESTAMP_DISPLAY!] %~1
exit /b 0

:GET_TIMESTAMP
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'" 2^>nul') do set "TIMESTAMP_DISPLAY=%%a"
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'" 2^>nul') do set "TIMESTAMP_COMPACT=%%a"
if not defined TIMESTAMP_DISPLAY set "TIMESTAMP_DISPLAY=%date% %time%"
if not defined TIMESTAMP_COMPACT set "TIMESTAMP_COMPACT=unknown"
exit /b 0

:WRITE_RESULT
set "RESULT_FILE=%TEMP%\AlphaCore\latest-push-result.txt"
if defined ALPHACORE_PUSH_RESULT_FILE set "RESULT_FILE=!ALPHACORE_PUSH_RESULT_FILE!"
for %%D in ("!RESULT_FILE!") do set "RESULT_DIR=%%~dpD"
if not exist "!RESULT_DIR!" (
    mkdir "!RESULT_DIR!" >nul 2>&1
)
if not exist "!RESULT_DIR!" (
    echo  [WARN] Cannot create result dir: !RESULT_DIR!
    exit /b 0
)
set "RESULT_TEMP=!RESULT_FILE!.tmp"
if exist "!RESULT_TEMP!" del /q "!RESULT_TEMP!" >nul 2>&1
>"!RESULT_TEMP!" (
    echo AlphaCore Push Result
    echo =====================
    echo Timestamp: !TIMESTAMP_DISPLAY!
    echo RunID: !RUN_ID!
    echo Exit: !FINAL_EXIT!
    echo quant_dashboard: !QD_STATUS!
    echo NEWS: !NEWS_STATUS!
    echo Pushed: !PUSH_COUNT!
    echo Errors: !FAIL_COUNT!
)
if exist "!RESULT_TEMP!" (
    move /y "!RESULT_TEMP!" "!RESULT_FILE!" >nul 2>&1
)
exit /b 0

:CLEAN_OLD_LOGS
set "LOG_COUNT=0"
for /f "delims=" %%F in ('dir /b /o-d "!LOG_DIR!\push-*.log" 2^>nul') do (
    set /a LOG_COUNT+=1
    if !LOG_COUNT! gtr 30 (
        del /q "!LOG_DIR!\%%F" >nul 2>&1
    )
)
exit /b 0

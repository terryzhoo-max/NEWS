# Safe Dual-Repository Push Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `一键推送.bat` safely synchronize, commit, push, and verify the `quant_dashboard` and NEWS repositories without automatic rebases, force pushes, or cross-repository failure coupling.

**Architecture:** Keep the double-clickable Windows Batch entry point, but replace duplicated repository logic with one `:PROCESS_REPO` subroutine configured per repository. A Python source-contract test verifies ordering and safety invariants without executing a real push.

**Tech Stack:** Windows Batch (`cmd.exe`), Git CLI, Python 3, pytest

---

## File Structure

- Create `tests/test_push_script_safety.py`: static regression checks for command ordering, safety constraints, repository isolation, and deployment guidance.
- Modify `一键推送.bat`: safe preflight, remote-state classification, fast-forward-only synchronization, independent repository processing, post-push verification, and accurate summary.

### Task 1: Lock the Safety Contract with Failing Tests

**Files:**
- Create: `tests/test_push_script_safety.py`
- Test: `tests/test_push_script_safety.py`

- [ ] **Step 1: Write the failing source-contract tests**

Create `tests/test_push_script_safety.py` with:

```python
"""Safety contract for the local dual-repository push launcher."""

from pathlib import Path


ROOT = Path(__file__).parents[1]
SCRIPT = ROOT / "一键推送.bat"


def _source() -> str:
    return SCRIPT.read_text(encoding="utf-8").replace("\r\n", "\n")


def test_launcher_uses_its_own_directory_and_shared_repo_handler():
    source = _source()

    assert 'set "SCRIPT_ROOT=%~dp0"' in source
    assert source.count("call :PROCESS_REPO") == 2
    assert ":PROCESS_REPO" in source
    assert 'set "ROOT=d:\\FIONA\\google AI"' not in source


def test_remote_state_is_checked_before_staging():
    source = _source()
    handler = source[source.index(":PROCESS_REPO") :]

    assert "git fetch --prune" in handler
    assert "git rev-list --left-right --count" in handler
    assert "git merge --ff-only" in handler
    assert handler.index("git fetch --prune") < handler.index("git add -A")
    assert handler.index("git rev-list --left-right --count") < handler.index(
        "git add -A"
    )


def test_dangerous_automatic_git_operations_are_absent():
    source = _source().lower()

    forbidden = (
        "git rebase",
        "pull --rebase",
        "push --force",
        "push -f",
        "reset --hard",
        "git stash",
    )
    for command in forbidden:
        assert command not in source


def test_divergence_and_post_push_verification_are_explicit():
    source = _source()

    assert "AHEAD" in source
    assert "BEHIND" in source
    assert "DIVERGED" in source
    assert "git rev-parse HEAD" in source
    assert "REMOTE_HEAD" in source
    assert "LOCAL_HEAD" in source


def test_repositories_are_independent_and_deploy_hint_is_correct():
    source = _source()

    assert 'call :PROCESS_REPO "quant_dashboard"' in source
    assert 'call :PROCESS_REPO "NEWS"' in source
    assert "cd /root/quant_dashboard/quant_dashboard ^&^& bash update.sh" in source
    assert 'if not "!FAIL_COUNT!"=="0"' in source
    assert "exit /b !FINAL_EXIT!" in source
```

- [ ] **Step 2: Run the tests and verify the expected failure**

Run:

```powershell
& 'D:\FIONA\google AI\quant_dashboard\quant_dashboard\.venv\Scripts\python.exe' `
  -m pytest tests/test_push_script_safety.py -q
```

Expected: failures showing the old script lacks `%~dp0`, `:PROCESS_REPO`, remote-state classification, and the corrected deployment command.

- [ ] **Step 3: Commit the failing tests**

```powershell
git add -- tests/test_push_script_safety.py
git commit -m "test: define safe push launcher contract"
```

### Task 2: Implement the Safe Shared Repository Workflow

**Files:**
- Modify: `一键推送.bat`
- Test: `tests/test_push_script_safety.py`

- [ ] **Step 1: Replace the duplicated main flow with repository configuration and independent calls**

The main section must derive paths from the script, initialize per-repository state, and call the shared handler twice:

```bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_ROOT=%~dp0"
if "%SCRIPT_ROOT:~-1%"=="\" set "SCRIPT_ROOT=%SCRIPT_ROOT:~0,-1%"
set "QD_DIR=%SCRIPT_ROOT%\quant_dashboard"
set "NEWS_DIR=%SCRIPT_ROOT%"
set "PUSH_COUNT=0"
set "FAIL_COUNT=0"
set "QD_STATUS=NOT_RUN"
set "NEWS_STATUS=NOT_RUN"
set "QD_MSG="

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] git not found
    set "FINAL_EXIT=1"
    goto :SUMMARY
)

call :PROCESS_REPO "quant_dashboard" "%QD_DIR%" "origin" "main" "QD"
call :PROCESS_REPO "NEWS" "%NEWS_DIR%" "git@github.com-terryzhoo-max/NEWS.git" "main" "NEWS"
goto :SUMMARY
```

- [ ] **Step 2: Add the preflight and safe remote-state classification**

At `:PROCESS_REPO`, assign the five arguments, validate the repository, branch and remote, then fetch before staging:

```bat
:PROCESS_REPO
set "REPO_NAME=%~1"
set "REPO_DIR=%~2"
set "REMOTE=%~3"
set "BRANCH=%~4"
set "REPO_KEY=%~5"
set "REPO_ACTIVE=false"
set "AHEAD=0"
set "BEHIND=0"
set "NEEDS_PUSH=0"

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

for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...!REMOTE!/!BRANCH! 2^>nul') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
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
```

- [ ] **Step 3: Add automatic staging, commit prompting, and push verification**

Continue the same subroutine with:

```bat
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
if /I not "!LOCAL_HEAD!"=="!REMOTE_HEAD!" (
    echo   [FAIL] Post-push verification mismatch
    goto :PROCESS_REPO_FAIL
)

echo   [OK] !REPO_NAME! push verified at !LOCAL_HEAD:~0,7!
set "!REPO_KEY!_STATUS=PUSHED"
set /a PUSH_COUNT+=1
goto :PROCESS_REPO_DONE
```

- [ ] **Step 4: Add isolated cleanup, failure handling, and summary exit status**

Add these labels after the main flow:

```bat
:PROCESS_REPO_FAIL
set "!REPO_KEY!_STATUS=FAILED"
set /a FAIL_COUNT+=1

:PROCESS_REPO_DONE
if /I "!REPO_ACTIVE!"=="true" popd
echo.
exit /b 0

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
```

- [ ] **Step 5: Run the source-contract tests and verify green**

Run:

```powershell
& 'D:\FIONA\google AI\quant_dashboard\quant_dashboard\.venv\Scripts\python.exe' `
  -m pytest tests/test_push_script_safety.py -q
```

Expected: `5 passed`.

- [ ] **Step 6: Commit the implementation**

```powershell
git add -- '一键推送.bat'
git commit -m "fix: make dual-repo push workflow fail safe"
```

### Task 3: Verify the Completed Launcher Without Real Pushes

**Files:**
- Verify: `一键推送.bat`
- Verify: `tests/test_push_script_safety.py`

- [ ] **Step 1: Run the complete regression test**

```powershell
& 'D:\FIONA\google AI\quant_dashboard\quant_dashboard\.venv\Scripts\python.exe' `
  -m pytest tests/test_push_script_safety.py -q
```

Expected: `5 passed`.

- [ ] **Step 2: Run repository and whitespace checks**

```powershell
git diff --check HEAD~2..HEAD
git status --short --branch
```

Expected: no whitespace errors; root repository is ahead only by the new local commits until the user explicitly pushes.

- [ ] **Step 3: Inspect all forbidden commands directly**

```powershell
Select-String -Path '.\一键推送.bat' `
  -Pattern 'git rebase','pull --rebase','push --force','push -f','reset --hard','git stash'
```

Expected: no matches.

- [ ] **Step 4: Review the final diff and do not execute a real push**

```powershell
git show --stat --oneline HEAD
git show --format=fuller --no-ext-diff HEAD -- '一键推送.bat'
```

Expected: only the intended launcher refactor; no real repository push is triggered during verification.

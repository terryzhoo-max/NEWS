# 一键推送结果展示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Windows 一键推送无需可见控制台或人工输入，也能在完成后用记事本明确展示成功或失败结果。

**Architecture:** 批处理在当前调用进程内同步执行，使用默认或环境变量提供的提交信息。最终状态始终写入 `%TEMP%\AlphaCore\latest-push-result.txt`；交互模式打开记事本，自动化模式只写文件。

**Tech Stack:** Windows Batch、Git CLI、Python 3、pytest

---

## 文件结构

- 修改 `一键推送.bat`：移除不可见控制台托管，提供非交互提交信息，生成并展示结果报告。
- 修改 `tests/test_push_script_safety.py`：更新入口契约，并增加无真实 Git 操作的结果报告集成测试。

### Task 1: 建立失败的结果报告测试

**Files:**
- Modify: `tests/test_push_script_safety.py`
- Test: `tests/test_push_script_safety.py`

- [ ] **Step 1: 用新的非交互入口契约替换旧托管控制台测试**

```python
def test_one_click_mode_is_non_interactive_and_opens_a_result_report():
    source = _source()

    assert 'start "AlphaCore Push" "%ComSpec%"' not in source
    assert 'set /p "COMMIT_MSG=' not in source
    assert 'set "DEFAULT_COMMIT_MSG=update: daily update"' in source
    assert 'if defined ALPHACORE_COMMIT_MSG' in source
    assert 'if not defined ALPHACORE_PUSH_NO_PAUSE (' in source
    assert 'start "" notepad.exe "!RESULT_FILE!"' in source
```

- [ ] **Step 2: 增加真实执行的失败报告测试**

在文件顶部加入 `import os` 和 `import subprocess`，再加入：

```python
def test_git_failure_writes_a_clear_result_report(tmp_path):
    result_file = tmp_path / "push-result.txt"
    env = os.environ.copy()
    env["PATH"] = str(Path(os.environ["SystemRoot"]) / "System32")
    env["ALPHACORE_PUSH_NO_PAUSE"] = "1"
    env["ALPHACORE_PUSH_RESULT_FILE"] = str(result_file)

    completed = subprocess.run(
        [os.environ["COMSPEC"], "/d", "/c", f'call "{SCRIPT}"'],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )

    assert completed.returncode == 1
    report = result_file.read_text(encoding="utf-8")
    assert "Overall: FAILED" in report
    assert "quant_dashboard: NOT_RUN" in report
    assert "NEWS: NOT_RUN" in report
    assert "Errors: 1" in report
```

- [ ] **Step 3: 运行新测试，确认因缺少实现而失败**

Run: `python -m pytest tests/test_push_script_safety.py -q`

Expected: 至少一个测试失败，失败原因是仍存在托管 `start`，且没有生成结果报告。

### Task 2: 实现非交互执行和结果报告

**Files:**
- Modify: `一键推送.bat:1-20`
- Modify: `一键推送.bat:75-100`
- Modify: `一键推送.bat:205-end`
- Test: `tests/test_push_script_safety.py`

- [ ] **Step 1: 移除托管控制台并初始化报告和提交信息**

删除 `--hosted`/`start "AlphaCore Push"` 入口块，在变量初始化区加入：

```bat
set "DEFAULT_COMMIT_MSG=update: daily update"
if defined ALPHACORE_COMMIT_MSG set "DEFAULT_COMMIT_MSG=!ALPHACORE_COMMIT_MSG!"
set "RESULT_FILE=%TEMP%\AlphaCore\latest-push-result.txt"
if defined ALPHACORE_PUSH_RESULT_FILE set "RESULT_FILE=!ALPHACORE_PUSH_RESULT_FILE!"
set "RESULT_READY=false"
```

- [ ] **Step 2: 删除提交信息输入，统一使用确定性提交信息**

用以下代码替换两个仓库的 `set /p` 分支：

```bat
set "COMMIT_MSG=!DEFAULT_COMMIT_MSG!"
echo   Commit message: "!COMMIT_MSG!"
```

- [ ] **Step 3: 在汇总阶段确定总体状态并调用报告子程序**

```bat
set "FINAL_EXIT=0"
set "OVERALL_STATUS=SUCCESS"
if not "!FAIL_COUNT!"=="0" (
    set "FINAL_EXIT=1"
    set "OVERALL_STATUS=FAILED"
)

call :WRITE_RESULT
if not defined ALPHACORE_PUSH_NO_PAUSE if /I "!RESULT_READY!"=="true" (
    echo  Opening result report: !RESULT_FILE!
    start "" notepad.exe "!RESULT_FILE!"
    if errorlevel 1 echo [WARN] Cannot open Notepad. Report: !RESULT_FILE!
)
exit /b !FINAL_EXIT!
```

- [ ] **Step 4: 添加结果报告子程序**

```bat
:WRITE_RESULT
for %%D in ("!RESULT_FILE!") do set "RESULT_DIR=%%~dpD"
if not exist "!RESULT_DIR!" mkdir "!RESULT_DIR!" >nul 2>&1
if not exist "!RESULT_DIR!" (
    echo [WARN] Cannot create result directory: !RESULT_DIR!
    exit /b 0
)

>"!RESULT_FILE!" (
    echo AlphaCore Push Result
    echo =====================
    echo Completed: !date! !time!
    echo Overall: !OVERALL_STATUS!
    echo quant_dashboard: !QD_STATUS!
    echo NEWS: !NEWS_STATUS!
    echo Pushed: !PUSH_COUNT!
    echo Errors: !FAIL_COUNT!
    if /I "!QD_STATUS!"=="PUSHED" (
        echo.
        echo Deploy on Alibaba Cloud:
        echo cd /root/quant_dashboard/quant_dashboard ^&^& bash update.sh
    )
    if /I "!OVERALL_STATUS!"=="FAILED" (
        echo.
        echo Action: Review the console output and run the launcher again after fixing the error.
    )
)
if errorlevel 1 (
    echo [WARN] Cannot write result report: !RESULT_FILE!
    exit /b 0
)
set "RESULT_READY=true"
exit /b 0
```

- [ ] **Step 5: 运行测试，确认实现通过**

Run: `python -m pytest tests/test_push_script_safety.py -q`

Expected: `7 passed`。

### Task 3: Windows 行为与安全回归验证

**Files:**
- Verify: `一键推送.bat`
- Verify: `tests/test_push_script_safety.py`

- [ ] **Step 1: 统一批处理与测试文件为 UTF-8 无 BOM、CRLF**

使用 PowerShell 读取两个文件，将换行统一为 CRLF，并用 `[System.Text.UTF8Encoding]::new($false)` 写回。

- [ ] **Step 2: 在隐藏 Git 的环境中执行批处理**

设置：

```powershell
$env:PATH = 'C:\Windows\System32'
$env:ALPHACORE_PUSH_NO_PAUSE = '1'
$env:ALPHACORE_PUSH_RESULT_FILE = "$env:TEMP\AlphaCore-test\result.txt"
```

执行 `cmd.exe /d /c call "D:\FIONA\google AI\一键推送.bat"`，预期退出码为 `1`，报告存在并包含 `Overall: FAILED`。

- [ ] **Step 3: 运行完整安全测试和差异检查**

Run: `python -m pytest tests -q`

Expected: `7 passed`。

Run: `git diff --check`

Expected: 退出码 `0`，无输出。

- [ ] **Step 4: 提交实现**

```powershell
git add -- '一键推送.bat' 'tests/test_push_script_safety.py' 'docs/superpowers/plans/2026-10-14-push-result-display.md'
git commit -m "fix: show durable push result report"
```

"""Safety contract for the local dual-repository push launcher."""

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).parents[1]
SCRIPT = ROOT / "一键推送.bat"


def _source() -> str:
    return SCRIPT.read_text(encoding="utf-8").replace("\r\n", "\n")


def test_one_click_mode_is_non_interactive_and_opens_a_result_report():
    source = _source()

    assert 'start "AlphaCore Push" "%ComSpec%"' not in source
    assert 'set /p "COMMIT_MSG=' not in source
    assert 'set "DEFAULT_COMMIT_MSG=update: daily update"' in source
    assert "if defined ALPHACORE_COMMIT_MSG" in source
    assert "if not defined ALPHACORE_PUSH_NO_PAUSE (" in source
    assert 'start "" notepad.exe "!RESULT_FILE!"' in source


def test_git_failure_writes_a_clear_result_report(tmp_path):
    result_file = tmp_path / "push-result.txt"
    env = os.environ.copy()
    env["PATH"] = str(Path(os.environ["SystemRoot"]) / "System32")
    env["ALPHACORE_PUSH_NO_PAUSE"] = "1"
    env["ALPHACORE_PUSH_RESULT_FILE"] = str(result_file)

    completed = subprocess.run(
        [os.environ["COMSPEC"], "/d", "/c", str(SCRIPT)],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )

    assert completed.returncode == 1
    assert "[WARN] Cannot write result report" not in completed.stdout
    report = result_file.read_text(encoding="utf-8")
    assert "Overall: FAILED" in report
    assert "quant_dashboard: NOT_RUN" in report
    assert "NEWS: NOT_RUN" in report
    assert "Errors: 1" in report


def test_launcher_uses_its_own_directory_and_shared_repo_handler():
    source = _source()

    assert 'set "SCRIPT_ROOT=%~dp0"' in source
    assert source.count("call :PROCESS_REPO") == 2
    assert "\n:PROCESS_REPO\n" in source
    assert 'set "ROOT=d:\\FIONA\\google AI"' not in source


def test_remote_state_is_checked_before_staging():
    source = _source()
    handler = source[source.index("\n:PROCESS_REPO\n") :]

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

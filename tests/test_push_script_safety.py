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

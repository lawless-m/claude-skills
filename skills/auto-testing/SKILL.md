---
name: auto-testing
description: Use when building an automated test → issue → fix loop with Claude Code and GitHub issues — overnight auto-fixing, regression loops, self-healing CI. Key insight is shell-gated lifecycle - shell exit codes, not Claude, decide when issues close.
---

# Automated Test-Fix Loop

Pattern for a Test → Fail → Issue → Fix → Repeat cycle that runs until tests pass, developed on the iSCSI project.

## Shell-based gating (the core rule)

LLMs rationalize failures and close issues prematurely ("the timeout is infrastructure, not my code"). Never put "close the issue if tests pass" in a prompt — the shell runs the tests and enforces `tests pass && close`:

```bash
./run-tests.sh full
if [ $? -eq 0 ]; then
    gh issue close "$ISSUE_NUM" --comment "Tests passed"
else
    gh issue comment "$ISSUE_NUM" --body "Tests failed. Leaving open."
fi
```

Separation of concerns: Claude writes code; the shell runs tests, checks exit codes, and manages issues. Prompts must explicitly say: do NOT run tests, do NOT close the issue — and that the tests are CORRECT and must not be modified (Claude will otherwise "fix" tests to make them pass).

## Issue-first workflow

Check for open issues BEFORE running tests. If an issue is open, fix it; only run tests when nothing is open. This prevents duplicate issues, issue spam, and wasted test runs.

## WIP branches preserve failed attempts

Before each retry, commit the previous failed attempt to an `auto-fix-wip/issue-N` branch and reference it in the next iteration's prompt, so approaches aren't repeated.

## Worked example: iSCSI project

- Ended with 25 tests passing (0 failed) via the automated test → issue → fix → close cycle.
- Found and fixed a multi-PDU transfer bug — a 6-line fix.
- Tests were validated against a reference implementation first: pass on reference but fail on ours = our bug; fail on both = suspect the tests.
- Shell gating prevented premature issue closing throughout.

## Templates

Full test-runner, issue-fixer/implementer, and auto-fix-loop scripts: see `reference-templates.md`.

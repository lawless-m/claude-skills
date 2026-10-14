# Auto-Testing Script Templates

Working templates from the iSCSI project. Exit code semantics used throughout:

```
0   = success (all tests passed)
1   = test failures
124 = timeout (likely hang/infinite loop)
```

## run-tests.sh — test runner with issue creation

```bash
#!/bin/bash
set -euo pipefail

TIMEOUT_SECONDS=10
OUTPUT_FILE="/tmp/test-output.txt"
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
OS_INFO=$(uname -a)

# Run tests with timeout
timeout $TIMEOUT_SECONDS <YOUR_TEST_COMMAND> 2>&1 | tee "$OUTPUT_FILE"
EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 124 ]; then
    EXIT_CODE="124 (timeout after ${TIMEOUT_SECONDS}s)"
fi

if [ $EXIT_CODE != 0 ]; then
    # Strip ANSI color codes
    CLEAN_OUTPUT=$(sed 's/\x1b\[[0-9;]*m//g' "$OUTPUT_FILE")

    # Check for duplicates before creating
    EXISTING=$(gh issue list --state open --search "Test Failure: <TEST_NAME>" --json number --jq '.[0].number')
    if [ -n "$EXISTING" ]; then
        gh issue comment "$EXISTING" --body "Test still failing in commit $(git rev-parse --short HEAD)"
    else
        gh issue create \
            --title "Test Failure: <TEST_NAME>" \
            --label test-failure \
            --body "$(cat <<EOF
## Test Failure Report

**Exit Code:** $EXIT_CODE
**Date:** $DATE
**Commit:** $COMMIT
**Branch:** $BRANCH
**OS:** $OS_INFO

### Test Output
\`\`\`
$CLEAN_OUTPUT
\`\`\`

### Files Involved
- Test: <path/to/test>
- Implementation: <path/to/impl>

### Expected Behavior
<What should happen>

### Actual Behavior
<What actually happened>
EOF
)"
    fi
    exit 1
fi

echo "All tests passed!"
exit 0
```

Restart the target/server before each run so you never test stale state:

```bash
pkill -f target_process
sleep 0.5
cargo run --example target &
```

## fix-issue.sh / implement-issue.sh — Claude writes code, shell closes issues

```bash
#!/bin/bash
set -euo pipefail

ISSUE_NUM=$1
MODEL=${2:-sonnet}

ISSUE_BODY=$(gh issue view $ISSUE_NUM --json body --jq '.body')

PROMPT="Fix the failure described in issue #$ISSUE_NUM:

$ISSUE_BODY

IMPORTANT: The tests are CORRECT and must NOT be modified.
Fix the implementation code, not the test code.

IMPORTANT: DO NOT run tests. DO NOT close the issue.
Your job:
1. Implement the fix
2. Commit changes
3. Add a comment documenting what you did

The wrapper script will run tests and close the issue if they pass."

claude --model "$MODEL" "$PROMPT"
CLAUDE_EXIT=$?

# Shell-based test gating (NOT Claude's responsibility)
if [ $CLAUDE_EXIT -eq 0 ]; then
    echo "Running tests to verify..."
    ./run-tests.sh full
    TEST_EXIT=$?

    if [ $TEST_EXIT -eq 0 ]; then
        gh issue close $ISSUE_NUM --comment "Implementation complete and tests pass"
    elif [ $TEST_EXIT -eq 124 ]; then
        gh issue comment $ISSUE_NUM --body "Timeout. Leaving open for debugging."
    else
        gh issue comment $ISSUE_NUM --body "Tests failed (exit $TEST_EXIT). Leaving open."
    fi
fi
```

Permission modes for the `claude` invocation: interactive (default), `--permission-mode acceptEdits`, or `--dangerously-skip-permissions` (sandboxed VMs/containers only).

## auto-fix-loop.sh — orchestration with issue-first logic

```bash
#!/bin/bash
set -euo pipefail

MAX_ITERATIONS=${1:-10}
MODEL=${2:-sonnet}

iteration=0
while [ $iteration -lt $MAX_ITERATIONS ]; do
    iteration=$((iteration + 1))

    # 1. Check for open issues FIRST (prevents duplicates)
    OPEN_ISSUES=$(gh issue list --state open --label test-failure --json number --jq '.[].number')

    if [ -n "$OPEN_ISSUES" ]; then
        ISSUE_NUM=$(echo "$OPEN_ISSUES" | head -1)
        echo "Found issue #$ISSUE_NUM, attempting fix..."

        # Preserve previous failed attempt on a WIP branch
        WIP_BRANCH="auto-fix-wip/issue-${ISSUE_NUM}"
        if [ $iteration -gt 1 ]; then
            git checkout -b "$WIP_BRANCH" || git checkout "$WIP_BRANCH"
            git add -A
            git commit -m "WIP: Attempted fix iteration $((iteration - 1))"
            git push origin "$WIP_BRANCH"
            git checkout master
        fi

        ./fix-issue.sh "$ISSUE_NUM" "$MODEL"
    else
        # No open issues - run tests to verify
        echo "No open issues. Running tests..."
        if ./run-tests.sh full; then
            echo "All tests passed!"
            exit 0
        else
            echo "Tests failed. New issue may be created."
        fi
    fi

    sleep 2
done

echo "Max iterations reached"
exit 1
```

Typical iteration budgets: 5-10 for a quick check, 50+ for overnight runs. Escalate the model (haiku → sonnet → opus) when the same issue keeps reopening.

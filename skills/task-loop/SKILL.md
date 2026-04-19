---
name: task-loop
description: One slice per invocation — picks the next unblocked pending task, works it to completion, then calls ScheduleWakeup(60) to fire the next slice if work remains. Designed to be driven by /loop in dynamic/self-paced mode.
---

# task-loop

Does **one task per invocation**, then schedules the next wake-up. Designed to run
under `/loop` in dynamic/self-paced mode via `ScheduleWakeup`. Does not internally
sleep or block. Does not loop within a turn.

This skill does not create tasks. It consumes whatever is already in the task list
(set up via `TaskCreate` beforehand, e.g. during planning).

## Cadence protocol

Follows the same contract as Matt's other `/loop`-driven commands (see carry-on.md
for reference):

- **Always do the slice first, commit/verify, then schedule the next wake-up.**
  Never schedule before doing work in a turn.
- **Delay: 60 seconds, flat.** That's the `ScheduleWakeup` runtime floor (clamps to
  `[60, 3600]`), and it's the tightest cadence available. Matt explicitly wants
  the tightest cadence — do not invent longer delays.
- **If no unblocked pending tasks remain**, do not schedule. Report completion
  and let the loop end.
- **If the slice halts** (failure, ambiguity, user input needed), do not schedule.
  Report the halt reason and exit the loop so Matt can investigate.

## Instructions

When the user invokes this skill, follow these rules exactly:

1. **Fetch the task list** with `TaskList`.

2. **Pick the next task**:
   - Filter to tasks with `status: pending` AND empty `blockedBy`.
   - If the list is empty, print `task-loop: no unblocked pending tasks, loop complete`
     and STOP. Do not call `ScheduleWakeup`.
   - Otherwise, pick the one with the **lowest numeric ID**.

3. **Inspect the task** with `TaskGet` to read the full description.

4. **Mark it in_progress** with `TaskUpdate` (set `status: in_progress`).

5. **Announce**: `task-loop: starting #<id> — <subject>`.

6. **Do the work** described in the task's `description` field. Treat the description
   as the authoritative instruction. Use any tools needed. If verification commands are
   specified (e.g. `cargo check`, `cargo test`), run them and confirm they pass.

7. **Complete or halt**:
   - **Success + verification passed**: `TaskUpdate` → `status: completed`. Print
     `task-loop: completed #<id>`.
   - **Failed / stuck / ambiguous**: leave `in_progress`. Print
     `task-loop: halted on #<id> — <one-line reason>`. STOP. Do NOT schedule the next
     wake-up.
   - **Never mark a task completed if tests/verification fail.** Per Matt's CLAUDE.md,
     partial completion is not completion.

8. **Decide whether to schedule the next slice**:
   - Re-fetch `TaskList`. If any `pending` task with empty `blockedBy` remains, call
     `ScheduleWakeup(60)` to fire the next slice. Print `task-loop: scheduled next slice in 60s`.
   - If no more unblocked tasks remain, print `task-loop: list drained, loop complete`
     and do NOT schedule. Let the loop terminate naturally.

9. **End the turn.** Do not loop within a turn. Do not `sleep`. The next slice arrives
   via `/loop` + `ScheduleWakeup`.

## Halting conditions (no schedule)

Do not call `ScheduleWakeup` if any of these apply — let the loop terminate:

- No unblocked pending tasks remain (normal completion).
- The slice failed or couldn't be completed (halted on a task).
- A task description required user input that wasn't provided.
- The user has intervened with instructions that change the plan.

## What "doing the work" looks like

Each task in the list has a `description` field with explicit acceptance criteria.
Trust it. Don't expand scope, don't refactor adjacent code, don't add features
beyond what's described. Per Matt's CLAUDE.md:

- Every changed line should trace directly to the task description.
- If the task says "verify with `cargo check`", run it before marking done.
- If the task says "unit tests for X", tests must pass before marking done.

If the task description is genuinely ambiguous, halt rather than guess.

## Examples

### Example 1: Normal slice, more work remains

```
User: /task-loop   (invoked by /loop in dynamic mode)

Claude: [TaskList → #1 is the lowest-ID unblocked pending task]
[TaskGet #1]
[TaskUpdate #1 → in_progress]
task-loop: starting #1 — Bootstrap Rust project
[writes Cargo.toml, creates module files, runs cargo check]
[cargo check passes]
[TaskUpdate #1 → completed]
task-loop: completed #1
[TaskList → #2 is now unblocked]
[ScheduleWakeup(60)]
task-loop: scheduled next slice in 60s
```

### Example 2: Halt on failure

```
User: /task-loop

Claude: [picks up #3]
task-loop: starting #3 — Implement nmap XML parser
[writes parser, runs cargo test, tests fail]
[investigates, attempts fix, still failing — root cause unclear]
task-loop: halted on #3 — parser tests fail on fixture B, unclear whether fixture or parser is wrong; needs human review
[does NOT schedule; loop ends]
```

### Example 3: List drained

```
User: /task-loop

Claude: [TaskList returns no unblocked pending tasks]
task-loop: no unblocked pending tasks, loop complete
[does NOT schedule]
```

### Example 4: Last task completed, nothing left

```
User: /task-loop

Claude: [picks up #12]
task-loop: starting #12 — End-to-end smoke test against real scan data
[runs the smoke test, passes]
[TaskUpdate #12 → completed]
task-loop: completed #12
[TaskList → empty]
task-loop: list drained, loop complete
[does NOT schedule]
```

## Notes

- This skill is designed for `/loop` in **dynamic/self-paced mode**, where the
  command itself drives cadence via `ScheduleWakeup`. It is NOT designed for
  cron-style `/loop 60s /task-loop`, though it would mostly still work there
  (with the caveat that cron mode would keep firing even when halted).
- The 60s minimum is a `ScheduleWakeup` runtime floor — not a choice. The tightest
  cadence available is what we use.
- One commit per slice is a good default if the task involves code changes, but
  not mandatory — some tasks (e.g. running verification) produce no commit.

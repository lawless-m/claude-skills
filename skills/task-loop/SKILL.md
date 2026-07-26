---
name: task-loop
description: Invoke once per timer tick under /loop dynamic (self-paced) mode — picks the next unblocked pending task, works it to completion, and schedules the next wake-up if work remains. Not for cron-style /loop 60s.
---

# task-loop

Does **one task per invocation**, then schedules the next wake-up via `ScheduleWakeup`. Designed for `/loop` in **dynamic/self-paced mode**, where the command drives its own cadence — not cron-style `/loop 60s /task-loop` (which would keep firing even after a halt). Does not create tasks (consume whatever `TaskCreate` set up during planning), does not sleep or block, does not loop within a turn.

## Flow

Always do the slice first, then decide whether to schedule — never schedule before doing work.

1. **`TaskList`** to fetch tasks.
2. **Pick** the `pending` task with empty `blockedBy` and the lowest numeric ID. If none, print `task-loop: no unblocked pending tasks, loop complete` and STOP (no `ScheduleWakeup`).
3. **`TaskGet`** to read the full description, then **`TaskUpdate` → in_progress**.
4. Announce: `task-loop: starting #<id> — <subject>`.
5. **Do the work** in the task's `description`, treating it as authoritative. Don't expand scope or refactor adjacent code — every changed line should trace to the description. Run any verification commands the task names (`cargo check`, `cargo test`, etc.) and confirm they pass.
6. **Complete or halt** — never mark completed if verification fails (partial completion ≠ completion, per CLAUDE.md):
   - Success + verification passed → `TaskUpdate` → completed, print `task-loop: completed #<id>`.
   - Failure/stuck/ambiguous → leave `in_progress`, print `task-loop: halted on #<id> — <one-line reason>`, STOP (no schedule).
7. **Schedule next slice**: re-fetch `TaskList`. If any unblocked pending task remains, call `ScheduleWakeup(60)` and print `task-loop: scheduled next slice in 60s`. Otherwise print `task-loop: list drained, loop complete` and don't schedule.
8. End the turn. The next slice arrives via `/loop` + `ScheduleWakeup`.

**60 seconds is a `ScheduleWakeup` runtime floor** (clamps to `[60, 3600]`), not a choice — it's the tightest cadence available, which is what Matt wants.

## When NOT to schedule (let the loop end)

- No unblocked pending tasks remain (normal completion).
- The slice failed or the task couldn't be completed.
- A task needs user input that wasn't provided, or the user intervened to change the plan.
- If a task description is genuinely ambiguous, halt rather than guess.

One commit per slice is a good default for code changes but not mandatory — some tasks (e.g. running verification) produce no commit.

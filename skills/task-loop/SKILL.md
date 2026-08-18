---
name: task-loop
description: Invoke once per timer tick under /loop dynamic mode — picks the next unblocked task from TASKS.md, works it, schedules the next wake-up. Not for cron-style /loop 60s.
---

# task-loop

Does **one task per invocation**, then schedules the next wake-up via `ScheduleWakeup`. Designed for `/loop` in **dynamic/self-paced mode**, where the command drives its own cadence — not cron-style `/loop 60s /task-loop` (which would keep firing even after a halt). Does not create tasks (consume whatever planning wrote), does not sleep or block, does not loop within a turn.

## The queue is a file

`TASKS.md` in the repository root. Not a session-scoped task list: the built-in one was keyed by session UUID, so a queue never survived opening a new conversation — fatal for any plan spanning more than one sitting. A file outlives the session, survives a crash, diffs in review, and depends only on Read/Edit/Bash.

Each task is one `##` section:

    ## [<status>] <id> — <subject>
    blocked-by: <comma-separated ids, or —>
    verify: <command>

    <description — authoritative, may run to several paragraphs>

`[ ]` pending, `[~]` in progress, `[x]` done. State changes are a **one-character edit** to the checkbox; nothing else moves. That keeps diffs honest and makes a half-finished edit obvious.

If `TASKS.md` is absent, print `task-loop: no TASKS.md, nothing to drain` and STOP.

## Flow

Always do the slice first, then decide whether to schedule — never schedule before doing work.

1. **Read `TASKS.md`.**
2. **Pick** the lowest-id task that is `[ ]` **and** whose every `blocked-by` id is `[x]`. If none, print `task-loop: no unblocked pending tasks, loop complete` and STOP (no `ScheduleWakeup`).
   - If tasks remain but all are blocked by something not `[x]`, that is a stall, not completion: print `task-loop: stalled — #<id> blocked by #<ids>` and STOP.
3. **Mark it `[~]`** with a single `Edit` to its header line, so a crash mid-slice leaves visible evidence of what was in flight.
4. Announce: `task-loop: starting #<id> — <subject>`.
5. **Do the work** in the task's description, treating it as authoritative. Don't expand scope or refactor adjacent code — every changed line should trace to the description. Run the verification commands the task names and confirm they pass.
6. **Complete or halt** — never mark done if verification fails (partial completion ≠ completion, per CLAUDE.md):
   - Success + verification passed → edit the header to `[x]`, print `task-loop: completed #<id>`.
   - Failure/stuck/ambiguous → **leave it `[~]`**, print `task-loop: halted on #<id> — <one-line reason>`, STOP (no schedule). The `[~]` is the record of where it stopped; do not tidy it back to `[ ]`.
7. **Schedule next slice**: re-read `TASKS.md`. If any unblocked `[ ]` task remains, call `ScheduleWakeup(60)` and print `task-loop: scheduled next slice in 60s`. Otherwise print `task-loop: list drained, loop complete` and don't schedule.
8. End the turn. The next slice arrives via `/loop` + `ScheduleWakeup`.

**60 seconds is a `ScheduleWakeup` runtime floor** (clamps to `[60, 3600]`), not a choice — it's the tightest cadence available, which is what Matt wants.

## When NOT to schedule (let the loop end)

- No unblocked pending tasks remain (normal completion).
- The slice failed or the task couldn't be completed.
- A task needs user input that wasn't provided, or the user intervened to change the plan.
- If a task description is genuinely ambiguous, halt rather than guess.

One commit per slice is a good default for code changes but not mandatory — some tasks (e.g. running verification) produce no commit. When a task says "do not commit", honour it; the queue file itself is part of the working tree, so a slice that commits should say whether `TASKS.md` goes with it.

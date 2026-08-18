---
description: Drain the tasks/ queue — one slice after another, no timer, until done or something stops it
argument-hint: [max slices — omit to drain the whole queue]
---

# tasks

Work the queue in `tasks/` until it is empty or something stops you. `$ARGUMENTS`, if a
number, caps how many slices to run; otherwise drain the lot.

No timer and no `ScheduleWakeup`. The old loop waited 60 s between slices only because
that is the scheduler's floor — a cost with no benefit. Finish a slice, pick the next,
carry on in the same turn.

That is safe here because **the queue is files**. A completed task is a move on disk, so
progress does not live in the conversation: if context is summarised mid-drain, re-read
`ls tasks/` and continue with nothing lost. A session-scoped list could not do that,
which is why it needed a fresh turn per slice.

## Flow

1. **Read the queue**: `ls tasks/*.md tasks/completed/*.md 2>/dev/null`. If `tasks/` has
   no `.md` files, print `tasks: queue empty` and stop.
2. **Run one slice** exactly as the `task-loop` skill defines it — that skill is the
   single definition of a slice; do not restate or vary it here.
3. **Then decide**:
   - Slice completed and unblocked work remains, and the cap is not reached → go to 2.
   - `tasks/` now empty → print `tasks: queue drained — <n> completed` and stop.
   - Slice halted → print `tasks: stopped at #<id> — <reason>` and stop. Do **not**
     move on to another task; a halt means something needs a human.
   - Everything left is blocked → `tasks: stalled — #<id> blocked by #<ids>` and stop.
   - Cap reached → print `tasks: <n> slices done, <m> remaining` and stop.

## Stop, don't push through

A halt is not a task to skip. The queue is ordered and often dependent, and a failure
usually means the plan met reality — that is information, not an obstacle. Report it and
let the user decide.

Announce each slice as it starts so a long drain is followable rather than a wall of
output arriving at the end.

## Be honest about how far this gets

Long descriptions plus real work plus verification output accumulate. A queue whose
tasks are large will exhaust context before it drains, and that is fine — say how many
slices ran and what is next. Resuming is `/tasks` again. Do not pretend a partial drain
was a full one, and never mark a task done to keep the run going.

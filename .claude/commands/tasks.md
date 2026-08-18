---
description: Drain the tasks/ queue — one slice after another, no timer, until done or something stops it
argument-hint: [max slices — omit to drain the whole queue]
---

# tasks

Work the queue in `tasks/` until it is empty or something stops you. `$ARGUMENTS`, if a
number, caps how many slices to run — an override for when the user wants one, never a
default and never something to ask them for. Otherwise drain the lot.

Finish a slice, pick the next, carry on in the same turn.

Progress lives on disk, not in the conversation: a completed task is a move. If context
is summarised mid-drain, re-read `ls tasks/` and continue with nothing lost.

## Flow

1. **Read the queue**: `ls tasks/*.md tasks/completed/*.md 2>/dev/null`. If `tasks/` has
   no `.md` files, print `tasks: queue empty` and stop.
2. **Run one slice** exactly as the `task-loop` skill defines it — that skill is the
   single definition of a slice; do not restate or vary it here.
3. **Then decide**:
   - Slice completed and unblocked work remains, and the cap is not reached → go to 2.
   - `tasks/` now empty → print `tasks: queue drained — <n> completed` and stop.
   - Slice halted → print `tasks: halted #<id> — <reason>`, leave the `halted:` line in
     its file, and go to 2 for the next *unblocked* task. Do not retry the halted one.
   - Nothing runnable remains → `tasks: <n> completed, <m> halted, <k> blocked` and stop.
   - Cap reached → print `tasks: <n> slices done, <m> remaining` and stop.

## A halt skips, it does not stop the run

A halt is not a failure of the run, and it is not a task to retry. Record why in the
task's `halted:` line, leave the file in `tasks/`, and move to the next unblocked task.

Skipping is safe because the queue already says what a failure invalidates: anything
genuinely downstream of a halted task has it in `blocked-by` and becomes unrunnable by
itself. Anything else is independent, and there is no reason a stumble on one should
cost the rest. Stopping the whole queue on the first halt is only ever right when
someone is watching — and the person who prepared a queue and left is precisely the
person it fails.

Do not attempt to unblock a halted task by editing its description, relaxing its
verification, or inventing a workaround its author did not sanction. Halt, record,
carry on.

At the end, list every halted task with its reason together, so the first thing read on
return is what needs a decision.

## Keep going until something objective stops you

The stop conditions are exactly the four above: drained, halted, stalled, or a cap the
user asked for. Nothing else. In particular, do **not** stop because the run feels long,
because a lot has been done, because the next task looks big, because it seems a good
moment to report, or because the context window is filling. Those are judgements the
user cannot make in advance and cannot see you making — from their side an unexplained
stop is indistinguishable from a fault.

Context is not a stop condition. Compaction is automatic, and the queue is on disk
precisely so it survives one: after a summary, re-read `ls tasks/` and continue. The
task descriptions, the verification commands and the working tree are all files. Nothing
the next slice needs lives in the conversation, so there is nothing to preserve by
stopping early — carry on and let the summary happen underneath you.

If you think a run should end for a reason not on the list, say so and ask. Do not
decide it silently and describe it afterwards as though it were a rule.

Announce each slice as it starts, so a long run is followable as it happens rather than
arriving as a wall of output at the end. That, not stopping early, is what keeps a drain
supervisable.

Never mark a task done to keep a run going, and never report a partial drain as a full
one.

---
name: task-loop
description: Do the next unblocked task from tasks/. Exactly one slice, then stop. Use when the user says "do the next task"; /tasks repeats it to drain the queue.
---

# task-loop

Does **exactly one task**, then stops and reports. Nothing else — no sleeping, no
scheduling, no draining the queue (that is `/tasks`), no creating tasks (consume
whatever planning wrote).

Stopping after one slice is the point: it is the unit that either succeeds and moves a
file, or fails and leaves a reason. `/tasks` is what repeats it.

## The queue is a directory, and location is the state

    tasks/NN.md              outstanding
    tasks/completed/NN.md    done

`ls tasks/*.md` **is** the queue: the only fact about a task's state is where its file
sits, and an empty `tasks/` means done. Completing one is a move, which git records as a
rename, so the content stays byte-identical from planning to done.

Each file:

    ---
    id: 4
    subject: Model the MC1408 DAC settling glitch
    blocked-by: [3]                  # ids, [] if none
    verify: cargo test -p beam-rasteriser
    halted: <reason>                 # optional; see below
    ---

    <description — authoritative, may run to several paragraphs>

One file per task, so a slice reads only the task it is about to do, two sessions on
different tasks never collide, and finishing #7 shows in review as one file moving.

If `tasks/` holds no `.md` files, print `task-loop: queue empty, nothing to do` and STOP.

## Flow

Do the slice first, then decide whether to schedule — never schedule before working.

1. **Read the queue**: `ls tasks/*.md tasks/completed/*.md 2>/dev/null`. Outstanding
   work is the first list; the second is what `blocked-by` resolves against.
2. **Pick** the lowest id in `tasks/` whose every `blocked-by` id has a file in
   `tasks/completed/`. If none:
   - `tasks/` empty → `task-loop: all tasks done` and STOP.
   - files remain but all are blocked → a stall, not completion:
     `task-loop: stalled — #<id> blocked by #<ids>` and STOP.
3. **Read only that file.** Its description is authoritative. A `halted:` line means a
   previous attempt stopped there — read the reason before repeating it.
4. Announce: `task-loop: starting #<id> — <subject>`.
5. **Do the work.** Don't expand scope or refactor adjacent code — every changed line
   should trace to the description. Run the `verify` command and any others the
   description names, and confirm they pass.
6. **Complete or halt** — never complete if verification fails (partial completion ≠
   completion, per CLAUDE.md):
   - Verified → move it: `git mv tasks/NN.md tasks/completed/` (plain `mv` if the file
     is untracked). Print `task-loop: completed #<id>`.
   - Failed/stuck/ambiguous → **leave it in `tasks/`** and add or update a `halted:`
     line with a one-line reason. Print `task-loop: halted on #<id> — <reason>` and
     STOP. Do not move it; not-done work belongs in the queue.

After the slice, report what is next (`task-loop: next is #<id> — <subject>`) and stop.
Do not start it.

One commit per slice is a good default for code changes but not mandatory. When a task
says "do not commit", honour it — but note the completion move is itself a change to
the working tree, so say whether it goes with the commit or stands alone.

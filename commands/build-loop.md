---
description: Plan the current goal into a finite, verifiable task list that /tasks can drain
argument-hint: [goal — omit to use what we've been working on]
---

# build-loop

Create a **finite, ordered task list** that `/tasks` can drain, then stop. The planning itself is delegated to a Fable subagent — that's the point of
this command: no `/model` juggling. (Frontmatter `model:` is ignored on the typed
slash-command path, hence the delegation.)

Goal: `$ARGUMENTS` — if empty, it's whatever this session has been working toward.
State it back in one sentence before doing anything, so a misreading costs one
exchange rather than a whole loop.

**Plan only.** No source edits, no commits, no builds.

## Steps

1. **Check the queue**: `ls tasks/*.md tasks/completed/*.md 2>/dev/null` in the
   repository root. Location is the state — a file in `tasks/` is outstanding, one in
   `tasks/completed/` is done. See the `task-loop` skill for the format.

2. **If `tasks/` is not empty**, don't silently add to it — show what's there and ask
   whether to resume, replace, or append deliberately. Stop until answered. A `halted:`
   line means a previous slice stopped mid-task; quote the reason.

3. **Compose a planning brief** from what this session already knows. The planner is a
   fresh agent — it does NOT see this conversation, so the brief must carry:
   - the goal, one sentence;
   - working directory and the files involved;
   - the project's real build/verify commands — only ones confirmed in use here,
     never guessed;
   - constraints and anything out of scope.

4. **Spawn the planner**: `Agent` with `subagent_type: "general-purpose"`,
   `model: "fable"`, prompt = the brief plus the planning rules below, verbatim.

   The planner returns task *specs*; you write them into `tasks/`. Keep your part
   mechanical.

5. **Write `tasks/NN.md` verbatim** from the returned JSON, in array order, ids from 1,
   zero-padded so `ls` sorts correctly.
   Copy `description` exactly as written — do not re-word, expand, or improve it. The
   planner read the code; you did not. Prefer generating the files with a script over
   retyping, so nothing is lost or silently "improved" in transit. Each file:

       ---
       id: <id>
       subject: <subject>
       blocked-by: [<ids>]
       verify: <command>
       ---

       <description>

   Convert the planner's 0-based `blockedBy` indices to 1-based ids. If a verification
   command it cites is cheap to confirm and load-bearing, spot-check it first — but
   check, don't rewrite.

6. **Verify the queue before handing it over.** Parse the files back: every id unique,
   no `blocked-by` pointing at a missing id, and the graph drains (repeatedly removing
   runnable tasks empties the list — no cycle). A queue that cannot drain is a loop
   that cannot end. Then hand off: id, subject, one-line verification for each, then
   `build-loop: <n> tasks in tasks/. Gate: #<last> — <check>. Run: /tasks to drain,
   or /task-loop for a single slice`
   If the planner returned a question instead of tasks, put it to the user and stop.

## Planning rules (include verbatim in the agent prompt)

You have no task-list tools and you do not write any file. Your final output IS the
task list, as JSON and nothing else — no preamble, no commentary:

```json
[{"subject": "...", "activeForm": "...", "description": "...", "blockedBy": []}]
```

- Array order is execution order — a slice takes the lowest-id unblocked task. Use `blockedBy` (0-based indices into this array) only for real dependencies;
  plain ordering is already implied.
- **Make tasks small.** One coherent change with one verification, not a work
  package. If the description needs "and then", or lists numbered sub-parts, or names
  more than a couple of files to change, it is at least two tasks — split it. Err
  small: ten tasks that each land in minutes are far better than three that each take
  an hour, because every completed task is a checkpoint on disk, a visible
  announcement, and a place a failure can stop cleanly. A task too large to finish is
  the one failure mode that leaves no useful trace.
- Each task's `description` must stand alone — the executing model may have lost all
  conversational context by then. It states: what to do, the exact verification
  command (only commands the brief confirms exist — never invent one), an observable
  done-when, and what must NOT be touched where scope creep is a risk.
- Write descriptions in full. They are the deliverable; whoever relays them will copy
  them verbatim, so anything you leave implicit is lost.
- The last task is an end-to-end gate — the check you'd use to call the whole goal
  done. A finite list with a real final check is what makes the drain provably end.
- Nothing speculative. If the brief is ambiguous, return no tasks — return
  `{"question": "..."}` instead.

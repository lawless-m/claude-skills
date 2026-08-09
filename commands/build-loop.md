---
description: Plan the current goal into a finite, verifiable task list that /task-loop can drain
argument-hint: [goal — omit to use what we've been working on]
---

# build-loop

Create a **finite, ordered task list** that `/loop /task-loop` can drain unattended,
then stop. The planning itself is delegated to a Fable subagent — that's the point of
this command: no `/model` juggling. (Frontmatter `model:` is ignored on the typed
slash-command path as of 2.1.226, hence the delegation.)

Goal: `$ARGUMENTS` — if empty, it's whatever this session has been working toward.
State it back in one sentence before doing anything, so a misreading costs one
exchange rather than a whole loop.

**Plan only.** No source edits, no commits, no builds.

## Steps

1. **Load the task tools** (deferred — schemas must be fetched first):
   `ToolSearch("select:TaskCreate,TaskList,TaskGet,TaskUpdate")`

2. **Check `TaskList`.** If pending or in_progress tasks already exist, don't silently
   add to them — show what's there and ask whether to resume, delete
   (`TaskUpdate` → `status: deleted`), or append deliberately. Stop until answered.

3. **Compose a planning brief** from what this session already knows. The planner is a
   fresh agent — it does NOT see this conversation, so the brief must carry:
   - the goal, one sentence;
   - working directory and the files involved;
   - the project's real build/verify commands — only ones confirmed in use here,
     never guessed;
   - constraints and anything out of scope.

4. **Spawn the planner**: `Agent` with `subagent_type: "general-purpose"`,
   `model: "fable"`, prompt = the brief plus the planning rules below, verbatim.
   The task list is session-shared, so tasks it creates are the same list
   `/task-loop` will drain.

5. **Relay the result**: id, subject, one-line verification for each task, then:
   `build-loop: <n> tasks. Gate: #<last> — <check>. Run: /loop /task-loop`
   If the planner came back with a question instead of tasks, put that question to
   the user and stop.

## Planning rules (include verbatim in the agent prompt)

- First load the task tools: `ToolSearch("select:TaskCreate,TaskList,TaskUpdate")`.
- Create tasks in execution order — `/task-loop` picks the lowest-ID unblocked
  pending task, so ID order is execution order. Add `addBlockedBy` only for real
  dependencies.
- Each task is one slice of work, completable in a single turn, with a description
  that stands alone: what to do, the exact verification command (only commands the
  brief confirms exist), an observable done-when, and what must NOT be touched
  where scope creep is a risk.
- The last task is an end-to-end gate — the check you'd use to call the whole goal
  done (full suite, smoke test). A finite list with a real final check is what makes
  the loop provably terminate.
- Nothing speculative. If the brief is ambiguous, create no tasks — return the
  question as your final output instead.
- Final output: a numbered summary — id, subject, one-line verification per task.

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

   The planner does NOT have the task tools — the task list is main-session scoped.
   So it returns task *specs* and you create them. That's the one unavoidable cost:
   the descriptions pass through your output. Keep your part mechanical.

5. **Create the tasks verbatim** from the returned JSON, in array order, one
   `TaskCreate` each, then wire any `blockedBy`. Copy `description` exactly as
   written — do not re-word, expand, or improve it. The planner read the code; you
   did not. If a verification command it cites is cheap to confirm and load-bearing,
   spot-check it first — but check, don't rewrite.

6. **Hand off**: id, subject, one-line verification for each, then
   `build-loop: <n> tasks. Gate: #<last> — <check>. Run: /loop /task-loop`
   If the planner returned a question instead of tasks, put it to the user and stop.

## Planning rules (include verbatim in the agent prompt)

You have no task-list tools. Your final output IS the task list, as JSON and nothing
else — no preamble, no commentary:

```json
[{"subject": "...", "activeForm": "...", "description": "...", "blockedBy": []}]
```

- Array order is execution order — `/task-loop` takes the lowest-ID unblocked pending
  task. Use `blockedBy` (0-based indices into this array) only for real dependencies;
  plain ordering is already implied.
- Each task is one slice of work, completable in a single turn. The `description`
  must stand alone — the executing model may have lost all conversational context by
  then. It states: what to do, the exact verification command (only commands the
  brief confirms exist — never invent one), an observable done-when, and what must
  NOT be touched where scope creep is a risk.
- Write descriptions in full. They are the deliverable; whoever relays them will copy
  them verbatim, so anything you leave implicit is lost.
- The last task is an end-to-end gate — the check you'd use to call the whole goal
  done. A finite list with a real final check is what makes the loop provably end.
- Nothing speculative. If the brief is ambiguous, return no tasks — return
  `{"question": "..."}` instead.

---
description: Plan the current goal into a finite, verifiable task list that /task-loop can drain
model: sonnet
argument-hint: [goal — omit to use what we've been working on]
---

# build-loop

Turn the goal into a **finite, ordered task list** that `/loop /task-loop` can drain
unattended, then stop.

Goal: `$ARGUMENTS` — if empty, it's whatever this session has been working toward.
Either way, state the goal back in one sentence before creating anything, so a
misreading costs one exchange rather than a whole loop.

**Plan only.** No source edits, no commits, no builds. Read-only inspection is fine.

## Steps

1. **Load the task tools** — they're deferred, so the schemas must be fetched first:
   `ToolSearch("select:TaskCreate,TaskList,TaskGet,TaskUpdate")`

2. **Check `TaskList`.** If pending or in_progress tasks already exist, don't silently
   add to them — show what's there and ask whether to resume, delete
   (`TaskUpdate` → `status: deleted`), or append deliberately. Stop until answered.

3. **Use what this session already knows.** The goal, the files, the build and test
   commands are mostly established above — don't re-explore from scratch. Only
   investigate what's genuinely still unknown. Never invent a verification command;
   use one this project actually uses.

4. **Create the tasks in ID order** with `TaskCreate` — `/task-loop` takes the
   lowest-ID unblocked pending task, so ID order *is* execution order. Add
   `addBlockedBy` only for real dependencies. Each task should be one slice of work,
   completable in a single turn, with:

   - a `description` carrying enough context to stand alone — the loop runs over many
     wake-ups and this conversation may be compacted out from under it;
   - an explicit verification command and an observable **done when**;
   - anything that must *not* be touched, where scope creep is a risk.

5. **Make the last task an end-to-end gate.** Full suite, smoke test, whatever you'd
   actually use to say "yes, that's done". This is the loop's terminating condition:
   `/task-loop` stops when the list drains, so a finite list with a real final check
   is what makes it provably end.

6. **Hand off** — print id, subject and one-line verification for each, then:
   `build-loop: <n> tasks. Gate: #<last> — <check>. Switch to Opus: /loop /task-loop`

Surface ambiguity now, not inside a task description. A vague task becomes a halted
loop at 3am. Nothing speculative — if you think extra work is warranted, say so in the
summary rather than creating a task for it.

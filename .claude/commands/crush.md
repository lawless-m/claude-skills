---
description: Crush the earliest unfinished milestone into rock issues on Gitea
argument-hint: [milestone title — omit for the earliest unfinished]
---

# crush

Break one **stone** — a Gitea milestone — into **rocks**: one issue per task, each labelled
`rock`, each in that milestone, each small enough to finish in a sitting. `/rocks` carries them.

**Plan only.** No source edits, no builds, no commits. Issues and nothing else.

Milestone: `$ARGUMENTS` if given, otherwise the earliest unfinished one.

Read the `Gitea` skill for auth (`$GITEA_TOKEN` is the `claude` account; no `Sudo`).

## Steps

1. **Identify the repo** from `git remote get-url origin`.

2. **Pick the stone.** `milestones.py` beside the Gitea skill gives the verdict:
   `PYTHONIOENCODING=utf-8 python ~/.claude/skills/Gitea/milestones.py <repo>`.
   Take the earliest **open** milestone. Stop and say so, without crushing, if:
   - it already has **open** rocks → `crush: <title> already crushed — <n> rocks open. Run /rocks`;
   - an earlier milestone is still open → that one is the work, not this;
   - there are no open milestones → `crush: no stones standing. Run /stones first`.

3. **Build the brief from the stone itself.** Its description holds the work summary, the
   acceptance criteria and a pointer to the governing document — read that document too. State the
   stone's title and criteria back in one line before planning, so a misread costs one exchange
   rather than a whole queue.

4. **Spawn the planner**: `Agent` with `subagent_type: "general-purpose"`, `model: "fable"`,
   prompt = the brief plus the rules below verbatim. The planner returns rock *specs*; you create
   the issues. Keep your part mechanical: copy each `description` exactly as written — the planner
   read the code, you did not.

5. **Create one issue per rock**, in array order:
   `POST /repos/<repo>/issues` with `{"title": ..., "body": ..., "milestone": <id>,
   "labels": [<id of `rock`>]}`. List the repo's labels first to find the id — never hardcode it;
   create the `rock` label if the repo hasn't one. The body is the description verbatim, then a
   final line `**Verify:** <command>`.

6. **Wire real dependencies only**: for each `blockedBy`, `POST /repos/<repo>/issues/<index>/dependencies`
   with `{"index": <blocking issue number>}`. Plain ordering needs no dependency — issue numbers
   already carry it.

7. **Verify the queue before handing it over.** Re-read the created rocks from the API: every one
   in the right milestone, labelled `rock`, with a `**Verify:**` line, and no dependency cycle
   (repeatedly removing unblocked rocks must empty the list). A queue that cannot drain is a loop
   that cannot end. Then:
   `crush: <n> rocks on <milestone>. Gate: #<last> — <check>. Run: /rocks`

If the planner returned a question instead of rocks, put it to the user and stop. Create nothing.

## Planning rules (include verbatim in the agent prompt)

You have no task-list tools and you create nothing. Your final output IS the rock list, as JSON and
nothing else — no preamble, no commentary:

```json
[{"subject": "...", "description": "...", "verify": "...", "blockedBy": []}]
```

- Array order is execution order. Use `blockedBy` (0-based indices into this array) only for real
  dependencies; plain ordering is already implied.
- **Make rocks small.** One coherent change with one verification, not a work package. If the
  description needs "and then", or lists numbered sub-parts, or names more than a couple of files,
  it is at least two rocks — split it. Err small: ten that each land in minutes beat three that
  each take an hour, because every closed rock is a checkpoint on the tracker, visible from
  anywhere, and a place a failure can stop cleanly.
- Each `description` must stand alone — whoever executes it may have no conversation at all behind
  them, only the issue. It states: what to do, the exact verification command (**only commands the
  brief confirms exist** — never invent one), an observable done-when, and what must NOT be touched
  where scope creep is a risk.
- `verify` is one shell command that passes or fails. No "check it looks right".
- The last rock is the **end-to-end gate**: the check you'd use to call the whole stone done,
  taken from its acceptance criteria. A finite list with a real final check is what makes the
  drain provably end.
- Nothing speculative. If the brief is ambiguous, return no rocks — return `{"question": "..."}`.

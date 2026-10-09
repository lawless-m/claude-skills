---
description: Create Gitea milestones — the stones — from a project's plan documents
argument-hint: [doc directory or glob — omit for plan/]
---

# stones

Turn a plan document set into **milestones** on the repo's Gitea tracker, one per phase, each
carrying its own acceptance criteria. A milestone is a *stone*: a standing piece of work, crushed
later into rocks by `/crush`.

**Plan only.** No issues, no source edits, no commits. Milestones and nothing else.

Documents: `$ARGUMENTS` if given, otherwise `plan/*.md` in the repository root.

Read the `Gitea` skill for auth (`$GITEA_TOKEN` is the `claude` account; no `Sudo`) and for the
rule that this is the place milestones are the unit of work.

## Steps

1. **Identify the repo** from `git remote get-url origin` — `<owner>/<name>` on
   dw.ramsden-international.com. If origin is not that server, say so and stop.

2. **Check what's there**: `GET /repos/<repo>/milestones?state=all`. Existing titles are
   **never** edited or duplicated — this command is safe to run twice. If every phase already has
   a milestone, print `stones: all <n> already standing` and stop.

3. **Read the documents** yourself before delegating — enough to know whether they contain a
   phased plan at all. If they don't, say what you found instead and stop; don't invent phases.

4. **Spawn the planner**: `Agent` with `subagent_type: "general-purpose"`, `model: "fable"`.
   It does not see this conversation, so the brief must name: the repo, the document paths, and
   that the output is milestones, not tasks. Include the rules below verbatim.

5. **Create them in order** from the returned JSON, skipping titles that already exist:
   `POST /repos/<repo>/milestones` with `{"title": ..., "description": ...}`. No due dates —
   the phases are ordered, not scheduled, and a date nobody agreed to is a rod for your own back.

6. **Report**: one line per milestone with its id, then
   `stones: <n> created, <m> already standing. Next: /crush`
   and the milestones URL. If the planner returned a question instead, put it to the user and stop.

## Planning rules (include verbatim in the agent prompt)

You write no files and create nothing. Your final output IS the milestone list, as JSON and
nothing else — no preamble, no commentary:

```json
[{"title": "Phase 0: Environment", "description": "..."}]
```

- One entry per phase **the documents actually define**, in the documents' own order, using their
  own titles. If the documents number their phases, keep the numbers.
- `description` carries three things and no more: a short summary of the work, the phase's
  **acceptance criteria verbatim** from the documents (its "Done when", however worded), and a
  pointer to the document and section that governs it. Mark a phase the documents give no criteria
  for as having none, rather than inventing one.
- Nothing speculative. No phases the documents don't contain, no "and then we could". If the
  document set has no phased plan, or its phases are too vague to state criteria for, return
  `{"question": "..."}` instead of a list.

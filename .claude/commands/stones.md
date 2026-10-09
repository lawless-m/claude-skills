---
description: Create Gitea milestones — the stones — from a project's plan documents
argument-hint: <zip or folder of plan documents> — omit to detect it
---

# stones

Turn a plan document set into **milestones** on the repo's Gitea tracker, one per phase, each
carrying its own acceptance criteria. A milestone is a *stone*: a standing piece of work, crushed
later into rocks by `/crush`.

**Plan only.** No issues, no source edits, no commits. Milestones and nothing else.

**Documents: whatever `$ARGUMENTS` names — a zip or a folder.** A plan set is identified by its
`CONTENTS.md`: these sets are generated to that agreement, so the index is always there whatever
the container is called. There is no conventional folder name either — `plan/`, `docs/`, `design/`
and the rest are all equally likely, so nothing here assumes one.

**Given a zip — the usual way they arrive — unpack it; the user shouldn't have to.** Check
`CONTENTS.md` is in the listing (`unzip -l`) and refuse any entry whose path escapes the target.
Extract into a folder beside the zip named for the zip's own top-level directory, and **say which
folder you made** in the first line of output. If that folder already exists, use it and extract
nothing, so a second run is harmless. The documents want to be on disk rather than read out of the
archive, because the milestones you are about to write cite them by path and `/crush` follows those
paths later.

**The zip is transient.** Matthew's flow is: generate the set in the chatbot as a zip, create the
repo, expand it, and point Claude at the `CONTENTS.md`. Once expanded the archive is dead weight
and a stale copy of documents that get edited afterwards. So **delete the zip** — but only one this
run extracted itself, and only once the milestones are created (step 7). Never delete a zip you did
not expand, and never one whose folder already existed.

If nothing is given, **detect, don't assume**: directories under the repository root holding a
`CONTENTS.md`, then failing that zips whose listing holds one. Exactly one candidate → use it and
name it. Several, or none → list what you found and ask. Never fall back to a guess, and never read
a folder the user didn't name without saying you did.

Unpacking a zip is the **only** change this command makes to the working tree, and it commits
nothing — the extracted documents are left for the user to commit or ignore as they see fit.

Read the `Gitea` skill for auth (`$GITEA_TOKEN` is the `claude` account; no `Sudo`) and for the
rule that this is the place milestones are the unit of work.

## Steps

1. **Identify the repo** from `git remote get-url origin` — `<owner>/<name>` on
   dw.ramsden-international.com. If origin is not that server, say so and stop.

2. **Check what's there**: `GET /repos/<repo>/milestones?state=all`. Existing titles are
   **never** edited or duplicated — this command is safe to run twice. If every phase already has
   a milestone, print `stones: all <n> already standing` and stop.

3. **Read `CONTENTS.md` first**, then the documents it points at. The index says what the set is
   and which document holds the phased build plan — use it rather than opening everything blind,
   and pass the planner the specific documents it names. Read enough yourself to know the set
   contains a phased plan at all; if it doesn't, say what you found instead and stop. Don't invent
   phases.

4. **Spawn the planner**: `Agent` with `subagent_type: "general-purpose"`, `model: "fable"`.
   It does not see this conversation, so the brief must name: the repo, the document paths, and
   that the output is milestones, not tasks. Include the rules below verbatim.

5. **Create them in order** from the returned JSON, skipping titles that already exist:
   `POST /repos/<repo>/milestones` with `{"title": ..., "description": ...}`. No due dates —
   the phases are ordered, not scheduled, and a date nobody agreed to is a rod for your own back.

6. **Delete the zip, if this run expanded one** — and only then, because the archive's only job was
   to carry the documents here, and the stones now hold the criteria on the tracker. Say that you
   deleted it. If a zip was untracked, that deletion is unrecoverable, so say that too, once. Leave
   the expanded folder: the milestones cite those documents by path and `/crush` reads them, so
   they want committing to the repo.

7. **Report**: one line per milestone with its id, then
   `stones: <n> created, <m> already standing. Next: /crush`
   and the milestones URL. If the planner returned a question instead, put it to the user and stop
   — and in that case delete nothing.

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

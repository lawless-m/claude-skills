---
name: "airlock-submission"
description: Use when a planning conversation is finished and the project should be handed over to the internal Gitea — "stage this", "send it through Airlock", "hand this over", "put this in Gitea". Covers the repo layout, the workflow labels, the manifest, and the gitea-mcp calls the Airlock connector exposes.
---

# Airlock Submission

The Airlock connector reaches a **staging** Gitea and nothing else. Write a planned project into
the org `inbox` there, mark it ready, and a scheduled puller inside the company moves it to the
internal Gitea within ten minutes, with git history, labels, milestones and issues intact. That
replaces the old route of zipping files and passing them through GitHub.

Everything below is specific to that route. The tool calls are ordinary gitea-mcp; what you cannot
infer is the org, the order, the numeric-id rule and the manifest.

## Steps, in this order

1. **Create the repo** — `create_repo` with `organization: inbox`, private, default branch
   `master`. Name in kebab-case, e.g. `boat-telemetry`. Without `organization` it is created in
   the account instead, where the puller never looks.
2. **Write the planning documents** — `create_or_update_file` (`owner`, `repo`, `message`,
   `branch_name`, then `path` + `content`). `content` is literal text, **not** base64; `files[]`
   writes several paths in one commit. Put `CONTENTS.md` at the root (what is here, where to
   start), then `README.md`, `CLAUDE.md`, and the plan under `plan/`.
3. **Create the five workflow labels** — `label_write`, method `create_repo_label`: `triage`,
   `plan`, `execute plan`, `fixed`, `fix failed`. **Keep the id each call returns.**
4. **Create the milestones** — `milestone_write`, method `create`, one per phase, **in phase
   order** so their ids ascend; the internal sweep reads phase order from the ids. Description is
   the phase summary plus its *Done when*. **Keep the id each call returns.**
5. **Raise one issue** — `issue_write`, method `create`, in the first milestone, titled for that
   phase, body from the milestone description, labelled `triage`. It takes **numeric ids, not
   names**: `labels` is an array of label ids, `milestone` is a milestone id. That is what steps 3
   and 4 kept them for.
6. **Write `AIRLOCK.json` last.** This is the hand-off — do not touch the repo afterwards, because
   an edit can race the puller.

```json
{
  "version": 1,
  "ready": true,
  "target_org": "Ramsden-International",
  "target_name": "BoatTelemetry",
  "description": "One-line description for the internal repo",
  "submitted_by": "chat",
  "submitted_at": "2026-10-11T22:30:00+01:00"
}
```

`target_name` is the internal repo name, PascalCase by convention, and must match
`^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$`. Omit `target_org` to take the default.

7. **Tell the user** it is staged and marked ready, and that it should land within ten minutes.

## Rules the puller enforces

It refuses the repo rather than fixing it, and leaves it in staging with a receipt saying why:

- No binaries, no LFS, no submodules, no CI workflow directories (`.gitea/workflows`,
  `.github/workflows`).
- No paths containing `..` and no absolute paths.
- At most 20 MB and at most 500 files.
- No secrets, credentials or internal hostnames in any document. Staging sits on the public
  internet, even if only for minutes.
- A name already taken internally is a reported collision, never a merge — pick another
  `target_name`.

## Reading the outcome

The receipts live on issue #1 of `inbox/airlock-log` — `issue_read`, method `get_comments`.

```
migrated inbox/boat-telemetry → Ramsden-International/BoatTelemetry @ 4bd526d at 2026-10-11T17:41:20Z
failed inbox/boat-telemetry: invalid — files; size
```

A failure kind is one of `invalid`, `collision`, `verify mismatch`, `error`. Nothing is deleted on
a failure: fix the staged repo, and the next cycle takes it.

## Gotchas

- A repo created with `auto_init` already has a `README.md`, so a bare create on that path fails
  with `repository file already exists`. Update it instead: `edits: [{old_string, new_string}]`,
  or `content` plus the `sha` from `get_file_contents`.
- Marking `ready` before everything is in means the puller may take a half-written project.
  `AIRLOCK.json` goes last, always.
- Authorship does not survive the crossing: internally every migrated issue and comment is
  attributed to the importing service account. `submitted_by` in the manifest is the only record
  of where it came from, which is why it stays in the repo.

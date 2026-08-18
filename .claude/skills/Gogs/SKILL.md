---
name: Gogs
description: Gitea issue tracker on dw.ramsden-international.com - the triage/plan/execute plan/fixed label workflow, plus creating, querying and commenting on issues via the REST API
---

# Gitea Issue Tracker

The server at `https://dw.ramsden-international.com/gogs` is **Gitea 1.26.2** — upgraded from
Gogs but it kept the `/gogs` URL path, the `$GOGS_*` env vars and this skill's name. Gitea API
semantics apply (the same upgrade is why remotes need `git@`, not `gogs@`).

## Issue workflow — labels drive the work

Matthew's process, in his words. The label says what stage an issue is at and whose turn it is.
A label is not a trigger — nothing polls the tracker; you act on labels when asked to look.

| label | means | next |
|---|---|---|
| `triage` | You read it and come up with a plan. | you post the plan, set `plan` |
| `plan` | Matthew reviews the plan. | he sets `execute plan` |
| `execute plan` | You execute the plan. | you set `fixed`, or `fix failed` |
| `fixed` | Executed and committed. | — |
| `fix failed` | It didn't work. | back to planning |

Two rules that carry the weight: **never write code on a `triage` issue** — the plan goes in a
comment and stops there; and **never set `execute plan` yourself** — that label is Matthew's
review, and setting it would be marking your own homework.

**Re-read the thread before posting anything.** Run the sweep, or at minimum fetch the comments,
immediately before you comment on an issue you have already commented on. Matthew answers on the
issue while you are still working, and a reply that lands mid-investigation is invisible unless you
go back and look — post without checking and you will contradict an answer you already had.

Working a `triage` issue:

1. Read the body properly — these are written fast, often dictated, so re-read for intent.
2. Investigate the real code and data before planning. **Check the issue's own premises**: the
   issue describes a symptom, and its guess at where the problem lives is often slightly off. When
   the evidence disagrees with the issue, say so in the plan rather than quietly building what was
   asked for.
3. Post the plan as a comment — what changes, in which files, what you found, and any open question
   you need answered before it can be built.
4. Relabel `triage` → `plan`.

**A plan usually has open questions in it, and answering them does not change the label.** The
issue stays on `plan` through the whole back-and-forth — you ask, Matthew answers in a comment, you
post a *revised* plan as a new comment (never edit the old one; the history is the point). `plan`
means "we are still settling the plan", whoever it is waiting on. It moves exactly once, when
Matthew is happy with it, and only he moves it.

Whose turn it is on a `plan` issue is therefore **not** in the label — it's the author of the last
comment. That only works because you post as `claude` (below), so check that before relying on it.

### Post as `claude`, not as Matthew

`$GOGS_TOKEN` is Matthew's account and he is a site admin, so **every write must carry
`-H "Sudo: claude"`** — comments, label changes, issue edits. Without it your comments are authored
`matthew.heath` and the issue history reads as him talking to himself, which also destroys the
turn-detection above. Reads don't need it.

```bash
curl -s -X POST "$GOGS_URL/api/v1/repos/$REPO/issues/1/comments" \
  -H "Content-Type: application/json" -H "Authorization: token $GOGS_TOKEN" \
  -H "Sudo: claude" -d @comment.json
```

Verify with the response's `user.login`, which should read `claude`. Authorship cannot be changed
after the fact, so get it right on the first post.

**Exception — label changes must NOT use `Sudo`.** `claude` can comment (read access is enough) but
is not a repo collaborator, so a label write as `claude` returns **403**. Send label changes as
Matthew, without the header. That costs nothing: turn detection reads comment authors, not who
moved a label. If `claude` is ever added as a collaborator, drop this exception.

### Sweeping for what's yours

`sweep.py` (next to this file) lists the open issues split into yours and Matthew's, using the
labels plus the last-comment author:

```bash
PYTHONIOENCODING=utf-8 python ~/.claude/skills/Gogs/sweep.py matthew.heath/CagesWaitrose
```

Yours are `triage` (plan it), `execute plan` (build it), `fix failed` (re-plan it), and any `plan`
issue whose last comment is Matthew's (he has answered — revise the plan). A `plan` issue whose
last comment is `claude` is with him; leave it alone.

Nothing polls this. The sweep runs when asked, or from a scheduled agent if one is ever set up.

Working an `execute plan` issue: implement it, commit referencing the issue number, comment with
what was done and the commit sha, and relabel → `fixed`. If it doesn't work — the plan turns out to
be wrong, or the fix doesn't hold — relabel → `fix failed` and comment with what went wrong rather
than quietly leaving it in `execute plan`. Leave the issue open either way; closing is Matthew's
call.

`fix failed` can also come back the other way: an issue you marked `fixed` gets relabelled when it
fails in real use. Treat that like a fresh `triage` — re-investigate given what the failure now
tells you, post a revised plan, and set it back to `plan` for review.

Label ids are per-repo, so **list them first, never hardcode**. On `matthew.heath/CagesWaitrose`
they are triage=1, plan=2, fixed=3, execute plan=4, fix failed=5.

## Instructions

1. **Authentication**: Use the `$GOGS_TOKEN` environment variable (set in Claude settings.json). Pass it as `Authorization: token $GOGS_TOKEN` header.
2. **Base URL**: Use `$GOGS_URL/api/v1` (defaults to `https://dw.ramsden-international.com/gogs/api/v1`).
3. **Default repo**: Prefer the repo matching the working directory; otherwise `Gavin.Thompson/RI-REPO`.
4. **Issue formatting**: Use markdown in issue bodies. Structure with `## Problem`, `## Proposed change`, `## Impact` sections where appropriate.
5. **Don't guess issue or label numbers**: list them first.
6. **Long bodies go in a file**: `-d @body.json`. Inline quoting of a multi-paragraph markdown body through the shell is where these calls usually break.
7. **Piping JSON into python**: set `PYTHONIOENCODING=utf-8`, or box-drawing characters and curly quotes in issue bodies blow up on Windows cp1252.

## Examples

### Example 1: List open issues with their labels
```bash
curl -s "$GOGS_URL/api/v1/repos/matthew.heath/CagesWaitrose/issues?state=open" \
  -H "Authorization: token $GOGS_TOKEN" | PYTHONIOENCODING=utf-8 python -c "
import json,sys
for i in json.load(sys.stdin):
    print('#%s [%s] %s' % (i['number'], ','.join(l['name'] for l in i.get('labels') or []), i['title']))
"
```

### Example 2: Post a plan, then move triage → plan
```bash
# 1. the plan comment (body in a file — it will be long)
curl -s -X POST "$GOGS_URL/api/v1/repos/matthew.heath/CagesWaitrose/issues/1/comments" \
  -H "Content-Type: application/json" -H "Authorization: token $GOGS_TOKEN" \
  -d @plan.json

# 2. PUT replaces the whole label set, so pass the full desired set
curl -s -X PUT "$GOGS_URL/api/v1/repos/matthew.heath/CagesWaitrose/issues/1/labels" \
  -H "Content-Type: application/json" -H "Authorization: token $GOGS_TOKEN" \
  -d '{"labels":[2]}'
```

### Example 3: Create an issue
```bash
curl -s -X POST "$GOGS_URL/api/v1/repos/Gavin.Thompson/RI-REPO/issues" \
  -H "Content-Type: application/json" -H "Authorization: token $GOGS_TOKEN" \
  -d '{"title": "Fix broken login page", "body": "## Problem\n\n...", "labels": [1]}'
```

### Example 4: Close an issue
```bash
curl -s -X PATCH "$GOGS_URL/api/v1/repos/Gavin.Thompson/RI-REPO/issues/5" \
  -H "Content-Type: application/json" -H "Authorization: token $GOGS_TOKEN" \
  -d '{"state": "closed"}'
```

### Example 5: Add a comment
```bash
curl -s -X POST "$GOGS_URL/api/v1/repos/Gavin.Thompson/RI-REPO/issues/3/comments" \
  -H "Content-Type: application/json" -H "Authorization: token $GOGS_TOKEN" \
  -d '{"body": "Fix deployed to production."}'
```

---

# API Reference

## Authentication

Token is available as the `$GOGS_TOKEN` environment variable, configured in `~/.claude/settings.json` under `env`. The base URL is `$GOGS_URL`.

In curl commands, reference them directly: `$GOGS_TOKEN` and `$GOGS_URL`.

## Common Endpoints

| Action | Method | Endpoint |
|--------|--------|----------|
| Server version | GET | `/version` |
| List issues | GET | `/repos/:owner/:repo/issues?state=open` |
| Get one issue | GET | `/repos/:owner/:repo/issues/:index` |
| Create issue | POST | `/repos/:owner/:repo/issues` |
| Edit issue | PATCH | `/repos/:owner/:repo/issues/:index` |
| Close issue | PATCH | `/repos/:owner/:repo/issues/:index` with `{"state":"closed"}` |
| Add comment | POST | `/repos/:owner/:repo/issues/:index/comments` |
| List comments | GET | `/repos/:owner/:repo/issues/:index/comments` |
| **Replace an issue's labels** | PUT | `/repos/:owner/:repo/issues/:index/labels` with `{"labels":[id,…]}` |
| Add labels, keeping existing | POST | `/repos/:owner/:repo/issues/:index/labels` with `{"labels":[id,…]}` |
| Remove one label | DELETE | `/repos/:owner/:repo/issues/:index/labels/:id` |
| List repo labels | GET | `/repos/:owner/:repo/labels` |
| Create label | POST | `/repos/:owner/:repo/labels` |
| List repos | GET | `/user/repos` |
| Get repo | GET | `/repos/:owner/:repo` |

`:index` is the **issue number** shown in the UI (`#2`), not the `id` field in the JSON — they
differ (issue `#2` came back with `"id": 17`).

## Pull requests

The old Gogs build 404'd on `/pulls`; **Gitea 1.26 serves it** — `GET /repos/:owner/:repo/pulls`
returns 200. Creating one via `POST /pulls` has not been exercised here, so if it fails, fall back
to pushing the branch and handing over the compare URL:
`$GOGS_URL/<owner>/<repo>/compare/master...<branch>`.

## Create Issue Body

```json
{
  "title": "Short title",
  "body": "Markdown body with ## sections",
  "labels": [1, 2],
  "assignee": "username"
}
```

Labels and assignee are optional. Label values are numeric ids (list them first to find ids).

---
name: Gogs
description: Create and manage issues, query repos, and interact with the Gogs API on dw.ramsden-international.com
---

# Gogs Issue Tracker

Interact with the Gogs instance at `https://dw.ramsden-international.com/gogs` via its REST API.

## Instructions

1. **Authentication**: Use the `$GOGS_TOKEN` environment variable (set in Claude settings.json). Pass it as `Authorization: token $GOGS_TOKEN` header.
2. **Base URL**: Use `$GOGS_URL/api/v1` (defaults to `https://dw.ramsden-international.com/gogs/api/v1`).
3. **Default repo**: Unless the user specifies otherwise, use `Gavin.Thompson/RI-REPO`.
4. **Issue formatting**: Use markdown in issue bodies. Structure with `## Problem`, `## Proposed change`, `## Impact` sections where appropriate.
5. **Don't guess issue numbers**: If you need to reference an existing issue, list them first.

## Examples

### Example 1: Create an issue
```
User: Create a Gogs issue about the broken login page

Claude: Reads token from config.toml, then:

curl -s -X POST "https://dw.ramsden-international.com/gogs/api/v1/repos/Gavin.Thompson/RI-REPO/issues" \
  -H "Content-Type: application/json" \
  -H "Authorization: token <token>" \
  -d '{"title": "Fix broken login page", "body": "## Problem\n\n..."}'
```

### Example 2: List open issues
```
User: What issues are open on the repo?

Claude:

curl -s "https://dw.ramsden-international.com/gogs/api/v1/repos/Gavin.Thompson/RI-REPO/issues?state=open" \
  -H "Authorization: token <token>"
```

### Example 3: Close an issue
```
User: Close issue #5

Claude:

curl -s -X PATCH "https://dw.ramsden-international.com/gogs/api/v1/repos/Gavin.Thompson/RI-REPO/issues/5" \
  -H "Content-Type: application/json" \
  -H "Authorization: token <token>" \
  -d '{"state": "closed"}'
```

### Example 4: Add a comment to an issue
```
User: Comment on issue #3 that the fix is deployed

Claude:

curl -s -X POST "https://dw.ramsden-international.com/gogs/api/v1/repos/Gavin.Thompson/RI-REPO/issues/3/comments" \
  -H "Content-Type: application/json" \
  -H "Authorization: token <token>" \
  -d '{"body": "Fix deployed to production."}'
```

### Example 5: Create an issue on a different repo
```
User: Create an issue on matthew.heath/other-repo about ...

Claude: Same pattern but with the specified owner/repo path:

curl -s -X POST "https://dw.ramsden-international.com/gogs/api/v1/repos/matthew.heath/other-repo/issues" \
  ...
```

---

# API Reference

## Authentication

Token is available as the `$GOGS_TOKEN` environment variable, configured in `~/.claude/settings.json` under `env`. The base URL is `$GOGS_URL`.

In curl commands, reference them directly: `$GOGS_TOKEN` and `$GOGS_URL`.

## Common Endpoints

| Action | Method | Endpoint |
|--------|--------|----------|
| List issues | GET | `/repos/:owner/:repo/issues?state=open` |
| Create issue | POST | `/repos/:owner/:repo/issues` |
| Edit issue | PATCH | `/repos/:owner/:repo/issues/:id` |
| Close issue | PATCH | `/repos/:owner/:repo/issues/:id` with `{"state":"closed"}` |
| Add comment | POST | `/repos/:owner/:repo/issues/:id/comments` |
| List comments | GET | `/repos/:owner/:repo/issues/:id/comments` |
| List repos | GET | `/user/repos` |
| Get repo | GET | `/repos/:owner/:repo` |
| List labels | GET | `/repos/:owner/:repo/labels` |
| Create label | POST | `/repos/:owner/:repo/labels` |

## Create Issue Body

```json
{
  "title": "Short title",
  "body": "Markdown body with ## sections",
  "labels": [1, 2],
  "assignee": "username"
}
```

Labels and assignee are optional. Label values are numeric IDs (list them first to find IDs).

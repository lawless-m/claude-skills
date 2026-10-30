---
name: Blog Management
description: Use when creating, editing, publishing, or deleting posts on Cyril's Workshop blog or the steponnopets.net devblog.
---

# Blog Management

Two blogs on steponnopets.net share one API shape and one key:

- DevBlog: `https://steponnopets.net/devblog/api`
- Cyril's Workshop (main blog): `https://steponnopets.net/cyril/api`

**API key**: `~/.claude/cyril-api-key` (single line, no trailing newline; same key for both blogs). Send as header on all write operations:

```bash
-H "X-Cyril-Key: $(cat ~/.claude/cyril-api-key)"
```

GET of published posts needs no auth; `GET .../api/posts?include_drafts=true` does.

## Endpoints (same structure on both blogs)

| Operation | Method + path |
|-----------|---------------|
| List posts | `GET /devblog/api/posts` (add `?include_drafts=true` with auth) |
| Single post | `GET /devblog/api/post?slug=<slug>` |
| Create | `POST /devblog/api/posts` |
| Update | `PATCH /devblog/api/post?slug=<slug>` |
| Delete | `DELETE /devblog/api/post?slug=<slug>` (permanent, no undo) |

## Environment facts and gotchas

- **Slug is immutable**: auto-generated from the title at creation (lowercase, hyphens) and cannot be changed afterwards — it is the post identifier. Changing `title` leaves the slug alone.
- **Drafts** are posts with `published_at = null`. `"publish": false` on create saves a draft; PATCH `"publish": true/false` publishes/unpublishes.
- **Project tags**: for posts about a GitHub repo, the FIRST tag MUST be `® ProjectName`. This auto-creates/updates the entry on the Projects page (description taken from the post's first paragraph, link from the `repo` field).
- **PATCH is partial**: send only the fields that changed. `tags` replaces the whole array, so include existing tags plus new ones.
- Use `--data-binary @file.json` rather than inline `-d` JSON to avoid shell escaping problems (especially on Windows).
- Admin panel (view drafts, edit, publish, delete, manage projects): `https://steponnopets.net/devblog/#/admin` — requires the API key.
- Backing stores are SQLite: `/var/www/data/devblog.db` and `/var/www/data/cyril.db` (check vsprod logs on 500 errors).

## Workflow

GET the post first, PATCH only what changed, then report the post URL (`https://steponnopets.net/devblog/#/post/<slug>`) so the user can verify.

Full field tables, curl/PowerShell patterns, response formats, and the DB schema are in `reference-api.md`.

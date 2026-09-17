# Blog API Reference

Detail for the steponnopets.net blog API (DevBlog `/devblog/api`, Cyril `/cyril/api` — identical structure).

## Post object

```json
{
  "slug": "post-title",
  "title": "Post Title",
  "content": "# Markdown content...",
  "tags": ["rust", "web"],
  "repo": "https://github.com/user/repo",
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z",
  "published_at": "2025-01-15T10:30:00Z"
}
```

`published_at` is `null` for drafts. Tags are a JSON array.

## PATCH fields (all optional — send only what changes)

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Update post title (slug stays the same) |
| `content` | string | Replace full markdown content |
| `tags` | array | Replaces ALL tags (`["tag1", "tag2"]`) |
| `publish` | boolean | `true` to publish, `false` to unpublish |

```bash
curl -X PATCH "https://steponnopets.net/devblog/api/post?slug=my-post" \
  -H "Content-Type: application/json" \
  -H "X-Cyril-Key: $(cat ~/.claude/cyril-api-key)" \
  -d '{"title": "New Title", "tags": ["rust", "svelte"], "publish": true}'
```

Returns the updated post on success.

## Create (file-based to avoid JSON escaping)

```bash
cat > /tmp/post.json << 'EOF'
{
  "title": "Post Title",
  "content": "# Markdown content here...",
  "repo": "https://github.com/user/repo",
  "tags": ["® RepoName", "rust", "web"],
  "publish": true
}
EOF

curl -X POST https://steponnopets.net/cyril/api/posts \
  -H "Content-Type: application/json" \
  -H "X-Cyril-Key: $(cat ~/.claude/cyril-api-key)" \
  --data-binary @/tmp/post.json

rm /tmp/post.json
```

Response: `{"slug": "post-title", "url": "https://steponnopets.net/cyril/#/post/post-title"}`

Windows: use the Write tool to create `post.json`, then:

```powershell
curl -X POST https://steponnopets.net/cyril/api/posts `
  -H "Content-Type: application/json" `
  -H "X-Cyril-Key: <api-key>" `
  --data-binary @post.json
```

## Delete

```bash
curl -X DELETE "https://steponnopets.net/devblog/api/post?slug=my-post-slug" \
  -H "X-Cyril-Key: $(cat ~/.claude/cyril-api-key)"
```

Permanent — no undo.

## Project tags

A first tag of `® ProjectName` auto-creates/updates a project entry:
- **Name**: from the tag (minus `® `)
- **Description**: first paragraph of the post content
- **URL**: the post's `repo` field

Clicking the project tag on the site shows all posts for that project.

## Database schema

SQLite at `/var/www/data/devblog.db` and `/var/www/data/cyril.db`:

```sql
CREATE TABLE posts (
  slug TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  tags TEXT,  -- JSON array: ["tag1", "tag2"]
  repo TEXT,
  created_at TEXT,
  updated_at TEXT,
  published_at TEXT  -- NULL for drafts
)
```

## Errors

| Status | Meaning | Action |
|--------|---------|--------|
| 404 | Post not found | Verify slug |
| 401 | Invalid API key | Check `~/.claude/cyril-api-key` contents |
| 400 | Invalid JSON | Verify request body syntax |
| 500 | Server error | Check vsprod logs |

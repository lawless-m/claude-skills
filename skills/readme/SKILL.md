---
name: readme
description: Use when writing or reworking a project's README so the gitea-px catalogue ("Gitea Projects", the list_projects tool) finds it, when the user says "/readme", "make the README index well" or "write a README for this repo", or when tools/readme-coverage.ps1 in GiteaPx flags a repo too-short or no-readme.
---

# A README the catalogue can find

The catalogue (GiteaPx, D15; rule in `C:/Sprout/GiteaPx/src/GiteaPx.Catalogue/Readmes/ReadmeReader.cs`):

- **Which file:** the top-level README on the **default branch's HEAD**, case-insensitive, preferring `README.md`, then `README.markdown`, then `README`, then any `README.<ext>`. A README in a subfolder or on another branch is invisible.
- **Too short:** under **300 bytes** and the repo is left out entirely.
- **What Claude sees first:** each repo's Gitea **description**, last update, and the **first 500 characters of the README's raw text**. Claude reads all the entries (about 120) and matches them on meaning. It fetches a whole README with `get_readme` (capped at 1 MB) only for repos that already look like a match.

So **the first 500 characters decide whether the repo is ever found.** Markdown syntax counts against them.

## The opening

- `# Name`, then a plain sentence or two: what it does, in the words someone would ask with ("serves product thumbnails from S3 by EAN", not "X is a solution for...").
- Name what it talks to: Exportmaster/DBISAM, X3, x3rocs, S3 and the bucket, SharePoint, Gitea, Elasticsearch, a CGI it calls. Also say where it runs (host, and whether it's a CGI, service or scheduled task). These are the nouns questions arrive with.
- Nothing ahead of that: no badges, images, HTML comments, front matter, table of contents, or long link URLs. A 150-character shields.io line costs a third of the excerpt.
- If a repo is a copy of, or the successor to, another one, say so in the opening. Claude can then tell which of the copies is current.

The rest is a normal README: build, run, settings (names, and where any secret comes from, never its value), deploy, status. Write it from the code, config and commits, not from a guess at the name.

## Also set the Gitea description

The description sits beside the excerpt and is often empty. Once the README is pushed, give it one line saying what the repo does, usually the README's opening sentence cut down:

```
pwsh -NoProfile -File ~/.claude/skills/readme/Set-GiteaDescription.ps1 <owner>/<repo> "<one line>"
```

The script is in this skill's folder. It uses the owner's `GITEA_ACCESS_TOKEN` (never printed), changes only the description, and prints the old and new values. Show the user the line before setting it, because it replaces whatever is there. Neither MCP can do this: gitea-mcp has no repo-settings tool, and gitea-px is read-only by design.

## Check

- **Preview what Claude will see:** `$t = Get-Content README.md -Raw; $t.Substring(0, [Math]::Min(500, $t.Length))`. Read it as if it were the only thing you knew about the repo.
- **Size:** at least 300 bytes.
- **Secrets:** none copied from the code (connection strings, passwords, tokens). Describe them instead.
- **After the push:** in `C:/Sprout/GiteaPx`, `pwsh -NoProfile -File tools/readme-coverage.ps1 -Expect <owner>/<repo>` should report `ok`, and the gitea-px `get_readme` tool should return the new text. The service re-reads a repo as soon as its HEAD moves.

The catalogue reads only the default branch, so a README committed elsewhere doesn't count until it's merged. Commit and push only when asked, per CLAUDE.md.

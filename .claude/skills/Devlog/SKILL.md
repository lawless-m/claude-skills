---
name: Devlog
description: Use when asked "how did we build X", "when did we decide Y", "what did I ask Claude about Z", or to find, read or link a past Claude Code session from any RI host — queries the central devlog (Devolver) archive over HTTP.
---

# Devlog

Every Claude Code session on RI hosts is pushed (PreCompact / SessionEnd hooks) to the devlog
receiver on RIVSPROD01, which stores one JSON transcript per session. Source: Gitea
`Ramsden-International/Devolver`.

Base URL: `https://dw.ramsden-international.com/devolver` — no auth, plain `curl` + `jq`.

## Endpoints

| GET | Params | Returns |
|---|---|---|
| `/api/search` | `q` (required), `scope`, `days`, `project`, `machine`, `sort=relevance`, `limit` (default 50) | `[{machine, project, session_id, timestamp, entry_type, snippet}]`, newest first unless `sort=relevance` |
| `/api/session` | `machine`, `project`, `session` (full session_id) | the stored transcript (below) |
| `/api/sessions` | `days` (default 30) | `[{machine, project, project_dir, session_id, last_activity, title}]` |

`scope`: `prompts` (user turns only), `conversations` (default — user + assistant), `all`
(also tool summaries, i.e. files edited / commands run).

Transcript: `{session_id, machine_id, project_dir, timestamp, git:{remote,branch,commit},
conversation:[...]}`. Entries are `{type:"user"|"assistant", content, timestamp}` or
`{type:"tool_summary", actions:[...]}`. Transcripts can be large — pull what you need with jq,
e.g. `jq -r '.conversation[] | select(.type=="user") | .content'`.

## Gotchas

- **Search is full-text on whole words** (SQLite FTS5), case-insensitive. Every word must appear in
  the same entry, any order; `"pull and deploy"` is an exact phrase; `deploy*` is a prefix.
  Punctuation is a word break, so `github-lawless` = the phrase "github lawless". No substring
  matching: `deploy` won't find "deployment" — use `deploy*`.
- Hits are individual entries, so one session can fill many slots — filter by `project`/`days`
  or use `sort=relevance` when a common term floods the results. `project`/`machine` filters
  are case-insensitive exact names.
- `project` is the last path component of the session's working dir (`C:\Sprout\Devolver` →
  `Devolver`), so same-named folders on different hosts share a project name; `machine` tells
  them apart. Case varies by host (`RIVMIS01`, `RIVSPROD01`, `beast`) — copy it from a search
  hit, don't type it.
- `session_id: "test-session"` entries are test pushes ("Can you add JWT authentication…") —
  ignore them.

## Linking a human to a session

`https://dw.ramsden-international.com/devolver/session?machine=M&project=P&session=ID&view=prompts`
(`view` = `prompts` | `replies` (default) | `all`). Browsable search: `/devolver/search`.

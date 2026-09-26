---
name: boofuzz
description: Use when writing or contributing a boofuzz network-protocol fuzzer in this repo — layout, formatting rules, and reading results.
---

# boofuzz fuzzers

Conventions for authoring fuzzers in this boofuzz project. General boofuzz API usage (Request/Block/primitives, Session setup, callbacks) is standard — see the boofuzz docs.

## Repo layout

| Directory | Contents |
|-----------|----------|
| `/examples/` | Complete runnable fuzzers with a CLI (`argparse`, a `main()`). New standalone fuzzers go here. |
| `/request_definitions/` | Reusable protocol PDU definitions only — importable modules, **no `main()`**. |

Put a fuzzer's protocol structure in `/request_definitions/` when it's worth reusing, and the runnable driver in `/examples/`.

## Formatting

Format with **Black** before committing; run the full checks with **tox**:
```bash
black your_fuzzer.py
tox
```
Use `# fmt: off` / `# fmt: on` **sparingly** — only to preserve hand-aligned protocol byte layouts that Black would reflow.

## Results

Runs land in `./boofuzz-results/*.db` (SQLite). Inspect via the web UI:
```bash
boo open boofuzz-results/run-YYYY-MM-DD_HH-MM-SS.db
```
Or query directly, e.g. failing/crashing cases:
```sql
SELECT name, type, timestamp FROM cases
WHERE type LIKE '%fail%' OR type LIKE '%crash%';
```

## Disclosure

For vulnerability disclosure templates and PoC extraction from a crash, see `references/disclosure.md`.

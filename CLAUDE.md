# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## Preferred CLI Tools

Our dev hosts have modern CLI tools installed — prefer them in shell commands. (If one is missing on this host, say so; install via cargo-binstall / dotnet tool / apt as appropriate.)

**Search & files**
- `rg` (ripgrep) over `grep` for searching file contents
- `fd` over `find` for locating files
- `ast-grep` (alias `sg`) for structural code search and codemod-style rewrites — when matching syntax, not text (e.g. "find all calls to X with a literal second arg", rename an API across a codebase)
- `difft` (difftastic) when a syntax-aware diff would be clearer than line-based diff (e.g. `GIT_EXTERNAL_DIFF=difft git diff`)

**Rust**
- `cargo nextest run` over `cargo test` — faster, cleaner failure output
- `cargo machete` — find unused dependencies
- `cargo audit` — RustSec advisory scan
- `cargo expand` — see macro-expanded code when debugging macros

**C#** (`~/.dotnet/tools`)
- `csharpier` — deterministic formatter
- `dotnet-outdated` — report stale NuGet package pins

**Python**
- `uv` — the standard Python driver (same as on beast): `uv run` for scripts with inline deps, `uvx` for one-off tools; avoid raw pip/venv

**General**
- `watchexec` — rerun a command on file change (e.g. `watchexec -e rs 'cargo nextest run'`)
- `shellcheck` — lint shell scripts before shipping them
- `hyperfine` — benchmark commands properly instead of eyeballing `time`
- `yq` — jq for YAML (mikefarah v4 syntax)
- `jq`, `parallel`, `tokei`, `gh`, `sqlite3` — also available

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

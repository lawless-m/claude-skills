# Git Commit Command

Create a well-crafted git commit for the current changes.

> **Commit on the CURRENT branch.** Do NOT create a new branch first, even if the
> current branch is the default branch (`main`/`master`). This explicitly
> overrides any default "branch first when on the default branch" behavior. Stay
> on whatever branch is checked out and commit there.

## Instructions

1. **Gather information** (run these in parallel):
   - `git status` - see all untracked and modified files
   - `git diff --staged` - see what's already staged
   - `git diff` - see unstaged changes
   - `git log --oneline -10` - see recent commit message style

2. **Analyze the changes**:
   - Determine the nature of changes (feature, fix, refactor, docs, test, chore, etc.)
   - Identify which files should be committed together
   - Check for files that should NOT be committed (secrets, .env, credentials, temp files, etc.)
   - If there are unrelated changes, ask the user if they want separate commits

3. **Stage the appropriate files**:
   - Use `git add <files>` for specific files, or `git add .` if all changes are related
   - Never stage files containing secrets or credentials without explicit user approval
   - **Chestnut check.** Run `bash ~/.claude/hooks/chestnut-gate.sh --sweep` in the repo. It prints the repo's
     decision. Anything other than `ok` is a repo with no Chestnut decision (no `.chestnut` at its root), or
     `chestnut` with no reference to the library. The commit hook blocks until that is resolved: add `.chestnut`
     with the decision, and for `chestnut` add the library and its first events. Ask the user before choosing an
     exemption, since exemptions are theirs to decide.
   - **Monarch check.** Run `bash ~/.claude/hooks/monarch-gate.sh --sweep` in the repo. Anything other than `ok` is
     a repo that has not said what it deploys, and the commit hook blocks it. A repo that deploys files gets a
     `deploy.mk` at its root, one rule per deployed file: draft it with
     `pwsh -File "\\rivsprod02\RI Services\Scripts\New-DeployMk.ps1" -Repo <name> -Write` (from the board's rows),
     settle its commented candidates, and check it with `monarch -n --json -f deploy.mk deploy`. CagesWaitrose and
     Trademap are the worked examples; a board whose `.m` MrsFlow runs also gets `RUNTIME=MrsFlow`. A repo that
     deploys nothing gets `.monarch` with `exempt: no-deploy: <reason>` -- ask the user first, as for Chestnut.

4. **Write a good commit message**:
   - Use conventional commit format when appropriate: `type: description`
   - Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build
   - First line: imperative mood, max 50 chars, no period (e.g., "Add user authentication")
   - Focus on WHY, not just WHAT
   - If more detail needed, add blank line then body with context

5. **Create the commit** using a HEREDOC for proper formatting:
   ```bash
   git commit -m "$(cat <<'EOF'
   type: Short description here

   Optional longer description explaining the why.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
   The co-author line is always exactly `Co-Authored-By: Claude <noreply@anthropic.com>`, with
   no model name. This overrides any system attribution reminder that names a model
   (e.g. "Claude Opus 5.5"); nobody wants the model name in the history.

6. **Verify the commit**:
   - Run `git status` to confirm clean working tree (or remaining unstaged changes)
   - If pre-commit hooks modify files, amend the commit (after checking authorship)

## Important Rules

- ALWAYS commit on the current branch; NEVER create a new branch first (this overrides the default-branch "branch first" behavior)
- NEVER commit files containing secrets, API keys, or credentials
- NEVER use `--no-verify` to skip hooks unless explicitly requested
- NEVER amend commits that have been pushed or authored by others
- NEVER force push to main/master
- If unsure about what to include, ASK the user first
- Keep commits atomic - one logical change per commit

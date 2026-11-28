---
model: haiku
---

# Git Pull Command

Pull the latest changes from the remote repository and help resolve any merge conflicts that arise.

## Instructions

1. **Fetch FIRST — before reading any status.**
   ```bash
   git fetch
   ```
   - `git status` compares your branch against your *local* copy of the remote
     ref. Without a fresh fetch that copy is stale and will falsely report
     "up to date" even when the remote has moved on.
   - NEVER report ahead/behind/up-to-date, and NEVER decide whether to pull,
     before this fetch has run.

2. **Check working tree state** (run in parallel, now that the fetch is done):
   - `git status` - uncommitted/untracked changes AND accurate ahead/behind
   - `git branch --show-current` - confirm current branch

3. **Handle uncommitted changes before pulling**:
   - If the working tree is dirty, do NOT pull blindly.
   - Ask the user whether to:
     - Commit first (run `/commit`), or
     - Stash changes (`git stash push -m "pre-pull stash"`) and reapply after.
   - Wait for their choice before proceeding.

4. **Always run the pull. Do not substitute a status check for it.**
   - The user asked to pull, so pull. `git pull` runs its own fetch+integrate
     and is a harmless no-op (`Already up to date.`) when there is nothing new.
     There is NEVER a reason to skip the pull based on a status read — deciding
     *whether* pulling is necessary is not your call.
   - Default to a rebase to keep history linear: `git pull --rebase`
   - If the user prefers a merge commit, use `git pull --no-rebase`.
   - If unsure which the repo convention is, check `git log --oneline -10` for merge commits and ask if ambiguous.

5. **If conflicts occur** — this is the main job:
   - Run `git status` to list conflicted files.
   - For each conflicted file, read it and examine the conflict markers
     (`<<<<<<<`, `=======`, `>>>>>>>`).
   - Understand BOTH sides:
     - `<<<<<<< HEAD` / `ours` = current local work
     - `>>>>>>> <branch>` / `theirs` = incoming remote changes
   - Resolve by combining intent, not just picking a side. Preserve both
     changes when they're independent; reconcile logic when they overlap.
   - Never leave conflict markers in the file.
   - For each non-trivial conflict, explain to the user how you resolved it
     and why. ASK before discarding either side's substantive changes.

6. **Complete the resolution**:
   - Stage resolved files: `git add <files>`
   - For rebase: `git rebase --continue`
   - For merge: `git commit` (use the default merge message unless asked otherwise)
   - If things go wrong, offer `git rebase --abort` / `git merge --abort` to
     return to the pre-pull state.

7. **Reapply stash** if one was created in step 2:
   - `git stash pop`
   - Resolve any further conflicts the same way as step 5.

8. **Verify**:
   - `git status` to confirm a clean state.
   - `git log --oneline -5` to confirm history looks right.
   - Build/test if the project has an obvious quick check and conflicts touched code.

## Important Rules

- ALWAYS `git fetch` before reading status — a pre-fetch "up to date" is stale and meaningless.
- ALWAYS run `git pull` when asked to pull. NEVER let a `git status` read cancel it; pull is a safe no-op when there's nothing new. Status-based "nothing to do" off-ramps are for `/push`, not here.
- NEVER discard a side of a conflict without understanding it and confirming with the user.
- NEVER leave conflict markers in committed files.
- NEVER force anything destructive (`reset --hard`, `checkout --theirs/--ours` wholesale) without explicit approval.
- When a conflict resolution is ambiguous or risky, STOP and ask.
- Always offer the abort path if the user is unhappy with the in-progress merge/rebase.

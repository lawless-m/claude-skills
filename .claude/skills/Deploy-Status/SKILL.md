---
name: Deploy-Status
description: Use when a deploy drift status comes up — STALE-COMMIT, NEEDS-DEPLOY, UNKNOWN-COMMIT, DEPLOY-AHEAD, UNTRACEABLE, STALE-DEP, UNCHECKED, NO-BUILD, UNPUSHED — or when asked "is this deployed", "why is X flagged on the deploy board", or to check a project's deploy state before or after a deploy.
---

# Deploy status — what the board says about your project, and why

The deploy board (https://dw.ramsden-international.com/tiny02/pibs/deploy.html) judges every
deployed artefact against **Gitea's default branch**. It is produced every five minutes on
RIVSPROD01 by `DeployDrift.ps1` in `Ramsden-International/Deployment`.

You usually cannot read that script, the share or the producer's logs from a project session —
and you don't need to. **Everything the board knows is published as JSON over HTTPS**, including
what each status means and what to do about it:

```bash
curl -s https://dw.ramsden-international.com/tiny02/pibs/deploy_status.json
```

Shape:

```
generated_at   when the producer ran (local time; older than ~10 min means it has stalled)
statuses       { STATUS: { means, do } } — the authoritative meaning of every status
rows[]         project, repo_url, assembly, kind, status, note, live_sha, commit_sha,
               deploy_date, publish_dir, machine
```

## Workflow

1. Fetch the JSON and filter to your project (the `project` field is the Gitea repo name):

   ```bash
   curl -s https://dw.ramsden-international.com/tiny02/pibs/deploy_status.json |
     jq '{generated_at, rows: [.rows[] | select(.project == "WHTransfer")]}'
   ```

2. Read `statuses[<status>]` for the row — `means` and `do`. Don't work from memory of what a
   status meant; the rules change, and the JSON is current.
3. Investigate in **your own repo** with the row's facts:
   - `live_sha` is what is actually running (from the exe's commit stamp, or for web content the
     commit whose version of the file is deployed).
   - `note` says how far behind, or what was matched.
   - For `STALE-COMMIT`: `git fetch && git log --stat <live_sha>..origin/<default> -- <project dir>`
     shows the commits counted. Then decide whether they change what is in the artefact.
4. Act on the answer:
   - **The commits change the artefact** → rebuild and deploy (the project's `deploy.ps1`, or `/deploy`).
   - **They cannot change it** (e.g. a file type the rule should have ignored) → the rule is too
     broad. Say so, naming the commit and the file, rather than redeploying to silence the board.
     The exclusions live in `scripts/DriftRules.ps1` (`$script:DocPaths`, `Get-ProjectExcludes`)
     in the Deployment repo.
   - **`UNKNOWN-COMMIT`** → `git cat-file -t <live_sha>` locally. If you have it, it was never
     pushed (or was amended after deploying): push it, or rebuild and deploy from a pushed commit.
   - **`DEPLOY-AHEAD`** on web content → the deployed file matches nothing ever committed. Diff
     it against the repo file named in the note; commit the live version if it is the right one.

## Gotchas

- **Only pushed commits exist** as far as the board is concerned. A local commit you have not
  pushed makes your deploy read `UNKNOWN-COMMIT`. Push before you deploy.
- **The board lags up to five minutes** after a deploy. Check `generated_at` before concluding
  a deploy did not fix a status.
- **`UNCHECKED` is not a pass.** It means the exe carries no commit stamp, so nothing could be
  checked. The fix is to stamp the build, not to ignore the row.
- Deploying from a dirty tree stamps `-dirty` and reads `UNTRACEABLE` until a clean redeploy.

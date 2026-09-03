# /deploy - Deploy a .NET CGI or scheduled-task service

Deploy a built .NET exe (CGI under `cgi-bin`, or a scheduled-task exe run from
its `PublishDir`) safely, so the deploy is verified rather than assumed.

**Why this exists**: Translation ran a Feb 5 binary for five months after its
fix was committed — `dotnet publish` was run, but the built exe was never
copied to `cgi-bin`. No error, no log line, no alert; the app just quietly got
slower every day. See the `Deployment` repo (`~/Git/Deployment`,
`notes/01-the-problem.md`) for the full post-mortem this procedure is drawn
from. `DeployDrift.ps1` in that repo (deployed at `R:\Scripts\DeployDrift.ps1`)
is the read-only detector for this failure mode; this command is the
procedure for deploying without causing it.

**Scope**: the .NET CGI / scheduled-task path only — a `dotnet publish` build
copied (by hand or already in place) into `cgi-bin` or run from a share.
Windows services, the Rust boards (`mrsflow-cgi`, `pintail-cgi`), and anything
else deployed by hand are **out of scope**. If asked to deploy one of those,
say so rather than guessing at a procedure that hasn't been verified for it.

## Instructions

1. **Identify the target.** Resolve the project by its csproj's
   `<AssemblyName>`, not by guessing from the repo or exe name — they often
   differ (`TranslationRefsProds.exe` is built by the `Translation` repo).
   Read `<PublishDir>` from the csproj; don't assume a path. If asked to
   deploy something that isn't a recognisable .NET CGI/task project, stop and
   say so instead of improvising.

2. **Confirm what is currently deployed, before changing anything.**
   Hash the exe currently at the destination (`Get-FileHash -Algorithm
   SHA256`). Never diagnose or decide "needs deploying" against code that
   isn't actually running — that gap is exactly what caused the five-month
   outage. If a `DeployDrift.ps1`-style comparison is available, run it first.

3. **Check the working tree is clean and committed.** Refuse to build from
   uncommitted changes for a production deploy — the whole point is that
   deployed bytes trace back to a specific commit. If the user wants to
   deploy dirty/uncommitted work anyway, that's their call, but say so
   explicitly rather than doing it silently.

4. **Back up before touching anything** — both ends:
   - The currently-deployed artefact (`Name.exe.bak-YYYYMMDD`).
   - Any data file the new build will rewrite (e.g. a Parquet file the exe
     reads and rewrites in place). Skipping this on the data side is what
     turned a bug into 25,360 deleted rows during the Translation fix.

5. **Build.** `dotnet publish -c Release` from the project directory. Confirm
   the output actually changed (new mtime/hash) — a publish that silently
   no-ops looks identical to a successful one otherwise.

6. **Test against a scratch copy first if the service touches data.** Never
   let the first run of new code touch production data or state. Copy the
   real input/output files to a scratch location, point the exe at the copies
   (env var, working directory, or config override — whatever the service
   supports), and run it there. A fix that has never been deployed has never
   been exercised end-to-end — expect latent bugs on first real execution;
   this step is how you catch them before production does.

7. **Deploy.** If `<PublishDir>` already targets `cgi-bin`/the task location
   directly (the Anthea pattern), the publish in step 5 *is* the deploy — no
   separate copy. Otherwise copy the built exe to its destination. If the
   csproj auto-copies other assets after publish (e.g. an `.html` file), that
   is not evidence the binary was copied too — check the actual destination.

8. **Verify by hash**, not by "the copy command didn't error." SHA-256 of the
   deployed file must equal SHA-256 of what was just built.

9. **Smoke-test the real entry point end-to-end** — an actual CGI request or
   an actual run of the scheduled exe, not just launching it and checking
   exit code 0 (the Feb build printed "Action completed successfully" on
   every run while silently doing nothing). Check data invariants that
   matter for this service: row counts moved in the expected direction, key
   uniqueness, column count, freshness of the timestamp/max-date it writes.
   Know what "worked" means for this specific service before calling it done.

10. **Roll back on failure.** Know the rollback command before you start, not
    after something breaks: restore the `.bak` copy over the deployed
    artefact and (if step 4's data backup was used) the data file, then
    hash-verify the rollback landed correctly.

11. **Record the deploy and clean up.** Once verified, log it to the deploy
    history so there's a durable record beyond this conversation:
    ```
    pwsh -File R:\Scripts\Record-Deploy.ps1 -SqliteOut R:\Outputs\Parquets\deploy\deploy_history.sqlite `
      -Assembly <name> -Project <name> -FromHash <step-2-hash> -ToHash <step-8-hash> `
      -DeployedBy <user> [-Note "..."]
    ```
    (Source: `~/Git/Deployment/scripts/Record-Deploy.ps1`.) Then remove the
    `.bak` copies (or leave them briefly if the user wants a grace period).
    `DeployDrift.ps1`'s next run will independently confirm this as `OK`.

## Important Rules

- **Hash, never trust mtime.** A file copy preserves mtime; only bytes prove
  a deploy happened.
- **Prefer `<PublishDir>` pointing straight at the deploy destination** (the
  Anthea pattern) — no manual copy hop to forget. If the project being
  deployed lacks this and the user is open to it, suggest adding it, but
  don't restructure a csproj mid-deploy without asking.
- **Never skip the backup or the scratch-copy test** to save time on a
  production deploy, even for a "small" fix — the Translation fix looked
  small too, and untested-in-practice code deleted 25,360 rows on first
  contact with real data.
- **If the target is ambiguous** (exe not found where expected, no
  `<PublishDir>`, multiple projects match) or a safe backup/scratch-test
  genuinely cannot be done, stop and ask rather than guessing.
- **This procedure is read-write and touches production.** Confirm the
  target and the plan with the user before step 4 if anything about the
  request is unclear — this is exactly the kind of outward-facing, hard-to-
  reverse action that warrants a check-in.

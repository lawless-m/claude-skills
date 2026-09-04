# /deploy - Deploy a .NET or Rust CGI/scheduled-task service

Deploy a built .NET or Rust exe (CGI under `cgi-bin`, or a scheduled-task exe
run from its build output) safely, so the deploy is verified rather than
assumed.

**Why this exists**: Translation ran a Feb 5 binary for five months after its
fix was committed — `dotnet publish` was run, but the built exe was never
copied to `cgi-bin`. No error, no log line, no alert; the app just quietly got
slower every day. See the `Deployment` repo (`~/Git/Deployment`,
`notes/01-the-problem.md`) for the full post-mortem this procedure is drawn
from. `DeployDrift.ps1` in that repo (deployed at `R:\Scripts\DeployDrift.ps1`)
is the read-only detector for this failure mode; this command is the
procedure for deploying without causing it.

**Scope**: a `dotnet publish` or `cargo build --release` output copied (by
hand or already in place) into `cgi-bin` or run from a share. Windows
services, and anything else deployed by hand with no verified procedure, are
**out of scope**. If asked to deploy one of those, say so rather than
guessing at a procedure that hasn't been verified for it.

## Instructions

1. **Identify the target and how it's built.**
   - **.NET**: resolve the project by its csproj's `<AssemblyName>`, not by
     guessing from the repo or exe name — they often differ
     (`TranslationRefsProds.exe` is built by the `Translation` repo). Read
     `<PublishDir>` from the csproj; don't assume a path.
   - **Rust**: resolve via the crate's `Cargo.toml` and
     `cargo metadata --no-deps --manifest-path <path>` — it gives the real
     bin target name and `target_directory` (a workspace's members share one
     at the workspace root, e.g. MrsFlow's crates all build into
     `~/Git/MrsFlow/target`; a standalone `[workspace]` crate like Pintail
     has its own, e.g. `~/Git/Pintail/pintail-cgi/target`). Don't guess the
     layout — ask cargo. **Unlike .NET, there is no `<PublishDir>` shortcut
     that can point straight at `cgi-bin`** — a Rust deploy is always a
     manual copy from `target/release/`, so hop-2 always applies.
   - **Either kind**: check the project's own README for anything it
     documents deploying *besides* the exe — Pintail's, for instance,
     documents `pintail.properties`, `pintail-prompt.md`, `data_document.json`
     (all to `cgi-bin`) and `web/pintail.html` (to `pibs\`). None of those are
     covered by `DeployDrift.ps1`'s automated checks, which only look at the
     exe and separately at HTML boards matched by basename — so there is no
     safety net catching a forgotten copy of a companion file the way there
     is for the binary. Treat every documented companion file with the same
     rigor as the exe: back up, copy, hash-verify.
   - If asked to deploy something that isn't a recognisable .NET or Rust
     CGI/task project, stop and say so instead of improvising.

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

4. **Back up before touching anything** — every deployed file that's about
   to change:
   - The currently-deployed artefact (`Name.exe.bak-YYYYMMDD`).
   - Any documented companion file from step 1 (properties/prompt/data/html).
   - Any data file the new build will rewrite (e.g. a Parquet file the exe
     reads and rewrites in place). Skipping this on the data side is what
     turned a bug into 25,360 deleted rows during the Translation fix.

5. **Build.**
   - .NET: `dotnet publish -c Release` from the project directory.
   - Rust: `cargo build --release` from the crate directory (or
     `--manifest-path` from anywhere). Check the crate's `Cargo.toml`/README
     for any non-default features the *deployed* binary needs — most CGI
     crates seen so far set their own correct defaults (e.g. `mrsflow-cgi`'s
     `exportmaster` feature is on by default), so don't add flags on a guess;
     verify against docs if unsure rather than assume none are needed.

   Either way, confirm the output actually changed (new mtime/hash) — a
   build that silently no-ops looks identical to a successful one otherwise.

6. **Test against a scratch copy first if the service touches data.** Never
   let the first run of new code touch production data or state. Copy the
   real input/output files to a scratch location, point the exe at the copies
   (env var, working directory, or config override — whatever the service
   supports), and run it there. A fix that has never been deployed has never
   been exercised end-to-end — expect latent bugs on first real execution;
   this step is how you catch them before production does.

7. **Deploy.**
   - .NET, `<PublishDir>` already targeting `cgi-bin`/the task location
     directly (the Anthea pattern): the publish in step 5 *is* the deploy —
     no separate copy. Otherwise copy the built exe to its destination.
   - Rust: always copy `target/release/<bin>.exe` to its destination — there
     is no direct-publish shortcut for Rust.
   - Either kind: also copy every companion file identified in step 1, to
     the destination its own docs specify. If the csproj auto-copies other
     assets after publish (e.g. an `.html` file), that is not evidence the
     binary was copied too — check the actual destination for every file,
     don't infer one from another.

8. **Verify by hash**, not by "the copy command didn't error." SHA-256 of
   every deployed file (the exe and every companion file) must equal SHA-256
   of what was just built/copied.

9. **Smoke-test the real entry point end-to-end** — an actual CGI request or
   an actual run of the scheduled exe, not just launching it and checking
   exit code 0 (the Feb build printed "Action completed successfully" on
   every run while silently doing nothing). Check data invariants that
   matter for this service: row counts moved in the expected direction, key
   uniqueness, column count, freshness of the timestamp/max-date it writes.
   Know what "worked" means for this specific service before calling it done.

10. **Roll back on failure.** Know the rollback command before you start, not
    after something breaks: restore the `.bak` copy over every deployed file
    that changed (exe and companions) and (if step 4's data backup was used)
    the data file, then hash-verify the rollback landed correctly.

11. **Record the deploy and clean up.** Once verified, log it to the deploy
    history so there's a durable record beyond this conversation:
    ```
    pwsh -File R:\Scripts\Record-Deploy.ps1 -SqliteOut R:\Outputs\Parquets\deploy\deploy_history.sqlite `
      -Assembly <name> -Project <name> -FromHash <step-2-hash> -ToHash <step-8-hash> `
      -DeployedBy <user> [-Note "..."]
    ```
    (Source: `~/Git/Deployment/scripts/Record-Deploy.ps1`.) Then remove the
    `.bak` copies (or leave them briefly if the user wants a grace period).
    `DeployDrift.ps1`'s next run will independently confirm the exe as `OK`
    (companion files aren't covered yet — see the Deployment repo's open
    questions).

## Important Rules

- **Hash, never trust mtime.** A file copy preserves mtime; only bytes prove
  a deploy happened.
- **Prefer `<PublishDir>` pointing straight at the deploy destination** (the
  Anthea pattern, .NET only) — no manual copy hop to forget. Rust has no
  equivalent shortcut; its hop-2 copy always needs doing and verifying by
  hand. If a .NET project lacks this and the user is open to it, suggest
  adding it, but don't restructure a csproj mid-deploy without asking.
- **A companion file is not covered by `DeployDrift.ps1`.** For Rust
  projects especially, don't let "the exe verified fine" stand in for "the
  deploy is done" — check every file the project's own docs say it deploys.
- **Never skip the backup or the scratch-copy test** to save time on a
  production deploy, even for a "small" fix — the Translation fix looked
  small too, and untested-in-practice code deleted 25,360 rows on first
  contact with real data.
- **If the target is ambiguous** (exe not found where expected, no
  `<PublishDir>`/no resolvable Cargo target, multiple projects match) or a
  safe backup/scratch-test genuinely cannot be done, stop and ask rather
  than guessing.
- **This procedure is read-write and touches production.** Confirm the
  target and the plan with the user before step 4 if anything about the
  request is unclear — this is exactly the kind of outward-facing, hard-to-
  reverse action that warrants a check-in.

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
   - **One program per deploy, taken from where `/deploy` is called.** Some
     repos hold many programs (`RocsMiddleware` has a dozen, each in its own
     folder with its own csproj). When the working directory is a project
     folder — it holds the csproj/`Cargo.toml` or its `deploy.ps1` — that
     project is the target and **nothing else is deployed**. Called from a
     multi-project repo root with no program named, ask which one; don't
     infer it from recent commits. Never run a repo-wide publish
     (`RocsMiddleware\check-published.ps1 -Publish` republishes every stale
     project) as a way of deploying one.
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
   - **Does the project already have a deploy script?** Look for a
     `deploy.ps1` (or equivalent) in the project's own folder, then the repo
     root for a single-program repo, *before* doing any of this by hand. In a
     multi-program repo the script belongs beside the csproj
     (`RocsMiddleware\X3CustomerPull\deploy.ps1`), never at the root. If there is one, read it and run it — it is the verified
     procedure for that project, and re-deriving the steps in conversation
     is exactly how a project-specific flag gets dropped. If there isn't
     one, see **Writing a deploy script** below: the default is to write and
     commit one as part of this deploy, not to hand-execute steps 2-11 again.
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

   **Then push the branch to origin** (`git push origin <branch>`). Running
   `/deploy` is the instruction to push; no separate ask is needed. The
   Chestnut dashboard links each program's version to its commit on Gitea, and
   a commit that exists only in a local clone is a 404 there — production
   running code origin has never seen. If the push fails (diverged, rejected),
   stop and ask; never force.

4. **Back up before touching anything** — every deployed file that's about
   to change:
   - The currently-deployed artefact.
   - Any documented companion file from step 1 (properties/prompt/data/html).
   - Any data file the new build will rewrite (e.g. a Parquet file the exe
     reads and rewrites in place). Skipping this on the data side is what
     turned a bug into 25,360 deleted rows during the Translation fix.

   **Backups go in `R:\Outputs\deploy-backups\<Assembly>\`, never beside the
   file they copy.** Writing `Name.exe.bak-YYYYMMDD` into `cgi-bin` was the
   earlier convention and it was a bad one on two counts. `cgi-bin` and `www`
   are *served*: a `.html.bak` there is fetchable over HTTP, and stale exes sit
   in the CGI directory. And because the copies are only removed by a run that
   reaches step 11, every failed or hand-run deploy left one behind — 458 MB
   of them had accumulated across the estate by 2026-09-22, which is what
   prompted this change. Keep the naming (`Name.exe.bak-yyyyMMdd-HHmmss`), just
   not the location.

5. **Build.**
   - .NET: `dotnet publish -c Release` from the project directory — but
     only once the csproj declares everything the deployed artefact needs.
     A CGI exe here typically needs `<RuntimeIdentifier>`, `<SelfContained>`
     and `<PublishSingleFile>`; without them the publish still *succeeds*
     and quietly emits a small framework-dependent exe that cannot run as a
     CGI. DDBMakerCGI's csproj declared none of them, so the documented
     build produced 156 KB against a live 107 MB binary. Put those
     properties **in the csproj, never on the command line**, so no
     invocation can leave them off.
   - Rust: `cargo build --release` from the crate directory (or
     `--manifest-path` from anywhere). Check the crate's `Cargo.toml`/README
     for any non-default features the *deployed* binary needs — most CGI
     crates seen so far set their own correct defaults (e.g. `mrsflow-cgi`'s
     `exportmaster` feature is on by default), so don't add flags on a guess;
     verify against docs if unsure rather than assume none are needed.

   Either way, confirm the output actually changed (new mtime/hash) — a
   build that silently no-ops looks identical to a successful one otherwise.

   **If the project does not yet stamp its commit into the artefact, add that
   now, as part of this deploy.** The flow here is edit code → make binary →
   test binary → update documentation → commit code, so at the moment of the
   build the commit does not exist yet. The .NET SDK stamps `SourceRevisionId`
   (HEAD at build time) into `ProductVersion` automatically, which under this
   flow names the commit *before* the code in the binary. `Rupert.Cgi.exe`,
   `CS-EM2Parquet.exe` and `T0_Report.exe` were each built seconds before the
   commit that held their code and each shipped naming the wrong one.

   That matters because of what it does to the drift board: a binary built from
   an uncommitted tree is stamped with HEAD, has no source commits after HEAD,
   and therefore reads **`OK`** — green, with uncommitted code in production.
   Overriding the stamp with `git describe --always --dirty` turns that into
   `UNTRACEABLE`. Green that should be red is the failure worth spending on;
   red that should be green only costs a redeploy.

   Reference implementations: `~/Git/Rupert` (csproj `StampCommitId` target —
   mind that `--` is illegal inside an XML comment) and `~/Git/Pintail`
   (`build.rs` emitting a `RIBUILDSTAMP:` literal, since Rust has no version
   resource). Both use the dirty flag, which ignores untracked files, so
   scratch beside the project does not mark every build dirty.

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
   - **If the overwrite is refused because the file is in use**, move the
     live file aside and copy into the freed name; don't just fail. Windows
     won't overwrite or delete a running exe, but it will rename one, and the
     running process carries on from the renamed file. A CGI request in
     flight, or a virus scanner re-reading a large exe, is enough to hold it —
     CMS Scanner's deploy failed on exactly that on 2026-09-23. Move it into
     `R:\Outputs\deploy-backups\<Assembly>\` as `Name.exe.inuse-<stamp>`,
     never beside the original: `R:` is `\\rivsprod02\RI Services`, the same
     share as `TinyWeb`, so the move is still a rename (tested with a running
     exe, UNC path to `R:` path), and a stale exe never sits in `cgi-bin`. The
     held file stays locked until its holder exits, so remove it at the end if
     you can and leave it if you can't; the next run's sweep collects it.
     Reference: `~/Git/CMS-Scanner/deploy.ps1` (`Install-File`,
     `Remove-Held`).

8. **Verify by hash**, not by "the copy command didn't error." SHA-256 of
   every deployed file (the exe and every companion file) must equal SHA-256
   of what was just built/copied.

   Hash equality only proves the copy landed — it says nothing about whether
   the *right thing* was built. Check the artefact's shape as well: a
   framework-dependent .NET publish verifies perfectly clean by hash while
   being the wrong binary entirely, and only its size gives it away. A size
   floor is the cheapest test that catches that.

   Then read the stamp back out of the deployed artefact and assert it is this
   commit: `(Get-Item $exe).VersionInfo.ProductVersion` for .NET, `<exe>
   --build-stamp` for the Rust ones. A `-dirty` stamp on a production deploy is
   a failure unless it was explicitly asked for — it means the bytes on the
   share match no commit at all.

9. **Smoke-test the real entry point end-to-end** — an actual CGI request or
   an actual run of the scheduled exe, not just launching it and checking
   exit code 0 (the Feb build printed "Action completed successfully" on
   every run while silently doing nothing). Check data invariants that
   matter for this service: row counts moved in the expected direction, key
   uniqueness, column count, freshness of the timestamp/max-date it writes.
   Know what "worked" means for this specific service before calling it done.

10. **Roll back on failure.** Know the rollback command before you start, not
    after something breaks: restore step 4's copy over every deployed file
    that changed (exe and companions) and (if step 4's data backup was used)
    the data file, then hash-verify the rollback landed correctly.

11. **Record the deploy and clean up.** Once verified, log it to the deploy
    history so there's a durable record beyond this conversation:
    ```
    pwsh -File R:\Scripts\Record-Deploy.ps1 -SqliteOut R:\Outputs\Parquets\deploy\deploy_history.sqlite `
      -Assembly <name> -Project <name> -FromHash <step-2-hash> -ToHash <step-8-hash> `
      -DeployedBy <user> [-Note "..."]
    ```
    (Source: `~/Git/Deployment/scripts/Record-Deploy.ps1`.) Then remove this
    run's backups from `R:\Outputs\deploy-backups\<Assembly>\` (or leave them
    briefly if the user wants a grace period). `DeployDrift.ps1`'s next run
    will independently confirm the exe as `OK` (companion files aren't covered
    yet — see the Deployment repo's open questions).

    Sweep the same directory at the *start* of the next run too. Removing
    backups only on success means a failed deploy keeps its rollback source —
    which is right — but nothing ever collects them afterwards, and that is
    exactly how the estate accumulated 458 MB of them. Deleting the previous
    run's leftovers once a new run has taken its own backup bounds the growth
    without ever leaving a deploy without a rollback.

## Writing a deploy script

Once a deploy has been worked out by hand it should not need working out by
hand again. If the project has no deploy script, write one as part of the
deploy and commit it — a chat transcript is not a durable record of a
procedure, which is the same class of problem as a binary that exists only on
a share.

`~/Git/DDBMakerCGI/deploy.ps1` is the reference: it implements steps 2-11 for
one project in ~130 lines. A compatible script has to:

- **Refuse a dirty tree** unless explicitly overridden (`-AllowDirty`), and
  capture the commit sha and subject for the deploy note.
- **Hash the live artefact first, then back it up** into
  `R:\Outputs\deploy-backups\<Assembly>\`, not next to the original. With
  `<PublishDir>` pointing at the destination the publish overwrites production
  directly, so the backup cannot be taken after it.
- **Read the destination out of the project file** instead of repeating it in
  the script. `DeployDrift.ps1` resolves the build from `<PublishDir>`; a
  script with its own hardcoded copy of that path can silently disagree with
  the drift report about where the binary is supposed to be.
- **Verify by hash, by shape, and by stamp** — see step 8. Check the stamp
  *before* copying where the deploy is a two-hop copy (Rust), so a mis-stamped
  binary never reaches the share at all.
- **Smoke-test the real entry point and assert something specific about the
  response**, not just HTTP 200. DDBMakerCGI's script checks for the `DUCK`
  magic at offset 8 of the served database.
- **Survive a locked destination**: overwrite, and when that is refused
  because the file is in use, move the live file aside into the backup
  directory and copy into its name (see step 7). Use the same routine in the
  rollback — a request running the *new* exe locks it just as well.
- **Roll back in a `catch`** wrapping everything from the publish onward:
  restore the backup over the artefact and hash-verify the restore landed.
- **Call `Record-Deploy.ps1`** with the before/after hashes.
- **Remove this run's backup only on success** — a failed run keeps it — and
  **sweep the previous run's leftovers at the start**, once this run's own
  backup is safely taken. The sweep covers held `.inuse-*` files too, one at
  a time, skipping any that are still locked.

Write it, then run it for the deploy at hand; the first real run is also the
test of the script. Note that the destination is machine-specific
(`R:\TinyWeb\www\cgi-bin\`) — that is the estate's existing convention,
not something this procedure introduces.

If the project also lacks a `<PublishDir>`, add one while you are there.
Without it `DeployDrift.ps1` reports the artefact `NO-BUILD` on every run,
which means the deployed binary is never compared to anything. Pointing it at
the destination is preferred (see the rules below); where that isn't wanted, a
declared staging directory still brings the project under coverage and keeps
the hop-2 "built but never copied" signal that publishing straight to
`cgi-bin` collapses.

## Important Rules

- **Prefer the project's own deploy script to doing it by hand**, and where
  there isn't one, leave one behind. Hand-running this procedure is the
  fallback, not the default.
- **Hash, never trust mtime.** A file copy preserves mtime; only bytes prove
  a deploy happened.
- **A commit sha stamped at build time names the commit BEFORE the one you
  want**, because the binary is built before the commit exists. Read `-dirty`
  as "built by hand, never went through the deploy script" — which is exactly
  what it means, and exactly what must not be in production.
- **Prefer `<PublishDir>` pointing straight at the deploy destination** (the
  Anthea pattern, .NET only) — no manual copy hop to forget. Rust has no
  equivalent shortcut; its hop-2 copy always needs doing and verifying by
  hand. If a .NET project lacks this and the user is open to it, suggest
  adding it, but don't restructure a csproj mid-deploy without asking.
- **A companion file is not covered by `DeployDrift.ps1`.** For Rust
  projects especially, don't let "the exe verified fine" stand in for "the
  deploy is done" — check every file the project's own docs say it deploys.
- **Never write a backup into a served directory.** `cgi-bin`, `www` and
  `pibs` are reachable over HTTP; a `.bak` there is a stale copy of production
  that anyone can fetch. Backups belong in `R:\Outputs\deploy-backups\`.
  Hand-made checkpoint files whose names record an intent (`cages.html
  .bak-20260914-precagezero`) are someone's working history, not deploy
  residue — leave those alone and ask before touching them.
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

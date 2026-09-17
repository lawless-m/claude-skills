---
name: chestnut
description: Use when told to "use /chestnut for logging", or when adding structured logging to, or converting the logging of, an RI CGI program or scheduled task — the Chestnut JSON Lines standard, library, Vector shipping and dashboard.
---

# Chestnut

Chestnut is RI's structured logging standard for CGI programs and scheduled tasks: a C#
library that appends JSON Lines to `C:\RI Services\Logs\<program>\<program>_YYYY-MM-DD.jsonl`,
Vector shipping them to a consolidated tree, and a dashboard over that tree
(`https://dw.ramsden-international.com/tiny02/pibs/chestnut.html`).

## 1. Make sure the repo is present

The repo must sit at `~/Git/Chestnut` — consuming projects reference the library by a
relative `ProjectReference`, so it has to be a sibling of the program's repo.

- Missing: `git clone git@dw.ramsden-international.com:matthew.heath/Chestnut.git ~/Git/Chestnut`
- Present: don't pull or touch its working tree unasked. `git -C ~/Git/Chestnut fetch` and
  mention it if `master` is behind `origin/master` or the tree is dirty.

## 2. Read before doing anything

The repo is the source of truth; this skill only points into it.

- `README.md` — library API, env vars (`CGILOG_ROOT`, `CGILOG_LEVEL`, `CGILOG_STDERR`,
  `CGILOG_TRIGGER`, `CGILOG_SCHEDULE`), guarantees, dashboard, build/test.
- `logging-standard/06-conversion-playbook.md` — **the procedure**, with its checklist.
- `logging-standard/01-log-event-schema.md` — the event contract, kept to hand.
- `conversions/elastifetch-survey.md` — the reference conversion (scheduled task, M.E.Logging
  adapter, deploy, first-run verification). `conversions/x3_4gl-survey.md` is a second one
  (a generic tool whose schedule comes from `CGILOG_SCHEDULE` set by the calling .bat).

## 3. Conventions established so far

- **One program per session.** Scope is logging only: no behaviour changes, no refactors.
  Things that look wrong go in the survey's observations, not the diff.
- The survey is written to `~/Git/Chestnut/conversions/<program>-survey.md` **before** the
  program's code changes. It stays in the Chestnut repo, not the program's repo.
- `program` is lower snake case and becomes the log directory name (`x3_4gl`).
- Reference the library from the program's csproj, with the comment the others carry:
  ```xml
  <!-- Structured logging to C:\RI Services\Logs\<program>. Needs the Chestnut repo checked out beside this one. -->
  <ProjectReference Include="..\Chestnut\src\Chestnut\Chestnut.csproj" />
  ```
  (adjust the `..` depth to where the csproj sits under `~/Git/<Repo>`).
- Existing `Microsoft.Extensions.Logging` code: swap the provider for `AddChestnut(log)` and leave
  the log calls alone. Dispose the `LoggerFactory` before the `ChestnutLogger`.
- `RunEnd` on every exit path, including argument-parse failures in `Main`.
- A deploy script's smoke run must set `CGILOG_ROOT` to a scratch dir and `CGILOG_TRIGGER=manual`,
  then delete the scratch — otherwise it leaves a fake scheduled run in the estate's logs.
  `~/Git/X3Bot/deploy.ps1` does all of this and restores the env afterwards (the playbook names
  ElastiCompare's, but that one only sets `CGILOG_ROOT`). Framework-dependent deploys must also
  check `Chestnut.dll` landed beside the exe, as `~/Git/ElastiCompare/deploy.ps1` does. Use `/deploy` for the deploy itself.
- Verification isn't done at deploy: the first real scheduled run, under the task's own
  account, must be confirmed in the log and via Vector, and recorded in the survey.

## 4. Rust

`logging-standard/04-library-rust.md` is the spec. Check whether the crate exists yet
(`~/Git/Chestnut/rust/chestnut/Cargo.toml`). If it doesn't, building it is its own piece of
work, done and tested in the Chestnut repo before any Rust program uses it. Don't write the
format by hand inside the program.

When building the crate:
- **Match the C# library's events and env vars.** The spec predates the C# code, so it doesn't
  mention `CGILOG_TRIGGER` or `CGILOG_SCHEDULE`; implement both. The events have to be
  indistinguishable, so the cross-language conformance check in `04` is required, not optional.
- **`CGILOG_ROOT` is required, with no default.** This is the one place the Rust crate
  deliberately differs from C#: the spec and `vector/linux.md` both say so. If it's unset, fall
  back to stderr and say why. Never quietly pick a path.
- **Prove the concurrency test on the target host.** Port `tests/Chestnut.Stress` and run
  several hundred processes appending on the real log root. The spec's claim about Windows
  append mode was wrong for .NET (see the erratum in `02`), so test rather than assume.

### Rust programs on Linux

rivsprod01 is the only Linux host with Vector so far. On any other host, check
(`systemctl is-active vector`) and don't assume.

**Host without Vector.** The program doesn't depend on Vector: it logs locally either way, so
building and converting can go ahead. But the program won't show on the dashboard, and the
conversion isn't finished, until this host ships. Putting Vector on it follows
`vector/linux.md`. It needs sudo, so find out who has it on that host. It also needs the
host's own copy of the rivsprod02 `RI Services` share mount, since that's where the sink
writes. If the host has no such mount, adding it (fstab, credentials, share grant) is a change
to the host. Raise it with the user rather than doing it as part of a logging job. Pin Vector
0.58.0, use `/var/log/ri-services` as the log root so `vector-linux.toml` works unchanged, and
record the install in `vector/linux.md` and the memory note on Vector hosts, as rivsprod01's
was.

**beast** (`ssh beast`, checked 2026-09-17):
- Debian 13, x86_64, user `matt` with passwordless sudo. `cargo` 1.95 is in `~/.cargo/bin`,
  which isn't on PATH for a non-interactive ssh command, so call it by full path. The machine
  can clone Chestnut from dw, but it isn't cloned yet.
- There's no Vector and no `/var/log/ri-services`, and `setfacl` is missing (`apt install acl`).
- The rivsprod02 `RI Services` share is already mounted at `/mnt/RIVSPROD02_RI_SERVICES`, with
  `noperm` and `/etc/win-credentials`. Here that path is the real mount, not a symlink as on
  rivsprod01, so `RequiresMountsFor=` uses it directly. The share needs no change.
- Scheduled jobs are systemd timers (no crontabs), mostly `User=root`.
- **The system time zone is `Etc/UTC`.** Timestamps will show `+00:00` and timers run in UTC,
  unlike the Windows hosts on UK time. Raise this with the user before recording a schedule.
- `hostname` is lower-case `beast`, so its sink folder won't match the upper-case
  `RIVSPROD01`/`RIVSPROD02` folders. Decide that when installing Vector.
- The root disk was 94% full.
- Passing `ssh beast` a command prints a port 5905 forwarding warning. It's harmless;
  `-o ClearAllForwardings=yes` silences it.

**Long-running servers** (decided 2026-09-17, first case `food-packaging-ocr` on beast):
one `run_start`/`run_end` pair covers the whole life of the server process, with one event per
request in between. This changes the standard itself, so it needs **a written proposal the user
has reviewed before any code**. The standard (`01`) was written for one process per run, so
the proposal must settle:
- **A schema change first.** `trigger` is `http`/`schedule`/`manual` and none fits a server.
  Agree the new value with the user (e.g. `service`), then add it to `01` along with its
  `run_start`/`run_end` data fields, in both libraries.
- **`run_end` on shutdown.** systemd stops a unit with SIGTERM, so the crate needs a signal
  handler that emits `run_end`. SIGKILL and the OOM killer leave no `run_end`. The next
  `run_start` from a new pid is the only evidence, so the monitor should treat a new run
  following an unfinished one as a crash.
- **Dashboard changes.** `Chestnut.Monitor` shows a run with no end as `running`, and decides
  "overdue" from a cron schedule. A server has no schedule, so it needs its own states
  (up, restarted, down), not the scheduled-task ones.
- **Request events.** Give each request its own `request_id` (or accept an incoming one) and
  log it on the request event, so requests can be grouped. Agree the event name and data
  fields with the user and record them in `01`.

**Every Linux host:**
- Set `CGILOG_ROOT=/var/log/ri-services` wherever the program is started: crontab line,
  systemd unit `Environment=`, or a wrapper script. If this is missing or wrong, Vector watches
  an empty directory and nothing reports an error.
- `/var/log/ri-services` is created with `sudo mkdir`, so it's root-owned. The account that runs
  the program must be able to create `<program>/` in it. Check that as that account
  (`sudo -u <acct> ...`); don't work it out from your own shell. The `setfacl` default ACL in
  `linux.md` gives the `vector` user read on new program folders. On a new host it has to be
  applied first.
- Record the crontab or timer schedule as cron text in `run_start`. For systemd timers, convert
  `OnCalendar=` to cron; don't record it verbatim, because the dashboard parses cron.
- The playbook is written for Windows. Swap Task Scheduler for the crontab or timer, the
  service account for the user the job runs as, and Start-in for the job's working directory.
  In the survey, check any log path the program has hardcoded.
- Trigger detection is the same: `REQUEST_METHOD` means `http`, otherwise `schedule`. Hand runs
  set `CGILOG_TRIGGER=manual`.
- Check delivery end to end: the program's own file should be identical to the day's file in
  `/mnt/RIVSPROD02_RI_SERVICES/Vector/events/<HOSTNAME>/`. That file shares one day for the
  whole host, so never delete it (see `linux.md`).

Consumers use a path dependency, the Rust equivalent of the C# `ProjectReference`:
`chestnut = { path = "../Chestnut/rust/chestnut" }`.

## 5. New programs

The playbook is about converting existing programs. A new program has no baseline, so skip the
survey and baseline steps. Everything else still applies from the first commit: initialise
first, `run_start`, `run_end` on every exit path, the panic/exception handler, the smoke-run
env, and confirming the first scheduled run. Still add a short
`conversions/<program>-survey.md` recording the program name, trigger, schedule, host and
deploy, so the estate stays listed in one place.

## Not this

The older `Logging` skill (`Utf8LoggingExtensions.cs`, `--log-dir`, plain text `.log`) is the
pre-Chestnut RocsMiddleware pattern. When Chestnut is asked for, Chestnut replaces it.

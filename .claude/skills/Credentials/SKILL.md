---
name: Credentials
description: Use when the user says "use kdbx", "move it to kdbx", "put that in KeePass" or "the vault", or when any RI program (console app, scheduled task, CGI, Linux service, Python or shell script, dev one-off) needs a password, API key or connection string, or has one in a JSON/appsettings/.properties file, a share or the source. Covers the shared KeePass vault, its entries, reading them from C#, Rust, Python and shell, and getting the master password onto the machine and account that runs the program.
---

# Credentials: the KeePass vault (kdbx)

**Every RI secret lives in one KeePass vault, read at runtime. This applies to any kind of program,
not just CGIs.** A console tool someone runs by hand, a scheduled task, a TinyWeb CGI, a systemd
service and a Python script all read the same way. Only *how the master password reaches the
process* changes with where it runs (see below). Config and command lines carry a *pointer* to the
entry, never the secret. A password in a JSON file on a share, in `appsettings.json` or in the repo
is what "we should use kdbx" means to get rid of.

| | |
|---|---|
| Vault | `\\RIVSPROD02\RI SERVICES\Credentials\ServicePasswords.kdbx` (KDBX4, master password only, no key file) |
| Secret-store key | **`kdbx-services`** (the test fixtures use `kdbx-master`: don't copy that) |
| Libraries | `C:\Sprout\Keepass-access-libs` (Gitea `matthew.heath/Keepass-access-libs`): C# `KdbxCredentials`, Rust `kdbx-credentials`. Both are read-only |
| CLI | `kdbx-getfield <vault> kdbx-services <group/title> username\|password\|url\|notes` (on PATH on Windows dev hosts and at `/usr/local/bin` on Linux) |

Entries are looked up by `group/title`, case-insensitive. An entry's **URL** holds the server
(`host`, `host:port` or `server\instance`), and extra settings go in **Notes** as `key=value` lines.
Neither library writes to the vault: Matt adds new entries in the KeePass app, so ask for one when
it's missing.

## Known entries

Verified in the vault on 2026-10-30:

| Entry | What | Read by |
|---|---|---|
| `X3/sagex3` | X3 SQL Server, read-only `SDRamsden_RO`; URL `10.80.42.21\X3LIVE`; Notes `schema=RAMLIVE` | X3CustomerPull, DrX3 |
| `X3/api` | X3 REST API: Password = API key, URL = API root. No username | X3CustomerPull |
| `PSQL/x3rocs` | PostgreSQL x3rocs on rivsprod01 (URL = host) | X3CustomerPull |
| `Exportmaster/RIVSEM01` | DBISAM login, URL `host:port` | SuperSub, ReproSharepointer, X3CustomerPull |

Also referenced in code but not checked here: `X3/MHE` (X3Bot), `Azure/Sharepointer`,
`ROCS/Keycloak`, `vSphere/vsphere`, `Trademap/it`, `Nisa/nisaretail`, `Gitea/chestnut`,
`Maxmind/Maxmind`. To check that an entry exists, read its **username** with `kdbx-getfield`. Never
print the password: when you need to know whether two secrets match, compare them in a script that
prints only the result.

## Reading it

- **C#:** add
  `<ProjectReference Include="..\..\Keepass-access-libs\csharp\src\KdbxCredentials\KdbxCredentials.csproj" />`
  (adjust the `..` depth so it lands on `C:\Sprout\Keepass-access-libs`), then
  `using var db = Database.Open(vaultPath, "kdbx-services"); using var e = db.Lookup("X3/sagex3");` and read
  `e.Username`, `e.Password`, `e.Url` and `e.Notes`. Failures are `KdbxException` subtypes
  (`EntryNotFoundException`, `SecretNotFoundException`, `AuthenticationFailedException`, …).
  Worked example with URL and Notes parsing:
  `RocsMiddleware/X3CustomerPull/Services/VaultCredentials.cs`. Programs that log with Chestnut pass
  `(vault, entry) => log.Io(IoKind.Kdbx, IoDirection.Read, null, vault, entry)` as the third argument
  of `Open`.
- **Python / shell:** call `kdbx-getfield` as a subprocess, one call per field (see
  `NisaFeedFetch/scripts/sftp_list.py`, `X3Bot/x3-cred.sh`).
- **Rust:** the `kdbx-credentials` crate in the same repo.
- **Config:** a `.properties` file holds `kdbx_path`, `kdbx_entry` and `kdbx_secret_store_key`. A CLI
  defaults to the shared vault and a fixed entry, with `--kdbx` / `--entry` overrides.

## Where the master password comes from

It is never in config or code. It sits in the OS secret store **of the account the process runs
as**, under `kdbx-services`. This is the part that differs per kind of program.

| Runs as | How to provision it |
|---|---|
| You, interactively on Windows (dev, a hand-run tool) | Credential Manager target `kdbx-services`, account `kdbx-credentials`. Use `provision-credential.bat` in the libs repo. Already done on Matt's dev hosts |
| Named service account (scheduled task, e.g. `NISAINT\scheduler.service.ac`) | `provision-runas.bat <account>` |
| LocalSystem (TinyWeb CGIs on RIVSPROD02, NSSM services) | `runas` can't become SYSTEM. Use the one-shot scheduled task `R:\kdbx\provision-system.bat`. `cmdkey /list` as admin won't show it, so test by having the service read it |
| Linux systemd service | root-only file `/etc/credstore/kdbx-services` and `LoadCredential=kdbx-services:/etc/credstore/kdbx-services` in the unit (unencrypted: systemd 247, no `systemd-creds`). Reference unit: `S3ImageCache/deploy/s3imagecache.service` |
| Linux, anything not launched by that unit (`dotnet run`, cron, a shell) | Set `CREDENTIALS_DIRECTORY` to a directory holding a `kdbx-services` file (UTF-8, no trailing newline). The dev box has `~/.config/ri-creds`, exported in `~/.bashrc` above the non-interactive guard. Non-login shells and cron don't source it, so prefix the variable there |

Full recipes: `Keepass-access-libs/csharp/USAGE.md` §3 and `deploy/systemd/README.md`.
`sc qc <service>` (`SERVICE_START_NAME`) tells you which account a Windows service runs as.

## Gotchas

- `SecretNotFoundException` almost always means the right key is in the *wrong account's* store,
  for example yours rather than SYSTEM's or the task account's. The vault and the code are usually
  fine.
- `kdbx-getfield` exits non-zero with `entry 'X' has no username` for key-only entries such as
  `X3/api`. That just means the field is empty, not that the lookup failed.
- In Java-properties files a UNC path needs doubled backslashes:
  `\\\\RIVSPROD02\\RI SERVICES\\Credentials\\ServicePasswords.kdbx`.
- Moving a project onto the vault: point it at the entry, stop tracking the old secret file and add
  it to `.gitignore`, then check whether the old file's password was real before deciding whether
  it needs rotating.

---
name: Windows Servers
description: Use when running commands on RI's Windows servers RIVSPROD02 (prod), RIVMIS01, RIVSIS02, RIVMDEV01, RIVSEM04 or RIVSEM01 (Exportmaster prod) — remote PowerShell as mh.admin, or when the user says "on prod2", "on sis", "on mis", "on dev01", "on sem04", "on sem01".
---

# Windows Servers (PowerShell remoting)

The user's profile (`$PROFILE`, OneDrive `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) defines
interactive shortcuts: `sis` → RIVSIS02, `mis` → RIVMIS01, `dev01` → RIVMDEV01, `sem04` → RIVSEM04, `sem01` → RIVSEM01, `prod2` → RIVSPROD02. They use
`Enter-PSSession`, which is interactive; **it does not work from Claude's tool calls**. Use `Invoke-Command`
with the same credential and the pwsh 7 endpoint:

```powershell
$cred = Import-Clixml "$env:USERPROFILE\mh.admin.xml"   # nisaint\mh.admin, DPAPI-encrypted: only this user on this machine can read it
Invoke-Command -ComputerName RIVSPROD02 -Credential $cred -ConfigurationName PowerShell.7 -ScriptBlock { Get-Service W3SVC }
```

**Always pass `-ConfigurationName PowerShell.7`.** Without it you get the default Windows PowerShell 5.1
endpoint, which has no `&&`, ternary or `??`, and writes files as UTF-16/ANSI unless `-Encoding UTF8` is set.

For several commands in a row, open one session with `New-PSSession` (with the same `-ConfigurationName`),
then run `Invoke-Command -Session`, then `Remove-PSSession`.

## Facts

| Alias | Host | pwsh | Notes |
|---|---|---|---|
| `prod2` | RIVSPROD02 | 7.6.6 | **Production.** The profile turns the terminal text red. Confirm with the user before any change. |
| `mis` | RIVMIS01 | 7.6.6 | Usually the machine Claude runs on (check `$env:COMPUTERNAME`). Local commands run as matthew.heath; remote to it only when mh.admin rights are needed. |
| `sis` | RIVSIS02 | 7.6.6 | Has its own profile variant, `Microsoft.PowerShell_profile-RIVSIS02.ps1` (prompt only). C: was down to 4.9 GB free; 33 GB free after cleanup on 2026-09-25. The user's former daily dev VM; RIVMIS01 replaced it. The user logs in as mh.admin; the local Matthew.Heath profile was removed on 2026-09-25. `\RocsMiddleware\cust info wiki` (hourly, about 15 min per run) was moved to mh.admin with a stored password on 2026-09-25. It used to be interactive-only as Matthew.Heath. |
| `dev01` | RIVMDEV01 | 7.6.6 | Dev box, 192.168.102.28. WinRM was broken on 2026-10-03: the 5985 listener was down, then every session failed with "WSMan service could not launch a host process" until `Enable-PSRemoting -Force` was run locally. Only the 5.1 endpoint existed until pwsh 7.6.6 was installed from the share the same day. Has internet. About 11 GB free on C: then. |
| `sem01` | RIVSEM01 | 7.6.6 | 192.168.102.2. **Production: the Exportmaster machine.** The profile alias turns the terminal text red. Confirm with the user before any change. Windows Server 2012 R2 (6.3.9600), so its default `powershell.exe` is **4.0**: no `&&`, ternary or `??`. **Weekly reboot on Sunday about 05:00.** Had no `PowerShell.7` endpoint; pwsh 7.6.6 was installed side by side from the share on 2026-10-03 (about 30 s, no reboot, `powershell.exe` untouched). .NET 8/9/10 list 2012 R2 as supported only with ESU, so 7.6 here is "should work", not an explicit Microsoft statement. WMF 5.1 was deliberately not installed (replaces 4.0 in place and needs a reboot). The mh.admin session cannot read `\\rivsts05` (double hop); the SYSTEM task can. 18 GB free on C: then. |
| `sem04` | RIVSEM04 | 7.6.6 | 192.168.102.240. Remoting worked first time on both endpoints (checked 2026-10-03), no repair needed. Upgraded from 7.5.4 to 7.6.6 from the share on 2026-10-03. Only about 7.9 GB free on C: then. |

## Gotchas

- Local variables do not reach the remote side automatically. Use `$using:var` or `-ArgumentList`.
- Returned objects are deserialized, so they have properties but no methods. Do the work remotely and return
  only the data.
- **Anything that restarts WinRM kills the remote session and its child processes mid-run.** This includes
  `Enable-PSRemoting` and registering an endpoint for a new pwsh version. Run those as a one-off SYSTEM
  scheduled task (`Register-ScheduledTask` → `Start-ScheduledTask`, poll, then unregister). That is how
  PowerShell.7 was registered on RIVSPROD02 on 2026-09-25.
- Upgrading pwsh: download the MSI on the server (prod has internet), check its SHA-256 against the GitHub
  release asset `digest`, then run `msiexec /i … /qn /norestart ENABLE_PSREMOTING=1 ADD_PATH=1` as a SYSTEM
  task. This takes about 1 minute and re-registers `PowerShell.7`. RIVSPROD02 (7.4.1) and RIVSIS02 (7.5.4)
  were upgraded to 7.6.6 this way on 2026-09-25. RIVSIS02 also has internet access.
- **The MSI is cached on the share** `\\rivsts05\Software\Dev Tools` (`PowerShell-7.6.6-win-x64.msi`, SHA-256
  `958838ff55091e1c8705d89efed0cc7e8245a3a6ef6c0ccfae20015227108ad8`, alongside 7.5.4). Prefer it to
  downloading per server: the SYSTEM task does `Copy-Item` from the UNC path, checks the hash, then runs
  msiexec. SYSTEM (the machine account) can read the share, and the task avoids the double-hop problem you would
  hit reading it as mh.admin inside `Invoke-Command`. Used on RIVMDEV01 on 2026-10-03; the task wrote a log to
  `C:\Windows\Temp` because the WinRM restart cuts off the session (expect an "I/O operation aborted" error
  while polling, then retry). For a newer pwsh, download once locally, verify against the release digest, and
  copy it to the share.
- A server that refuses with "WSMan service could not launch a host process" or a refused port 5985 needs
  `Enable-PSRemoting -Force -SkipNetworkProfileCheck` run locally (console/RDP); nothing can be done remotely.
  Check the port first with `Test-NetConnection <host> -Port 5985`.
- `Unregister-ScheduledTask` can fail with "The task XML contains a value which is incorrectly formatted or out of
  range", and `Get-ScheduledTask` for the same task fails too. With `-ErrorAction SilentlyContinue` that looks
  like "task gone" when it is not. Delete with `schtasks /delete /tn <name> /f` and verify with
  `schtasks /query /tn <name>` (RIVMDEV01, 2026-10-03).
- A leading `Start-Sleep` in a tool call is blocked by the harness. Poll with repeated plain checks instead.
- The local safety hook scans any command containing `Remove-Item` and blocks it if *any* token looks like a
  protected path: msiexec's `/i`, `/1GB`, `Get-PSDrive C`, or a variable holding a profile root. Measure in one
  call, then delete in a separate call that contains only `Remove-Item -LiteralPath` with the full literal paths.
- RIVSPROD02's `\RI Watch\Delete old log files` task calls a bare `pwsh`, so it relies on
  `C:\Program Files\PowerShell\7\` being on the machine PATH.

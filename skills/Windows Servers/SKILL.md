---
name: Windows Servers
description: Use when running commands on RI's Windows servers RIVSPROD02 (prod), RIVMIS01 or RIVSIS02 — remote PowerShell as mh.admin, or when the user says "on prod2", "on sis", "on mis".
---

# Windows Servers (PowerShell remoting)

The user's profile (`$PROFILE`, OneDrive `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) defines
interactive shortcuts: `sis` → RIVSIS02, `mis` → RIVMIS01, `prod2` → RIVSPROD02. They use
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
| `mis` | RIVMIS01 | 7.6.x | Usually the machine Claude runs on (check `$env:COMPUTERNAME`). Local commands run as matthew.heath; remote to it only when mh.admin rights are needed. |
| `sis` | RIVSIS02 | 7.6.6 | Has its own profile variant, `Microsoft.PowerShell_profile-RIVSIS02.ps1` (prompt only). C: is tight (~4.9 GB free on 2026-09-25). |

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
- The local safety hook sometimes misreads `Remove-Item` in a command that also contains msiexec's `/i`
  as deleting a system path. Do the cleanup in a separate call.
- RIVSPROD02's `\RI Watch\Delete old log files` task calls a bare `pwsh`, so it relies on
  `C:\Program Files\PowerShell\7\` being on the machine PATH.

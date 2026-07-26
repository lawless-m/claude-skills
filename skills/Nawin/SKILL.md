---
name: Nawin
description: Use when working on the Nawin .NET 9 codebase or connecting to 9front/Plan 9 over 9P2000 — serving a directory, CPU remote shell, mounting via FUSE/ProjFS, or running the auth server. Covers this repo's project layout, ports, auth protocols, and 9front test VM.
---

# Nawin

Nawin is a .NET 9 implementation of 9P2000 (clients, servers, authentication, CPU remote shell) at `/home/matt/Git/Nawin`. Run tools with `dotnet run --project Nawin.<Project> -- ...`; pass `--help` to any project for its full CLI.

## Projects (quick-ref)

| Project | Purpose | Default port |
|---------|---------|--------------|
| Nawin.Cli | Interactive 9P client (ls, cat, stat, cp, mkdir, rm, mount, shell) | connects to 564 |
| Nawin.Serve | Serve local dirs over 9P (U9FS replacement) | 564 |
| Nawin.Cpu | CPU client — remote shell with namespace export | 17010 |
| Nawin.CpuServer | Accept inbound CPU connections | 17010 |
| Nawin.Auth | Auth server (p9sk1/dp9ik); also `adduser`/`listusers` | 567 |
| Nawin.Jerq | Graphics app with /dev/draw export | — |

Mounting: `Nawin.Cli mount` uses FUSE on Linux (`-f` runs foreground) and ProjFS on Windows.

## Auth protocols

- `none` — trusted networks.
- `simple:user:pass` — plaintext username/password, simple setups.
- `p9sk1` — DES-based, original Plan 9.
- `dp9ik` — ChaCha20-Poly1305 + PBKDF2, modern 9front.

## Ports and privilege

Port 564 (9P) requires root. Prefer a high port (e.g. `-p 5640`) to avoid it. When you must use 564 under sudo, `dotnet` is not on root's PATH — use `sudo $(which dotnet) run ...` or `sudo env "PATH=$PATH" dotnet run ...`. Alternatively grant the published binary the capability: `sudo setcap 'cap_net_bind_service=+ep' <path-to-publish>/Nawin.Serve`.

The local auth server listens on **port 17019** (not the default 567). It runs as the `nawin-auth` systemd service:
```bash
sudo systemctl restart nawin-auth && sleep 2 && systemctl status nawin-auth 2>&1 | head -15
```

## Examples (one-liners)

- Serve a directory: `dotnet run --project Nawin.Serve -- -p 5640 .`
- Serve with auth: `dotnet run --project Nawin.Serve -- -p 5640 --auth simple:matt:secret /home/matt/share`
- List a 9front server: `dotnet run --project Nawin.Cli -- -H 9front.local -u glenda -p password -a dp9ik ls /`
- Remote shell: `dotnet run --project Nawin.Cpu -- --host 9front.local -u glenda -P secret --protocol dp9ik "cat /dev/sysname"`
- Mount (Linux): `dotnet run --project Nawin.Cli -- -H 9front.local -u glenda -a dp9ik mount -f /mnt/9front`

Full CLI for any tool via `--help`.

## Testing with 9front

Start the local 9front VM (barn):
```bash
/opt/isos/9front.sh
```
9front source is at `/mnt/` when `/opt/isos/9front-11321.amd64.iso` is mounted.

CPU into the local 9front via the local auth server (p9sk1 on 17019):
```bash
dotnet run --project Nawin.Cpu -- --host localhost --port 17019 --user glenda --password test1234 --protocol p9sk1 "command"
```

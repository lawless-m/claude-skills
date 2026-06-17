---
description: Launch yazi in a new alacritty window at the current session directory
model: haiku
---

Launch the `yazi` terminal file manager in a **new alacritty window**, starting in
the current working directory of this Claude session.

yazi must run in a real terminal, so it has to be spawned detached in its own
alacritty window — it cannot run inside a normal (non-TTY) tool call. Alacritty and
yazi are installed on both Windows and Linux and the alacritty invocation is
identical; only the shell used to spawn it differs.

Steps:

1. Use the current working directory of this session as the start directory.

2. Detect the platform and spawn alacritty **detached** (do not block waiting for it
   to exit), running yazi with its working directory set to that cwd:

   - **Windows** — use the PowerShell tool:
     ```powershell
     Start-Process alacritty -ArgumentList '--working-directory', "$PWD", '-e', 'yazi'
     ```

   - **Linux** — use the Bash tool:
     ```bash
     setsid alacritty --working-directory "$PWD" -e yazi >/dev/null 2>&1 &
     ```
     (If `setsid` is unavailable, fall back to `nohup alacritty --working-directory "$PWD" -e yazi >/dev/null 2>&1 &`.)

3. Confirm to the user that yazi launched and state the directory it opened in. Do not
   wait for the window to close.

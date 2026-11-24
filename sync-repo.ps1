# Git Repository Sync Script for Windows Scheduled Tasks
# This script commits local changes, pulls from remote, and pushes back
#
# A failure is written to sync-failed.txt in the repo (ignored, so not synced) and surfaced at the
# start of every Claude session by hooks/sync-status.sh; success removes it. A pull that conflicts
# is aborted rather than left half-done: on 2026-11-03 one was left mid-rebase, and every later run
# committed onto it without pushing for three weeks.

param(
    [string]$RepoPath = "$env:USERPROFILE\.claude",
    [string]$GitPath = "$env:USERPROFILE\AppData\Local\Programs\Git\bin\git.exe"
)

# Change to repository directory
try {
    Set-Location $RepoPath -ErrorAction Stop
} catch {
    Write-Error "Failed to change to repository directory: $RepoPath"
    exit 1
}

# Get current timestamp and hostname
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$hostname = $env:COMPUTERNAME
$failFile = Join-Path $RepoPath "sync-failed.txt"

Write-Host "Starting sync at $timestamp on $hostname"

# Function to run git commands
function Invoke-Git {
    param([string]$Command)
    Write-Host "Running: git $Command"
    $process = Start-Process -FilePath $GitPath -ArgumentList $Command.Split(' ') -NoNewWindow -Wait -PassThru
    return $process.ExitCode
}

function Report-Failure {
    param([string]$Message)
    Write-Warning $Message
    Set-Content -Path $failFile -Encoding utf8 -Value "$timestamp on ${hostname}: $Message"
}

# Never commit onto a rebase someone (or an earlier run) left in progress
if ((Test-Path (Join-Path $RepoPath ".git\rebase-merge")) -or (Test-Path (Join-Path $RepoPath ".git\rebase-apply"))) {
    Report-Failure "a rebase is in progress in $RepoPath, so nothing was committed. Finish or abort it by hand (git -C `"$RepoPath`" status)."
    exit 1
}

# Check for changes
Invoke-Git "add -A" | Out-Null

# Check if there are changes to commit
$status = & "$GitPath" status --porcelain
if ($status) {
    Write-Host "Changes detected, committing..."
    Invoke-Git "commit -m `"Auto-sync: Local changes from $hostname at $timestamp`"" | Out-Null
} else {
    Write-Host "No changes to commit"
}

# Pull with rebase
Write-Host "Pulling changes..."
$pullResult = Invoke-Git "pull --rebase"
if ($pullResult -ne 0) {
    # Undo the half-done rebase: the local commit stays safe on master and the next run retries.
    Invoke-Git "rebase --abort" | Out-Null
    Report-Failure "pull --rebase failed (a conflict with another machine's changes?); the rebase was aborted and local commits are kept. Resolve by hand: git -C `"$RepoPath`" pull --rebase"
    exit 1
}

# Push changes
Write-Host "Pushing changes..."
$pushResult = Invoke-Git "push"
if ($pushResult -ne 0) {
    Report-Failure "push failed; local commits are kept and the next run retries."
    exit 1
}

Remove-Item -Path $failFile -ErrorAction SilentlyContinue
Write-Host "Sync completed successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
exit 0

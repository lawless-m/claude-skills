<#
.SYNOPSIS
  Sets one Gitea repo's description, the one line the catalogue shows beside its README excerpt.

.DESCRIPTION
  Uses your own token from the User-scope GITEA_ACCESS_TOKEN variable, read fresh and never printed.
  It sends one PATCH to the repo, then reads the description back to confirm it. It changes
  nothing else, and works only on repos your token can administer.

.EXAMPLE
  pwsh -NoProfile -File Set-GiteaDescription.ps1 <owner>/<repo> "<what it does, in one line>"
#>
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Description
)
$ErrorActionPreference = 'Stop'

$Repo = $Repo.Trim()
if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { Write-Host "refused: give the repo as owner/repo, not '$Repo'"; exit 2 }
$Description = $Description.Trim()
if (-not $Description -or $Description -match '[\r\n]') { Write-Host 'refused: the description must be one non-empty line'; exit 2 }

$token = [Environment]::GetEnvironmentVariable('GITEA_ACCESS_TOKEN', 'User')
if (-not $token) { Write-Host 'GITEA_ACCESS_TOKEN is not set for this Windows user'; exit 1 }
$url = "https://dw.ramsden-international.com/gitea/api/v1/repos/$Repo"
$headers = @{ Authorization = "token $token" }

$status = 0
$before = Invoke-RestMethod $url -Headers $headers -SkipHttpErrorCheck -StatusCodeVariable status
if ($status -ne 200) { Write-Host "Gitea answered $status for ${Repo}: check the name, and that your token can see it"; exit 1 }

$body = @{ description = $Description } | ConvertTo-Json -Compress
Invoke-RestMethod $url -Method Patch -Headers $headers -ContentType 'application/json; charset=utf-8' `
    -Body ([Text.Encoding]::UTF8.GetBytes($body)) -SkipHttpErrorCheck -StatusCodeVariable status | Out-Null
if ($status -eq 403) { Write-Host "Gitea refused (403): your token cannot change $Repo's settings (it needs admin on the repo and the write:repository scope)"; exit 1 }
if ($status -ge 300) { Write-Host "Gitea answered $status to the change"; exit 1 }

$after = Invoke-RestMethod $url -Headers $headers
if ($after.description -ne $Description) { Write-Host "could not confirm: Gitea now says '$($after.description)'"; exit 1 }
"description set for ${Repo}:"
"  was: $(if ($before.description) { $before.description } else { '(empty)' })"
"  now: $($after.description)"

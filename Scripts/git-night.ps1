<#
.SYNOPSIS
  Commit on a feature branch, push it, and open a GitHub compare page.

.USAGE
  pwsh ./Scripts/git-night.ps1 -Message "What you changed" [-Force] [-NoVerify]

.NOTES
  - Stages all changes. Never stashes or force-pushes. Stops on Git errors.
  - Refuses to leave unpublished commits behind on a protected branch.
  - Commit hooks run unless -NoVerify is supplied.
  - -Force checks a clean working tree; it does not create an empty commit.
#>
param(
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
  [switch]$Force,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'
# Git exit codes are checked explicitly; diff --quiet uses 1 for changes.
$PSNativeCommandUseErrorActionPreference = $false
$Protected = @("main","master","develop")
$Remote    = "origin"

function Invoke-Git {
  & git @args
  if ($LASTEXITCODE -ne 0) {
    throw "git $($args -join ' ') failed (exit $LASTEXITCODE). No further steps were run."
  }
}

try {
  Invoke-Git rev-parse --show-toplevel | Out-Null
  $curBranch = (Invoke-Git symbolic-ref --quiet --short HEAD).Trim()
  $dirty = Invoke-Git status --porcelain
  if (-not $dirty -and -not $Force) {
    Write-Host 'Nothing to commit.'
    exit 0
  }

  # Read the configured URL, before any local insteadOf rewrite.
  $remoteUrl = (Invoke-Git config --get "remote.$Remote.url").Trim()
  if ($remoteUrl -notmatch '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$') {
    throw 'origin must be a GitHub HTTPS or SSH remote; refusing to guess a repository.'
  }
  $GitHubOwner = $Matches.owner
  $Repo = $Matches.repo

  Invoke-Git remote set-head $Remote --auto | Out-Null
  $defaultRef = (Invoke-Git symbolic-ref --short "refs/remotes/$Remote/HEAD").Trim()
  $MainBranch = $defaultRef.Substring($Remote.Length + 1)

  if ($Protected -contains $curBranch -or $curBranch -eq $MainBranch) {
    Invoke-Git fetch $Remote "refs/heads/${curBranch}:refs/remotes/$Remote/$curBranch" | Out-Host
    $ahead = [int](Invoke-Git rev-list --count "$Remote/$curBranch..HEAD")
    if ($ahead -gt 0) {
      throw "'$curBranch' has $ahead unpublished commit(s). Create a feature branch from HEAD to preserve them, then rerun."
    }
    $slug = ($Message -replace '[^a-zA-Z0-9-]+', '-').Trim('-').ToLowerInvariant()
    if (-not $slug) { $slug = 'changes' }
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).TrimEnd('-') }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 6)
    $newBranch = "feat/$stamp-$slug-$suffix"
    Invoke-Git checkout -b $newBranch "$Remote/$curBranch" | Out-Host
  } else {
    $newBranch = $curBranch
  }

  # A failed branch switch must never fall through to staging or committing.
  $activeBranch = (Invoke-Git symbolic-ref --quiet --short HEAD).Trim()
  if ($Protected -contains $activeBranch -or $activeBranch -eq $MainBranch) {
    throw "Refusing to commit on protected branch '$activeBranch'."
  }
  Invoke-Git add -A | Out-Host
  & git diff --cached --quiet
  $diffExit = $LASTEXITCODE
  if ($diffExit -eq 0) {
    Write-Host 'No staged changes.'
    exit 0
  }
  if ($diffExit -ne 1) { throw "Unable to inspect staged changes (exit $diffExit)." }

  $commitArgs = @('commit', '-m', $Message)
  if ($NoVerify) { $commitArgs += '--no-verify' }
  Invoke-Git @commitArgs | Out-Host
  Invoke-Git push -u $Remote $newBranch | Out-Host

  $baseName = [Uri]::EscapeDataString($MainBranch)
  $headName = [Uri]::EscapeDataString($newBranch)
  $prUrl = "https://github.com/$GitHubOwner/$Repo/compare/${baseName}...${headName}?expand=1"
  Write-Host "Pushed branch: $newBranch"
  Write-Host "Open a pull request: $prUrl"
  Start-Process -FilePath $prUrl
  exit 0
} catch {
  Write-Error $_ -ErrorAction Continue
  exit 1
}

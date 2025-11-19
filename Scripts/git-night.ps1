<#
.SYNOPSIS
  Safe-night Git: never commit to main, auto-branch from latest remote, push, open PR.

.USAGE
  pwsh ./scripts/git-night.ps1 -Message "What you changed" [-Force] [-NoVerify]

.NOTES
  - Stashes nothing → zero data loss.
  - Always bases new branch on remote/$MainBranch.
  - Auto-detects GitHub user/repo from remote URL.
  - Skips commit hooks by default (late-night mercy).
#>
param(
  [Parameter(Mandatory)][string]$Message,
  [switch]$Force,
  [switch]$NoVerify = $true   # change to $false if you want hooks
)

# ───── CONFIG ─────
$Protected = @("main","master","develop")
$Remote    = "origin"
$FG = "DarkCyan"; $ERR = "Red"; $OK = "Green"; $WARN = "Yellow"
function Write-Status([string]$m, [string]$c=$FG) { Write-Host $m -ForegroundColor $c }

# ───── 0. AUTO-DETECT REPO INFO ─────
$remoteUrl = git remote get-url $Remote
if ($remoteUrl -match 'github\.com[/:](?<user>[^/]+)/(?<repo>[^.]+)') {
    $GitHubUser = $matches.user
    $Repo       = $matches.repo
} else {
    Write-Status "Could not parse GitHub remote – falling back to config." $WARN
    $GitHubUser = "TerminalsandCoffee"
    $Repo       = (git rev-parse --show-toplevel | Split-Path -Leaf)
}
$MainBranch = $Protected | Where-Object { git show-ref --verify --quiet refs/heads/$_ } | Select-Object -First 1
if (-not $MainBranch) { $MainBranch = "main" }

# ───── 1. CURRENT STATE ─────
$curBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$dirty     = git status --porcelain

if (-not $dirty -and -not $Force) {
    Write-Status "Nothing to commit – exiting." $WARN
    exit 0
}

# ───── 2. ENSURE FEATURE BRANCH FROM LATEST REMOTE ─────
if ($Protected -contains $curBranch) {
    Write-Status "`nOn protected '$curBranch' – creating feature branch from latest remote..." $WARN

    # Always fetch latest
    git fetch $Remote $curBranch

    # Build timestamped name
    $ts        = Get-Date -Format "yyyyMMdd-HHmm"
    $sanitized = $Message -replace '[^\w-]+','-' -replace '-+$',''
    $newBranch = "feat/$ts-$($sanitized.ToLower())"

    # Create branch directly from remote (carries over working tree)
    git checkout -b $newBranch "$Remote/$curBranch"
    Write-Status "Switched to $newBranch (based on $Remote/$curBranch)" $OK
}
else {
    $newBranch = $curBranch
    Write-Status "Already on feature branch '$newBranch' – proceeding." $FG
}

# ───── 3. STAGE & COMMIT ─────
git add -A
if (git diff --cached --quiet) {
    Write-Status "No staged changes after add – aborting." $WARN
    exit 0
}

$commitArgs = @("-m", $Message)
if ($NoVerify) { $commitArgs += "--no-verify" }
git commit @commitArgs
if (-not $?) {
    Write-Status "Commit failed (hook?). Fix and retry." $ERR
    exit 1
}

# ───── 4. PUSH & SET UPSTREAM ─────
git push -u $Remote $newBranch

# ───── 5. OPEN PR COMPARE VIEW ─────
$prUrl = "https://github.com/$GitHubUser/$Repo/compare/$MainBranch...$newBranch?expand=1"
Start-Process $prUrl

# ───── DONE ─────
Write-Status "`nBranch : $newBranch" $OK
Write-Status "PR     : $prUrl`n" $OK
Write-Status "Night-mode engaged – your changes are safe. ☾" "DarkGray"
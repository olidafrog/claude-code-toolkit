<#
  sync.ps1 — keep this Windows machine's %USERPROFILE%\.claude\ in sync with the
  claude-code-toolkit repo. Native-Windows equivalent of scripts/sync.sh.

  REQUIRES: Developer Mode enabled (Settings > System > For developers) so PowerShell can
  create symlinks without an elevated prompt.

  What it does (idempotent, safe to run any time):
    1. git pull --rebase --autostash   (best-effort; warns and continues on failure)
    2. Symlink every tracked skill / agent / command / global file into ~\.claude\,
       backing up any real file it would replace (never deletes).
    3. Report anything real in ~\.claude\{skills,agents,commands} that ISN'T in the repo.
    4. Show git status. With `-Push "message"` it also commits & pushes.

  Usage:
    powershell -File scripts\sync.ps1
    powershell -File scripts\sync.ps1 -Push "message"
#>
param([string]$Push = "")

$ErrorActionPreference = "Stop"

$Repo        = Split-Path -Parent $PSScriptRoot
$ClaudeHome  = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }
$MachineSrc  = "machine-windows.md"    # this machine imports the Windows tooling notes
$Stamp       = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup      = Join-Path $ClaudeHome "backups\toolkit-migration-$Stamp"

$VendorSkills = @(
  "gsap-core","gsap-frameworks","gsap-performance","gsap-plugins","gsap-react",
  "gsap-scrolltrigger","gsap-timeline","gsap-utils","framer","framer-code-components","playwright-cli"
)

function Link-Item($Src, $Dst) {
  if (-not (Test-Path $Src)) { Write-Host "  skip (source missing): $Src"; return }
  $item = Get-Item $Dst -Force -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType -eq "SymbolicLink") {
    if ($item.Target -eq $Src) { return }               # already correct
    Remove-Item $Dst -Force
  } elseif ($item) {                                     # real file/dir -> back up
    $rel = $Dst.Substring($ClaudeHome.Length).TrimStart('\')
    $bdst = Join-Path $Backup $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $bdst) | Out-Null
    Move-Item $Dst $bdst
    Write-Host "  backed up $rel"
  }
  New-Item -ItemType Directory -Force -Path (Split-Path $Dst) | Out-Null
  # Windows PowerShell 5.1's `New-Item -ItemType SymbolicLink` ignores Developer Mode and
  # demands admin; `cmd mklink` honors Developer Mode and creates the link unprivileged.
  $mkFlag = if (Test-Path $Src -PathType Container) { "/D " } else { "" }
  cmd /c "mklink $mkFlag`"$Dst`" `"$Src`"" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "mklink failed for $Dst -> $Src" }
  Write-Host "  linked    $($Dst.Substring($ClaudeHome.Length).TrimStart('\'))"
}

# ---------------------------------------------------------------- 1. pull
Write-Host "==> Pulling latest from origin"
git -C $Repo pull --rebase --autostash
if ($LASTEXITCODE -ne 0) { Write-Host "  WARNING: git pull failed - continuing with local state" }

# ---------------------------------------------------------------- 2. link
Write-Host "==> Linking repo -> $ClaudeHome"
foreach ($k in "skills","agents","commands") {
  New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeHome $k) | Out-Null
}
Get-ChildItem (Join-Path $Repo "skills")   -Directory | ForEach-Object { Link-Item $_.FullName (Join-Path $ClaudeHome "skills\$($_.Name)") }
Get-ChildItem (Join-Path $Repo "agents")   -Filter *.md | ForEach-Object { Link-Item $_.FullName (Join-Path $ClaudeHome "agents\$($_.Name)") }
Get-ChildItem (Join-Path $Repo "commands") -Filter *.md | ForEach-Object { Link-Item $_.FullName (Join-Path $ClaudeHome "commands\$($_.Name)") }

Link-Item (Join-Path $Repo "global\CLAUDE.md")             (Join-Path $ClaudeHome "CLAUDE.md")
Link-Item (Join-Path $Repo "global\$MachineSrc")           (Join-Path $ClaudeHome "machine.md")
Link-Item (Join-Path $Repo "global\statusline-command.sh") (Join-Path $ClaudeHome "statusline-command.sh")

# ---------------------------------------------------------------- 3. adoption report
Write-Host "==> Local items in ~\.claude not tracked in the repo"
$untracked = $false
foreach ($k in "skills","agents","commands") {
  Get-ChildItem (Join-Path $ClaudeHome $k) -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.LinkType -eq "SymbolicLink") { return }
    if ($k -eq "skills" -and $VendorSkills -contains $_.Name) { return }
    Write-Host "  $k\$($_.Name)  (real, not in repo - move into repo\$k\ then re-run to link)"
    $script:untracked = $true
  }
}
if (-not $untracked) { Write-Host "  (none - everything is linked)" }

# ---------------------------------------------------------------- 4. status / push
Write-Host "==> Repo status"
git -C $Repo status --short

if ($Push -ne "") {
  if (git -C $Repo status --porcelain) {
    Write-Host "==> Committing & pushing"
    git -C $Repo add -A
    git -C $Repo commit -m $Push
    git -C $Repo push
  } else { Write-Host "  nothing to commit" }
} else {
  Write-Host "  (run with -Push ""message"" to commit & push these changes)"
}
Write-Host "Done."

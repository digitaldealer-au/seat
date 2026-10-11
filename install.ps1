# Digital Dealer operator seat — the one line for Windows. Open PowerShell, paste it, press Enter:
#
#   irm https://raw.githubusercontent.com/digitaldealer-au/seat/main/install.ps1 | iex
#
# What it does: fetches the GitHub tool for this one run, opens the browser so you sign in to GitHub as yourself, pulls
# the seat installer from the team repository (private; your sign-in is what lets it through) and runs it. The installer
# does everything else and records what it adds. Run the same line again any time to update; it skips what is done.
# Nothing is downloaded by hand, unzipped or unblocked, so Windows' "could not be verified" check never applies.
# Test hook: $env:DDSEAT_BOOTSTRAP_ONLY = '1' stops after the fetch and prints the installer folder.
$ErrorActionPreference = 'Stop'
$Org = 'digitaldealer-au'; $Team = 'engineering-playbook'; $Kit = 'operator-kit/seat-installer'
$GhVer = '2.102.0'                   # GitHub CLI release used only for the sign-in and the first fetch
function Say($m) { Write-Host ''; Write-Host "  $m" }
function Fail($m, $what) { Write-Host ''; Write-Host "  Stopped: $m" -ForegroundColor Red; Write-Host "  What to do: $what"; Write-Host ''; exit 2 }

Say 'Digital Dealer - operator seat'
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
$W = Join-Path $env:USERPROFILE '.dd-seat\bootstrap'
Remove-Item -LiteralPath $W -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $W | Out-Null
Say 'Fetching the GitHub tool (one-off, for the sign-in)...'
try { Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/cli/cli/releases/download/v$GhVer/gh_${GhVer}_windows_$arch.zip" -OutFile (Join-Path $W 'gh.zip') }
catch { Fail 'could not download the GitHub tool.' 'check the internet connection, then run the line again.' }
Expand-Archive -LiteralPath (Join-Path $W 'gh.zip') -DestinationPath (Join-Path $W 'gh') -Force
$gh = Join-Path $W 'gh\bin\gh.exe'

& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
  Say 'A browser opens: sign in to GitHub as YOURSELF (your own account, with its two-factor sign-in).'
  Say "If asked, choose GitHub.com, then HTTPS, then 'Login with a web browser'."
  & $gh auth login -h github.com -p https -w
  if ($LASTEXITCODE -ne 0) { Fail 'the GitHub sign-in did not finish.' 'run the line again and complete the browser step.' }
}
$who = (& $gh api user --jq .login 2>$null)
if (-not $who) { Fail 'the GitHub sign-in is not working.' 'run the line again.' }
Say "Signed in to GitHub as $who."
$tok = (& $gh auth token).Trim()
$H = @{ Authorization = "Bearer $tok"; Accept = 'application/vnd.github.raw+json'; 'User-Agent' = 'dd-seat' }

$Dest = Join-Path $env:USERPROFILE '.dd-seat\installer'
Remove-Item -LiteralPath $Dest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'assets') | Out-Null
Say 'Fetching the seat installer from the team repository...'
try { $tree = Invoke-RestMethod -UseBasicParsing -Headers $H -Uri "https://api.github.com/repos/$Org/$Team/git/trees/main?recursive=1" }
catch { Fail "could not read the team repository as $who." "your GitHub account must be in the $Org organisation (ask Andre), then run the line again." }
$blobs = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path.StartsWith("$Kit/") })
if ($blobs.Count -eq 0) { Fail 'the installer was not found in the team repository.' 'ask Andre.' }
foreach ($b in $blobs) {
  $rel = $b.path.Substring($Kit.Length + 1).Replace('/', '\')
  Invoke-WebRequest -UseBasicParsing -Headers $H -Uri "https://api.github.com/repos/$Org/$Team/git/blobs/$($b.sha)" -OutFile (Join-Path $Dest $rel)
}
Get-ChildItem -LiteralPath $Dest -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
if (-not (Test-Path (Join-Path $Dest 'start-here.ps1'))) { Fail "the installer is incomplete ($($blobs.Count) files)." "ask Andre to check $Kit in the team repository." }
Remove-Item -LiteralPath $W -Recurse -Force -ErrorAction SilentlyContinue
Say "Installer fetched ($($blobs.Count) files). Handing over to it."
if ($env:DDSEAT_BOOTSTRAP_ONLY -eq '1') { Write-Output $Dest; exit 0 }
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'start-here.ps1')
exit $LASTEXITCODE

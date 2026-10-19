#!/bin/bash
# Digital Dealer operator seat — the one line for a Mac (Terminal) or Ubuntu inside Windows (the Ubuntu window). Paste it,
# press Return:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/digitaldealer-au/seat/main/install.sh)"
#
# What it does: fetches the GitHub tool for this one run, opens the browser so you sign in to GitHub as yourself, pulls
# the seat installer from the team repository (private; your sign-in is what lets it through) and runs it. The installer
# does everything else and records what it adds. Run the same line again any time to update; it skips what is done.
# Nothing is downloaded by hand, unzipped or unblocked, so the Mac's "could not verify" check never applies.
# Test hook: DDSEAT_BOOTSTRAP_ONLY=1 stops after the fetch and prints the installer folder.
set -u
ORG="digitaldealer-au"; TEAM="engineering-playbook"; KIT="operator-kit/seat-installer"
GH_VER="2.102.0"                      # GitHub CLI release used only for the sign-in and the first fetch
[ -t 0 ] || exec </dev/tty 2>/dev/null   # the prompts read from the terminal even when the script was piped in
say() { printf '\n  %s\n' "$*"; }
fail() { printf '\n  Stopped: %s\n  What to do: %s\n\n' "$1" "$2"; exit 2; }

say "Digital Dealer — operator seat"
# The same line works in Ubuntu inside Windows (WSL), 2026-10-19.
case "$(uname -s)" in
  Darwin) KIND=macOS;;
  Linux)  grep -qsi microsoft /proc/version || fail "this line is for a Mac or Ubuntu inside Windows (WSL)." "ask Andre."
          KIND=linux;;
  *) fail "this line is for a Mac." "on Windows, open PowerShell and run the Windows line from the manual.";;
esac
case "$(uname -m)" in arm64|aarch64) ARCH=arm64;; x86_64) ARCH=amd64;; *) fail "unknown processor ($(uname -m))." "ask Andre.";; esac

W="$HOME/.dd-seat/bootstrap"; rm -rf "$W"; mkdir -p "$W"
say "Fetching the GitHub tool (one-off, for the sign-in)..."
if [ "$KIND" = macOS ]; then
  curl -fsSL -o "$W/gh.zip" "https://github.com/cli/cli/releases/download/v$GH_VER/gh_${GH_VER}_macOS_$ARCH.zip" \
    || fail "could not download the GitHub tool." "check the internet connection, then run the line again."
  unzip -q "$W/gh.zip" -d "$W" || fail "could not unpack the GitHub tool." "run the line again."
else
  curl -fsSL -o "$W/gh.tgz" "https://github.com/cli/cli/releases/download/v$GH_VER/gh_${GH_VER}_linux_$ARCH.tar.gz" \
    || fail "could not download the GitHub tool." "check the internet connection, then run the line again."
  tar -xzf "$W/gh.tgz" -C "$W" || fail "could not unpack the GitHub tool." "run the line again."
  # the sign-in page opens in the Windows browser (the link travels in a variable, never on a command line)
  if [ -z "${BROWSER:-}" ] && ! command -v wslview >/dev/null 2>&1; then
    printf '%s\n' '#!/bin/sh' 'DD_URL="$1" WSLENV="${WSLENV:+$WSLENV:}DD_URL" exec powershell.exe -NoProfile -NonInteractive -Command '"'"'Start-Process $env:DD_URL'"'" > "$W/open"
    chmod +x "$W/open"; export BROWSER="$W/open"
  fi
fi
GH="$W/gh_${GH_VER}_${KIND}_$ARCH/bin/gh"

if ! "$GH" auth status >/dev/null 2>&1; then
  say "A browser opens: sign in to GitHub as YOURSELF (your own account, with its two-factor sign-in)."
  say "If asked, choose GitHub.com, then HTTPS, then 'Login with a web browser'."
  "$GH" auth login -h github.com -p https -w || fail "the GitHub sign-in did not finish." "run the line again and complete the browser step."
fi
WHO="$("$GH" api user --jq .login 2>/dev/null)"
[ -n "$WHO" ] || fail "the GitHub sign-in is not working." "run the line again."
say "Signed in to GitHub as $WHO."

DEST="$HOME/.dd-seat/installer"; rm -rf "$DEST"; mkdir -p "$DEST/assets"
say "Fetching the seat installer from the team repository..."
LIST="$("$GH" api "repos/$ORG/$TEAM/git/trees/main?recursive=1" --jq ".tree[] | select(.type==\"blob\" and (.path|startswith(\"$KIT/\"))) | .sha + \" \" + .path" 2>/dev/null)" || LIST=""
# On a refusal (not yet in the organisation: GitHub answers 404) the tool prints the error body on stdout, so a
# non-empty answer is not proof. Every line must be "<40-hex sha> <path>"; anything else means "could not read".
printf '%s\n' "$LIST" | grep -qvE '^[0-9a-f]{40} ' && LIST=""
[ -n "$LIST" ] || fail "could not read the team repository as $WHO." "your GitHub account must be in the $ORG organisation (ask Andre), then run the line again."
N=0
while IFS= read -r line; do
  sha="${line%% *}"; path="${line#* }"; rel="${path#$KIT/}"
  "$GH" api -H "Accept: application/vnd.github.raw+json" "repos/$ORG/$TEAM/git/blobs/$sha" > "$DEST/$rel" \
    || fail "could not fetch $rel." "run the line again."
  N=$((N + 1))
done <<< "$LIST"
chmod +x "$DEST"/*.sh "$DEST"/*.command 2>/dev/null
[ -f "$DEST/start-here.sh" ] && [ -f "$DEST/dd-ui.sh" ] || fail "the installer is incomplete ($N files)." "ask Andre to check operator-kit/$KIT in the team repository."
[ "$KIND" = linux ] && [ -f "$DEST/wsl-tools.sh" ] || [ "$KIND" = macOS ] || fail "the installer does not support Ubuntu yet ($N files)." "ask Andre to check operator-kit/$KIT in the team repository."
[ "${BROWSER:-}" = "$W/open" ] && unset BROWSER   # the installer sets its own lasting one
rm -rf "$W"
say "Installer fetched ($N files). Handing over to it."
[ "${DDSEAT_BOOTSTRAP_ONLY:-}" = "1" ] && { echo "$DEST"; exit 0; }
exec bash "$DEST/start-here.sh"

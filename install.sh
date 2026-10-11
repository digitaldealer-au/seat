#!/bin/bash
# Digital Dealer operator seat — the one line for a Mac. Open Terminal, paste it, press Return:
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
case "$(uname -s)" in Darwin) ;; *) fail "this line is for a Mac." "on Windows, open PowerShell and run the Windows line from the manual.";; esac
case "$(uname -m)" in arm64) ARCH=arm64;; x86_64) ARCH=amd64;; *) fail "unknown processor ($(uname -m))." "ask Andre.";; esac

W="$HOME/.dd-seat/bootstrap"; rm -rf "$W"; mkdir -p "$W"
say "Fetching the GitHub tool (one-off, for the sign-in)..."
curl -fsSL -o "$W/gh.zip" "https://github.com/cli/cli/releases/download/v$GH_VER/gh_${GH_VER}_macOS_$ARCH.zip" \
  || fail "could not download the GitHub tool." "check the internet connection, then run the line again."
unzip -q "$W/gh.zip" -d "$W" || fail "could not unpack the GitHub tool." "run the line again."
GH="$W/gh_${GH_VER}_macOS_$ARCH/bin/gh"

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
LIST="$("$GH" api "repos/$ORG/$TEAM/git/trees/main?recursive=1" --jq ".tree[] | select(.type==\"blob\" and (.path|startswith(\"$KIT/\"))) | .sha + \" \" + .path" 2>/dev/null)"
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
rm -rf "$W"
say "Installer fetched ($N files). Handing over to it."
[ "${DDSEAT_BOOTSTRAP_ONLY:-}" = "1" ] && { echo "$DEST"; exit 0; }
exec bash "$DEST/start-here.sh"

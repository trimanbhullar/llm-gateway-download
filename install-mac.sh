#!/bin/bash
# LLM Gateway for Mac, in one step: downloads the latest version, checks it, puts it in Applications and opens it.
#   curl -fsSL https://llmgateway.orionsoft.cc/install-mac.sh | bash -s YOUR-ACCESS-KEY
# A download made here isn't marked as "from the internet" the way a browser's is, so macOS doesn't stop it.
set -u
KEY="${1:-}"
REPO="trimanbhullar/llm-gateway-download"
APP="LLM Gateway.app"
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

say "Installing LLM Gateway…"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/LLM-Gateway-Mac.zip" "https://github.com/$REPO/releases/latest/download/LLM-Gateway-Mac.zip" \
  || { say "Couldn't download LLM Gateway. Check the internet connection and try again."; exit 1; }
# the same file GitHub published: its SHA-256 matches the release's
want="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | tr ',' '\n' \
  | grep -A30 '"name": *"LLM-Gateway-Mac.zip"' | grep -m1 '"digest"' | sed 's/.*sha256:\([0-9a-f]*\).*/\1/')"
have="$(shasum -a 256 "$tmp/LLM-Gateway-Mac.zip" | cut -d' ' -f1)"
if [ -n "$want" ] && [ "$want" != "$have" ]; then say "The download didn't match the published version. Try again in a minute."; exit 1; fi

pkill -f "$APP/Contents/MacOS/" 2>/dev/null; sleep 1
ditto -x -k "$tmp/LLM-Gateway-Mac.zip" "$tmp/x" || { say "Couldn't unpack the download."; exit 1; }
dest="/Applications"; [ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
rm -rf "$dest/$APP"
ditto "$tmp/x/$APP" "$dest/$APP" || { say "Couldn't copy LLM Gateway into $dest."; exit 1; }
xattr -dr com.apple.quarantine "$dest/$APP" 2>/dev/null
say "Installed in $dest. Opening it…"

up() { curl -s -o /dev/null --max-time 2 http://127.0.0.1:8090/; }
wait_up() { for _ in $(seq 1 "$1"); do up && return 0; sleep 1; done; return 1; }
open "$dest/$APP"
if ! wait_up 40; then
  # it didn't start: try again without its menu-bar icon, the part most likely to differ on a new macOS
  log="$HOME/Library/Logs/LLM-Gateway-start.log"
  mkdir -p "$(dirname "$log")"
  pkill -f "$APP/Contents/MacOS/" 2>/dev/null; sleep 1
  # from now on the app starts without its menu-bar icon here, however it's opened
  mkdir -p "$HOME/Library/Application Support/LLM-Gateway"
  touch "$HOME/Library/Application Support/LLM-Gateway/.no-tray"
  nohup "$dest/$APP/Contents/MacOS/LLM Gateway" --no-tray >"$log" 2>&1 &
  if ! wait_up 40; then
    say "LLM Gateway didn't start on this Mac. Please send this to whoever sent you the link:"
    sw_vers 2>/dev/null
    tail -25 "$log" 2>/dev/null
    tail -15 "$HOME/Library/Application Support/LLM-Gateway/gateway.log" 2>/dev/null
    exit 1
  fi
  say "Started (without its menu-bar icon on this macOS)."
fi
if [ -n "$KEY" ]; then open "http://127.0.0.1:8090/#key=$KEY"; else open "http://127.0.0.1:8090/"; fi
say "LLM Gateway is running. Its page has opened in your browser."

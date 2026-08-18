#!/bin/bash
# Sentinel Chrome Launcher
# Uses a dedicated profile at ~/.openclaw/chrome-profile/ (NOT your system Chrome dir).
# This is required — Chrome 112+ blocks CDP on the system Chrome profile for security.
#
# LinkedIn is logged in once manually. After that it persists indefinitely.
# Gmail sign-in in this window is NOT needed — only the LinkedIn session matters.

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SENTINEL_PROFILE="$HOME/.openclaw/chrome-profile"
CDP_PORT=18800
CDP_VERSION_URL="http://localhost:$CDP_PORT/json/version"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Safety check ──────────────────────────────────────────────────────────────
if curl -s "$CDP_VERSION_URL" > /dev/null 2>&1; then
    echo ""
    echo "Sentinel Chrome is already running on CDP port $CDP_PORT."
    echo "No relaunch needed."
    echo ""
    exit 0
fi

# ── Launch Chrome ──────────────────────────────────────────────────────────────
echo "Launching Sentinel Chrome on CDP port $CDP_PORT..."
echo "Profile: $SENTINEL_PROFILE"
mkdir -p "$SENTINEL_PROFILE"

"$CHROME" \
    --remote-debugging-port=$CDP_PORT \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --user-data-dir="$SENTINEL_PROFILE" \
    --profile-directory="Default" \
    > /dev/null 2>&1 &

CHROME_PID=$!
echo "Chrome launched (PID: $CHROME_PID)"

# ── Wait for CDP ───────────────────────────────────────────────────────────────
echo "Waiting for CDP on port $CDP_PORT..."

MAX_WAIT=30
COUNT=0
until curl -s "$CDP_VERSION_URL" > /dev/null 2>&1; do
    sleep 1
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_WAIT ]; then
        echo ""
        echo "ERROR: CDP did not become available within ${MAX_WAIT}s."
        exit 1
    fi
done

echo ""
echo "Chrome is ready."
echo "  CDP port: $CDP_PORT  |  PID: $CHROME_PID  |  Waited: ${COUNT}s"
echo "  CDP endpoint: $CDP_VERSION_URL"
USER_DATA_DIR="$(curl -s "$CDP_VERSION_URL" | /usr/bin/python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("userDataDir","unknown"))' 2>/dev/null)"
echo "  Reported userDataDir: ${USER_DATA_DIR:-unknown}"
echo ""
echo "If this is first run, navigate to https://www.linkedin.com/login and log in."
echo "Then run: python3 \"$REPO_ROOT/helpers/linkedin_helper.py\" preflight"
echo ""

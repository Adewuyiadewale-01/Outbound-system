#!/bin/bash
# Second dedicated Chrome profile for the sequential Activity Check lane.
# The profile is intentionally independent from the original CDP profile.

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SENTINEL_PROFILE="$HOME/.openclaw/chrome-profile-2"
CDP_PORT=18801
CDP_VERSION_URL="http://localhost:$CDP_PORT/json/version"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if curl -s "$CDP_VERSION_URL" > /dev/null 2>&1; then
    echo "Second Activity Chrome is already running on CDP port $CDP_PORT."
    exit 0
fi

echo "Launching second Activity Chrome on CDP port $CDP_PORT..."
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
MAX_WAIT=30
COUNT=0
until curl -s "$CDP_VERSION_URL" > /dev/null 2>&1; do
    sleep 1
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_WAIT ]; then
        echo "ERROR: CDP did not become available within ${MAX_WAIT}s."
        exit 1
    fi
done

echo "Chrome is ready: port $CDP_PORT, PID $CHROME_PID."
echo "On first use, sign into the second authorized account manually, then close no windows."
echo "Verify with: LINKEDIN_CDP_PORT=$CDP_PORT python3 \"$REPO_ROOT/helpers/linkedin_helper.py\" preflight"

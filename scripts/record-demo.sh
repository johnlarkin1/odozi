#!/usr/bin/env bash
#
# record-demo.sh — Record a simulator demo video of Odyssey UI tests
#
# Usage:
#   ./scripts/record-demo.sh                    # Record demo, save locally
#   ./scripts/record-demo.sh --pr 42            # Record, upload to Dropbox, post to PR #42
#   ./scripts/record-demo.sh --tests MyTest     # Run specific test class
#   ./scripts/record-demo.sh --dropbox          # Upload to Dropbox via API
#   ./scripts/record-demo.sh --pr 42 --dropbox  # Full flow: record → Dropbox → PR comment
#
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────
PROJECT="Odyssey.xcodeproj"
SCHEME="Odyssey"
DEFAULT_TESTS="FeatureDemos"  # Marker: resolved to individual classes below
OUTPUT_DIR="$(pwd)/build/demos"
SIMULATOR_NAME="iPhone 16 Pro Max"
ENV_FILE="$(pwd)/.env"

# ── Parse arguments ────────────────────────────────────────────────────
PR_NUMBER=""
TEST_TARGET="$DEFAULT_TESTS"
USE_DROPBOX=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pr)       PR_NUMBER="$2"; USE_DROPBOX=true; shift 2 ;;
        --tests)    TEST_TARGET="$2"; shift 2 ;;
        --dropbox)  USE_DROPBOX=true; shift ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --help|-h)
            head -8 "$0" | tail -6
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────
timestamp() { date +"%Y-%m-%d_%H-%M-%S"; }

info()  { echo "▸ $*"; }
error() { echo "✗ $*" >&2; exit 1; }

cleanup() {
    if [[ -n "${RECORD_PID:-}" ]] && kill -0 "$RECORD_PID" 2>/dev/null; then
        info "Stopping recording..."
        kill -SIGINT "$RECORD_PID" 2>/dev/null || true
        wait "$RECORD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── Load .env ─────────────────────────────────────────────────────────
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

# ── Dropbox API helpers ───────────────────────────────────────────────
dropbox_get_token() {
    # Refresh the short-lived access token using the long-lived refresh token
    local response
    response=$(curl -s https://api.dropbox.com/oauth2/token \
        -d grant_type=refresh_token \
        -d "refresh_token=$DROPBOX_REFRESH_TOKEN" \
        -d "client_id=$DROPBOX_APP_KEY" \
        -d "client_secret=$DROPBOX_APP_SECRET")

    DROPBOX_ACCESS_TOKEN=$(echo "$response" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['access_token'])" 2>/dev/null) \
        || error "Failed to get Dropbox access token. Check DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_REFRESH_TOKEN in .env"

    info "Dropbox token refreshed"
}

dropbox_upload() {
    local local_path="$1"
    local remote_path="$2"
    local file_size
    file_size=$(stat -f%z "$local_path" 2>/dev/null || stat -c%s "$local_path")
    local max_simple=$((150 * 1024 * 1024))

    if [[ "$file_size" -le "$max_simple" ]]; then
        # Simple upload (< 150 MB)
        info "Uploading to Dropbox ($((file_size / 1024))KB)..."
        curl -s -X POST https://content.dropboxapi.com/2/files/upload \
            --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
            --header "Dropbox-API-Arg: {\"path\": \"$remote_path\", \"mode\": \"overwrite\", \"autorename\": true}" \
            --header "Content-Type: application/octet-stream" \
            --data-binary @"$local_path" > /dev/null
    else
        # Chunked upload (> 150 MB)
        info "Chunked upload to Dropbox ($((file_size / 1024 / 1024))MB)..."
        local chunk_size=$((148 * 1024 * 1024))
        local offset=0

        # Start session
        local session_id
        session_id=$(curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/start \
            --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
            --header "Dropbox-API-Arg: {\"close\": false}" \
            --header "Content-Type: application/octet-stream" \
            < /dev/null | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['session_id'])")

        # Upload chunks
        while [[ "$offset" -lt "$file_size" ]]; do
            local remaining=$((file_size - offset))
            local this_chunk=$chunk_size
            local close=false
            if [[ "$remaining" -le "$chunk_size" ]]; then
                this_chunk=$remaining
                close=true
            fi

            info "  Uploading chunk at offset $offset ($((this_chunk / 1024 / 1024))MB)..."
            dd if="$local_path" bs=1048576 skip=$((offset / 1048576)) count=$(( (this_chunk + 1048575) / 1048576 )) 2>/dev/null | \
                curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/append_v2 \
                    --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
                    --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$session_id\", \"offset\": $offset}, \"close\": $close}" \
                    --header "Content-Type: application/octet-stream" \
                    --data-binary @- > /dev/null

            offset=$((offset + this_chunk))
        done

        # Finish session
        curl -s -X POST https://content.dropboxapi.com/2/files/upload_session/finish \
            --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
            --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$session_id\", \"offset\": $file_size}, \"commit\": {\"path\": \"$remote_path\", \"mode\": \"overwrite\", \"autorename\": true}}" \
            --header "Content-Type: application/octet-stream" \
            < /dev/null > /dev/null
    fi

    info "Upload complete"
}

dropbox_share_link() {
    local remote_path="$1"

    # Try to create a new shared link
    local response
    response=$(curl -s -X POST https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings \
        --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{\"path\": \"$remote_path\", \"settings\": {\"requested_visibility\": \"public\"}}")

    local url
    url=$(echo "$response" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('url',''))" 2>/dev/null)

    # If link already exists, fetch it
    if [[ -z "$url" ]]; then
        url=$(curl -s -X POST https://api.dropboxapi.com/2/sharing/list_shared_links \
            --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
            --header "Content-Type: application/json" \
            --data "{\"path\": \"$remote_path\", \"direct_only\": true}" \
            | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['links'][0]['url'])" 2>/dev/null) || true
    fi

    echo "$url"
}

# ── Resolve simulator ─────────────────────────────────────────────────
UDID=$(xcrun simctl list devices available -j | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
for runtime, devs in data['devices'].items():
    for d in devs:
        if d['name'] == '$SIMULATOR_NAME' and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
") || error "Simulator '$SIMULATOR_NAME' not found. Run: make setup-simulator"

info "Using simulator: $SIMULATOR_NAME ($UDID)"

# ── Boot simulator if needed ──────────────────────────────────────────
STATE=$(xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
for runtime, devs in data['devices'].items():
    for d in devs:
        if d['udid'] == '$UDID':
            print(d['state'])
            sys.exit(0)
")

if [[ "$STATE" != "Booted" ]]; then
    info "Booting simulator..."
    xcrun simctl boot "$UDID"
    open -a Simulator
    sleep 3
fi

# ── Build app ─────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
    info "Building $SCHEME..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$UDID" \
        -derivedDataPath build \
        -quiet \
        build-for-testing 2>&1 | tail -5
fi

# ── Determine branch name for filename ────────────────────────────────
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
BRANCH_SLUG=$(echo "$BRANCH" | tr '/' '-' | tr -cd '[:alnum:]-')
TIMESTAMP=$(timestamp)
FILENAME="demo_${BRANCH_SLUG}_${TIMESTAMP}.mp4"

# ── Prepare output directory ──────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
VIDEO_PATH="$OUTPUT_DIR/$FILENAME"

# ── Override status bar for clean recording ───────────────────────────
xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4 2>/dev/null || true

# ── Start recording ──────────────────────────────────────────────────
info "Recording to: $VIDEO_PATH"
xcrun simctl io "$UDID" recordVideo --codec=h264 "$VIDEO_PATH" &
RECORD_PID=$!
sleep 1  # Give recorder time to initialize

# ── Resolve test targets ─────────────────────────────────────────────
# If using the default "FeatureDemos" marker, discover all Demo classes
# in the FeatureDemos/ directory and pass each as a separate -only-testing flag.
ONLY_TESTING_FLAGS=()
if [[ "$TEST_TARGET" == "FeatureDemos" ]]; then
    DEMO_DIR="$(pwd)/OdysseyUITests/FeatureDemos"
    while IFS= read -r classname; do
        ONLY_TESTING_FLAGS+=(-only-testing:"OdysseyUITests/$classname")
    done < <(grep -l 'class.*: FeatureDemoBase' "$DEMO_DIR"/*.swift 2>/dev/null \
        | xargs -I{} basename {} .swift)
    if [[ ${#ONLY_TESTING_FLAGS[@]} -eq 0 ]]; then
        error "No demo classes found in $DEMO_DIR"
    fi
    info "Running tests: ${ONLY_TESTING_FLAGS[*]}"
else
    ONLY_TESTING_FLAGS=(-only-testing:"$TEST_TARGET")
    info "Running tests: $TEST_TARGET"
fi

# ── Run UI tests ──────────────────────────────────────────────────────
set +e
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath build \
    "${ONLY_TESTING_FLAGS[@]}" \
    test-without-building 2>&1 | tail -20
TEST_EXIT=$?
set -e

# ── Stop recording ───────────────────────────────────────────────────
sleep 1  # Let final frames render
info "Stopping recording..."
kill -SIGINT "$RECORD_PID" 2>/dev/null || true
wait "$RECORD_PID" 2>/dev/null || true
unset RECORD_PID  # Prevent cleanup from trying again

# ── Clear status bar override ─────────────────────────────────────────
xcrun simctl status_bar "$UDID" clear 2>/dev/null || true

# ── Verify recording ─────────────────────────────────────────────────
if [[ ! -f "$VIDEO_PATH" ]]; then
    error "Recording failed — no video file produced"
fi

FILE_SIZE=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat --format=%s "$VIDEO_PATH" 2>/dev/null)
info "Recorded: $FILENAME ($(( FILE_SIZE / 1024 ))KB)"

# ── Upload to Dropbox ────────────────────────────────────────────────
SHARE_URL=""
if [[ "$USE_DROPBOX" == true ]]; then
    load_env

    # Validate credentials
    if [[ -z "${DROPBOX_APP_KEY:-}" || -z "${DROPBOX_APP_SECRET:-}" || -z "${DROPBOX_REFRESH_TOKEN:-}" ]]; then
        error "Missing Dropbox credentials. Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_REFRESH_TOKEN in .env"
    fi

    dropbox_get_token

    REMOTE_PATH="/$FILENAME"
    dropbox_upload "$VIDEO_PATH" "$REMOTE_PATH"

    SHARE_URL=$(dropbox_share_link "$REMOTE_PATH")

    if [[ -n "$SHARE_URL" ]]; then
        info "Share URL: $SHARE_URL"
    else
        info "Warning: Could not create share link"
    fi
fi

# ── Post to PR ───────────────────────────────────────────────────────
if [[ -n "$PR_NUMBER" ]]; then
    if ! command -v gh &>/dev/null; then
        error "gh CLI not found. Install: brew install gh"
    fi

    BODY="## Demo Video

**Branch:** \`$BRANCH\`
**Recorded:** $TIMESTAMP
**Tests:** \`$TEST_TARGET\`
**Test result:** $([ $TEST_EXIT -eq 0 ] && echo 'Passed' || echo 'Some failures (see test results)')

### Video
"
    if [[ -n "$SHARE_URL" ]]; then
        # Convert dl=0 to raw=1 so the video is directly viewable
        DIRECT_URL="${SHARE_URL/dl=0/raw=1}"
        BODY+="[$FILENAME]($SHARE_URL)

![]($DIRECT_URL)"
    else
        BODY+="Video saved locally: \`$VIDEO_PATH\`
> Upload manually or drag into this comment to attach."
    fi

    BODY+="

---
*Recorded with \`make demo\`*"

    gh pr comment "$PR_NUMBER" --body "$BODY"
    info "Posted demo comment to PR #$PR_NUMBER"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Demo recording complete"
echo "  Video: $VIDEO_PATH"
if [[ -n "$SHARE_URL" ]]; then
echo "  Dropbox: $SHARE_URL"
fi
if [[ -n "$PR_NUMBER" ]]; then
echo "  PR: #$PR_NUMBER commented"
fi
echo "═══════════════════════════════════════════════════"

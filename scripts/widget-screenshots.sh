#!/usr/bin/env bash
#
# widget-screenshots.sh — Render widget screenshots and optionally post to a PR
#
# Usage:
#   ./scripts/widget-screenshots.sh                    # Render screenshots locally
#   ./scripts/widget-screenshots.sh --pr 42            # Render, upload to Dropbox, post to PR
#   ./scripts/widget-screenshots.sh --dropbox          # Upload to Dropbox only
#
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────
PROJECT="Odyssey.xcodeproj"
SCHEME="Odyssey"
OUTPUT_DIR="$(pwd)/build/widget-screenshots"
SIMULATOR_NAME="iPhone 16"
ENV_FILE="$(pwd)/.env"

# ── Parse arguments ────────────────────────────────────────────────────
PR_NUMBER=""
USE_DROPBOX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pr)       PR_NUMBER="$2"; USE_DROPBOX=true; shift 2 ;;
        --dropbox)  USE_DROPBOX=true; shift ;;
        --help|-h)
            head -8 "$0" | tail -6
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────
info()  { echo "▸ $*"; }
error() { echo "✗ $*" >&2; exit 1; }

# ── Load .env ─────────────────────────────────────────────────────────
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

# ── Dropbox helpers (same as record-demo.sh) ──────────────────────────
dropbox_get_token() {
    local response
    response=$(curl -s https://api.dropbox.com/oauth2/token \
        -d grant_type=refresh_token \
        -d "refresh_token=$DROPBOX_REFRESH_TOKEN" \
        -d "client_id=$DROPBOX_APP_KEY" \
        -d "client_secret=$DROPBOX_APP_SECRET")

    DROPBOX_ACCESS_TOKEN=$(echo "$response" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['access_token'])" 2>/dev/null) \
        || error "Failed to get Dropbox access token"

    info "Dropbox token refreshed"
}

dropbox_upload() {
    local local_path="$1"
    local remote_path="$2"
    info "Uploading $(basename "$local_path")..."
    curl -s -X POST https://content.dropboxapi.com/2/files/upload \
        --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
        --header "Dropbox-API-Arg: {\"path\": \"$remote_path\", \"mode\": \"overwrite\", \"autorename\": true}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"$local_path" > /dev/null
}

dropbox_share_link() {
    local remote_path="$1"
    local response
    response=$(curl -s -X POST https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings \
        --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{\"path\": \"$remote_path\", \"settings\": {\"requested_visibility\": \"public\"}}")

    local url
    url=$(echo "$response" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('url',''))" 2>/dev/null)

    if [[ -z "$url" ]]; then
        url=$(curl -s -X POST https://api.dropboxapi.com/2/sharing/list_shared_links \
            --header "Authorization: Bearer $DROPBOX_ACCESS_TOKEN" \
            --header "Content-Type: application/json" \
            --data "{\"path\": \"$remote_path\", \"direct_only\": true}" \
            | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['links'][0]['url'])" 2>/dev/null) || true
    fi

    echo "$url"
}

# ── Resolve simulator ────────────────────────────────────────────────
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"

# ── Prepare output directory ─────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Build and run snapshot tests ──────────────────────────────────────
info "Building and running widget snapshot tests..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath build \
    -only-testing:OdysseyTests/WidgetSnapshotTests \
    test 2>&1 | tail -20

TEST_EXIT=${PIPESTATUS[0]}

# ── Collect screenshots from test output ─────────────────────────────
# Tests write to both tmp and build/widget-screenshots/
SCREENSHOT_COUNT=$(find "$OUTPUT_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
info "Generated $SCREENSHOT_COUNT screenshots in $OUTPUT_DIR"

if [[ "$SCREENSHOT_COUNT" -eq 0 ]]; then
    error "No screenshots generated. Check test output above."
fi

# ── Upload to Dropbox ────────────────────────────────────────────────
declare -A SHARE_URLS

if [[ "$USE_DROPBOX" == true ]]; then
    load_env

    if [[ -z "${DROPBOX_APP_KEY:-}" || -z "${DROPBOX_APP_SECRET:-}" || -z "${DROPBOX_REFRESH_TOKEN:-}" ]]; then
        error "Missing Dropbox credentials. Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_REFRESH_TOKEN in .env"
    fi

    dropbox_get_token

    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    BRANCH_SLUG=$(echo "$BRANCH" | tr '/' '-' | tr -cd '[:alnum:]-')

    for png in "$OUTPUT_DIR"/*.png; do
        [[ -f "$png" ]] || continue
        filename=$(basename "$png")
        remote_path="/widget-screenshots/${BRANCH_SLUG}/${filename}"
        dropbox_upload "$png" "$remote_path"
        url=$(dropbox_share_link "$remote_path")
        if [[ -n "$url" ]]; then
            SHARE_URLS["$filename"]="$url"
            info "  $filename → $url"
        fi
    done

    info "All screenshots uploaded"
fi

# ── Post to PR ───────────────────────────────────────────────────────
if [[ -n "$PR_NUMBER" ]]; then
    if ! command -v gh &>/dev/null; then
        error "gh CLI not found. Install: brew install gh"
    fi

    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

    BODY="## Widget Screenshots

**Branch:** \`$BRANCH\`
**Generated:** $(date +%Y-%m-%d\ %H:%M)

### Small Widget
| Not Logged | Mood Logged | Fully Submitted |
|:---:|:---:|:---:|"

    # Build image rows
    ROW="| "
    for state in small_not_logged small_mood_logged small_fully_submitted; do
        filename="${state}.png"
        if [[ -n "${SHARE_URLS[$filename]:-}" ]]; then
            direct_url="${SHARE_URLS[$filename]/dl=0/raw=1}"
            ROW+="![$state]($direct_url) | "
        else
            ROW+="*(local only)* | "
        fi
    done
    BODY+="
$ROW

### Medium Widget
| Not Logged | Mood Logged | Fully Submitted |
|:---:|:---:|:---:|"

    ROW="| "
    for state in medium_not_logged medium_mood_logged medium_fully_submitted; do
        filename="${state}.png"
        if [[ -n "${SHARE_URLS[$filename]:-}" ]]; then
            direct_url="${SHARE_URLS[$filename]/dl=0/raw=1}"
            ROW+="![$state]($direct_url) | "
        else
            ROW+="*(local only)* | "
        fi
    done
    BODY+="
$ROW

---
*Generated with \`make widget-screenshots\`*"

    gh pr comment "$PR_NUMBER" --body "$BODY"
    info "Posted widget screenshots to PR #$PR_NUMBER"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Widget screenshots complete"
echo "  Output: $OUTPUT_DIR"
echo "  Files:  $SCREENSHOT_COUNT PNGs"
if [[ -n "$PR_NUMBER" ]]; then
echo "  PR:     #$PR_NUMBER commented"
fi
echo "═══════════════════════════════════════════════════"

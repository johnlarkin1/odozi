#!/usr/bin/env bash
#
# appstore-assets.sh — Generate all App Store assets (iPhone + Watch screenshots, metadata)
#
# Usage:
#   ./scripts/appstore-assets.sh              # Full run (iPhone + Watch + metadata)
#   ./scripts/appstore-assets.sh --iphone     # iPhone screenshots only
#   ./scripts/appstore-assets.sh --watch      # Watch screenshots only
#   ./scripts/appstore-assets.sh --metadata   # Metadata only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/appstore-assets"
SCREENSHOTS_DIR="$PROJECT_ROOT/screenshots"

# Device names for required App Store dimensions
IPHONE_65="iPhone 11 Pro Max"    # 1242×2688 (6.5" display)
IPHONE_67="iPhone 13 Pro Max"    # 1284×2778 (6.7" display)
WATCH_DEVICE="Apple Watch Series 10 (46mm)"

WATCH_BUNDLE_ID="com.johnlarkin.Odyssey.OdysseyWatch"
WATCH_SCHEME="OdysseyWatch"
PROJECT="Odyssey.xcodeproj"

# Watch screenshot views to capture
WATCH_VIEWS=("today" "checkin" "feeling" "week" "confirmation")
WATCH_LABELS=("Today Glance" "Mood Check-In" "Feeling Picker" "Week Summary" "Confirmation")

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

log()  { echo "▸ $*"; }
warn() { echo "⚠ $*" >&2; }
err()  { echo "✘ $*" >&2; exit 1; }

ensure_simulator() {
    local name="$1"
    if xcrun simctl list devices available | grep -q "$name"; then
        log "Simulator '$name' exists"
    else
        log "Creating simulator '$name'..."
        local device_type
        # Map device name to device type identifier
        case "$name" in
            "iPhone 11 Pro Max")
                device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max" ;;
            "iPhone 13 Pro Max")
                device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro-Max" ;;
            "Apple Watch Series 10 (46mm)")
                device_type="com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-10-46mm" ;;
            *)
                err "Unknown device: $name" ;;
        esac

        # Find the latest available runtime
        local platform
        case "$name" in
            iPhone*) platform="iOS" ;;
            Apple\ Watch*) platform="watchOS" ;;
        esac

        local runtime
        runtime=$(xcrun simctl list runtimes available -j | python3 -c "
import sys, json
rts = [r for r in json.loads(sys.stdin.read())['runtimes'] if '$platform' in r['name']]
print(rts[-1]['identifier'])" 2>/dev/null) || err "No $platform runtime found"

        xcrun simctl create "$name" "$device_type" "$runtime" || err "Failed to create $name"
        log "Created simulator '$name'"
    fi
}

get_udid() {
    local name="$1"
    xcrun simctl list devices available -j | python3 -c "
import sys, json
devices = json.loads(sys.stdin.read())['devices']
for runtime, devs in devices.items():
    for d in devs:
        if d['name'] == '$name' and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)" 2>/dev/null
}

boot_simulator() {
    local name="$1"
    local udid
    udid=$(get_udid "$name") || err "Cannot find UDID for '$name'"
    xcrun simctl boot "$udid" 2>/dev/null || true
    log "Booted '$name' ($udid)"
    echo "$udid"
}

# ──────────────────────────────────────────────
# Phase 1: iPhone Screenshots (via Fastlane)
# ──────────────────────────────────────────────

do_iphone() {
    log "═══ PHASE: iPhone Screenshots ═══"

    # Ensure simulators exist
    ensure_simulator "$IPHONE_65"
    ensure_simulator "$IPHONE_67"

    # Run fastlane screenshots
    cd "$PROJECT_ROOT"
    log "Running fastlane screenshots..."
    bundle exec fastlane screenshots

    # Copy to organized output
    mkdir -p "$OUTPUT_DIR/iphone-6.5" "$OUTPUT_DIR/iphone-6.7"

    local count_65=0 count_67=0
    for f in "$SCREENSHOTS_DIR/en-US/"*.png; do
        [ -f "$f" ] || continue
        local basename
        basename=$(basename "$f")
        if [[ "$basename" == *"$IPHONE_65"* ]]; then
            local clean_name="${basename#*-}"
            cp "$f" "$OUTPUT_DIR/iphone-6.5/$clean_name"
            count_65=$((count_65 + 1))
        elif [[ "$basename" == *"$IPHONE_67"* ]]; then
            local clean_name="${basename#*-}"
            cp "$f" "$OUTPUT_DIR/iphone-6.7/$clean_name"
            count_67=$((count_67 + 1))
        fi
    done

    log "iPhone 6.5\" screenshots: $count_65"
    log "iPhone 6.7\" screenshots: $count_67"

    # Validate dimensions
    validate_iphone_dimensions
}

validate_iphone_dimensions() {
    log "Validating iPhone screenshot dimensions..."
    local ok=true

    for f in "$OUTPUT_DIR/iphone-6.5/"*.png; do
        [ -f "$f" ] || continue
        local w h
        w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
        h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
        if [[ "$w" != "1242" || "$h" != "2688" ]]; then
            warn "$(basename "$f"): ${w}×${h} (expected 1242×2688)"
            ok=false
        fi
    done

    for f in "$OUTPUT_DIR/iphone-6.7/"*.png; do
        [ -f "$f" ] || continue
        local w h
        w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
        h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
        if [[ "$w" != "1284" || "$h" != "2778" ]]; then
            warn "$(basename "$f"): ${w}×${h} (expected 1284×2778)"
            ok=false
        fi
    done

    if $ok; then
        log "✓ All iPhone screenshot dimensions valid"
    else
        warn "Some iPhone screenshots have unexpected dimensions — check above"
    fi
}

# ──────────────────────────────────────────────
# Phase 2: Watch Screenshots (via simctl io)
# ──────────────────────────────────────────────

do_watch() {
    log "═══ PHASE: Watch Screenshots ═══"

    ensure_simulator "$WATCH_DEVICE"

    # Watch simulators require a paired iPhone to stay alive.
    # Ensure at least one iPhone sim is booted and paired.
    local iphone_udid
    iphone_udid=$(xcrun simctl list devices booted -j | python3 -c "
import sys, json
devices = json.loads(sys.stdin.read())['devices']
for runtime, devs in devices.items():
    for d in devs:
        if 'iPhone' in d['name'] and d['state'] == 'Booted':
            print(d['udid'])
            sys.exit(0)
sys.exit(1)" 2>/dev/null) || true

    if [ -z "$iphone_udid" ]; then
        log "No booted iPhone found — booting $IPHONE_65 for watch pairing..."
        iphone_udid=$(boot_simulator "$IPHONE_65")
    fi

    # Boot the watch simulator
    local watch_udid
    watch_udid=$(get_udid "$WATCH_DEVICE") || err "Cannot find UDID for '$WATCH_DEVICE'"

    # Pair the watch with the iPhone (ignore error if already paired)
    xcrun simctl pair "$watch_udid" "$iphone_udid" 2>/dev/null || true

    xcrun simctl boot "$watch_udid" 2>/dev/null || true

    # Open Simulator app so the watch renders
    open -a Simulator
    sleep 3
    log "Watch simulator booted ($watch_udid), paired with iPhone ($iphone_udid)"

    # Build the watch app
    log "Building watch app..."
    cd "$PROJECT_ROOT"
    xcodebuild -project "$PROJECT" \
        -scheme "$WATCH_SCHEME" \
        -configuration Debug \
        -destination "platform=watchOS Simulator,name=$WATCH_DEVICE" \
        -derivedDataPath build \
        CODE_SIGNING_ALLOWED=NO \
        -quiet \
        build || err "Watch app build failed"

    # Find and install the built app
    local watch_app
    watch_app=$(find "$PROJECT_ROOT/build/Build/Products" -name "OdysseyWatch.app" -type d | head -1)
    [ -n "$watch_app" ] || err "Cannot find OdysseyWatch.app in build output"

    log "Installing watch app..."
    xcrun simctl install "$watch_udid" "$watch_app"

    # The watch app auto-cycles through views every 4 seconds in screenshot mode:
    #   t=0s  → today, t=4s → checkin, t=8s → feeling, t=12s → week, t=16s → confirmation
    # We launch once and capture at the right timestamps.
    local VIEW_DURATION=4
    local LAUNCH_SETTLE=3  # seconds to wait after launch before first capture

    # Capture each view
    mkdir -p "$OUTPUT_DIR/watch"

    # Terminate any running instance and launch fresh
    xcrun simctl terminate "$watch_udid" "$WATCH_BUNDLE_ID" 2>/dev/null || true
    sleep 1

    log "Launching watch app in screenshot mode..."
    SIMCTL_CHILD_SCREENSHOT_MODE=1 \
        xcrun simctl launch "$watch_udid" "$WATCH_BUNDLE_ID"

    # Wait for the app to settle after launch
    sleep "$LAUNCH_SETTLE"

    local idx=0
    for view in "${WATCH_VIEWS[@]}"; do
        local label="${WATCH_LABELS[$idx]}"

        if [ "$idx" -gt 0 ]; then
            # Wait for the view to cycle (4 seconds between each)
            sleep "$VIEW_DURATION"
        fi

        # Small extra settle time for the view to render
        sleep 1

        log "Capturing watch: $label ($view)..."
        local outfile="$OUTPUT_DIR/watch/$(printf '%02d' $((idx + 1)))_${view}.png"
        xcrun simctl io "$watch_udid" screenshot "$outfile"
        log "  → $(basename "$outfile")"

        idx=$((idx + 1))
    done

    # Terminate after last capture
    xcrun simctl terminate "$watch_udid" "$WATCH_BUNDLE_ID" 2>/dev/null || true

    log "Watch screenshots: $idx"

    # Report dimensions
    log "Watch screenshot dimensions:"
    for f in "$OUTPUT_DIR/watch/"*.png; do
        [ -f "$f" ] || continue
        local w h
        w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
        h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
        log "  $(basename "$f"): ${w}×${h}"
    done
}

# ──────────────────────────────────────────────
# Phase 3: Metadata
# ──────────────────────────────────────────────

do_metadata() {
    log "═══ PHASE: Metadata ═══"
    mkdir -p "$OUTPUT_DIR"
    cp "$SCRIPT_DIR/appstore-metadata.txt" "$OUTPUT_DIR/metadata.txt"
    log "Metadata written to appstore-assets/metadata.txt"
}

# ──────────────────────────────────────────────
# Phase 4: HTML Gallery
# ──────────────────────────────────────────────

do_gallery() {
    log "═══ PHASE: HTML Gallery ═══"

    local iphone_65_imgs="" iphone_67_imgs="" watch_imgs=""

    for f in "$OUTPUT_DIR/iphone-6.5/"*.png 2>/dev/null; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .png)
        iphone_65_imgs+="<div class='card'><img src='iphone-6.5/$(basename "$f")' /><p>$name</p></div>"$'\n'
    done

    for f in "$OUTPUT_DIR/iphone-6.7/"*.png 2>/dev/null; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .png)
        iphone_67_imgs+="<div class='card'><img src='iphone-6.7/$(basename "$f")' /><p>$name</p></div>"$'\n'
    done

    for f in "$OUTPUT_DIR/watch/"*.png 2>/dev/null; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .png)
        watch_imgs+="<div class='card watch'><img src='watch/$(basename "$f")' /><p>$name</p></div>"$'\n'
    done

    cat > "$OUTPUT_DIR/gallery.html" <<HTML
<!DOCTYPE html>
<html><head>
<title>Odozi — App Store Assets</title>
<style>
  body { background: #0a0a1a; color: #eee; font-family: -apple-system, sans-serif; padding: 40px 20px; max-width: 1400px; margin: 0 auto; }
  h1 { color: #F5A623; text-align: center; }
  h2 { color: #2EC4B6; margin-top: 48px; border-bottom: 1px solid #333; padding-bottom: 8px; }
  .grid { display: flex; flex-wrap: wrap; justify-content: center; gap: 20px; margin-top: 20px; }
  .card { background: #16213e; border-radius: 16px; padding: 12px; text-align: center; }
  .card img { height: 480px; border-radius: 8px; }
  .card.watch img { height: 240px; }
  .card p { margin-top: 8px; font-size: 13px; color: #aaa; }
  .meta { background: #16213e; border-radius: 12px; padding: 24px; margin-top: 20px; white-space: pre-wrap; font-family: monospace; font-size: 13px; line-height: 1.6; color: #ccc; }
  .dims { font-size: 11px; color: #666; margin-top: 4px; }
  .timestamp { text-align: center; color: #555; font-size: 12px; margin-top: 48px; }
</style>
</head><body>
<h1>Odozi — App Store Assets</h1>

<h2>iPhone 6.5" (1242×2688)</h2>
<div class="grid">
$iphone_65_imgs
</div>

<h2>iPhone 6.7" (1284×2778)</h2>
<div class="grid">
$iphone_67_imgs
</div>

<h2>Apple Watch</h2>
<div class="grid">
$watch_imgs
</div>

<h2>Metadata</h2>
<div class="meta">$(cat "$OUTPUT_DIR/metadata.txt" 2>/dev/null || echo "No metadata generated")</div>

<p class="timestamp">Generated $(date '+%B %d, %Y at %H:%M')</p>
</body></html>
HTML

    log "Gallery written to appstore-assets/gallery.html"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

main() {
    local do_all=true
    local run_iphone=false run_watch=false run_metadata=false

    for arg in "$@"; do
        case "$arg" in
            --iphone)   run_iphone=true; do_all=false ;;
            --watch)    run_watch=true; do_all=false ;;
            --metadata) run_metadata=true; do_all=false ;;
            --help|-h)
                echo "Usage: $0 [--iphone] [--watch] [--metadata]"
                echo "  No flags = run everything"
                exit 0 ;;
            *) err "Unknown argument: $arg" ;;
        esac
    done

    mkdir -p "$OUTPUT_DIR"

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Odozi — App Store Asset Generator      ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    if $do_all || $run_iphone; then
        do_iphone
        echo ""
    fi

    if $do_all || $run_watch; then
        do_watch
        echo ""
    fi

    if $do_all || $run_metadata; then
        do_metadata
        echo ""
    fi

    # Always generate gallery if any screenshots were taken
    do_gallery

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   ✓ Done! Assets in appstore-assets/     ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  appstore-assets/"

    if [ -d "$OUTPUT_DIR/iphone-6.5" ]; then
        echo "  ├── iphone-6.5/   $(ls "$OUTPUT_DIR/iphone-6.5/"*.png 2>/dev/null | wc -l | tr -d ' ') screenshots (1242×2688)"
    fi
    if [ -d "$OUTPUT_DIR/iphone-6.7" ]; then
        echo "  ├── iphone-6.7/   $(ls "$OUTPUT_DIR/iphone-6.7/"*.png 2>/dev/null | wc -l | tr -d ' ') screenshots (1284×2778)"
    fi
    if [ -d "$OUTPUT_DIR/watch" ]; then
        echo "  ├── watch/        $(ls "$OUTPUT_DIR/watch/"*.png 2>/dev/null | wc -l | tr -d ' ') screenshots"
    fi
    echo "  ├── metadata.txt"
    echo "  └── gallery.html  ← open in browser to review"
    echo ""
}

main "$@"

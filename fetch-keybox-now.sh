#!/bin/sh
# Fetch a fresh keybox.xml in real time and write it to the current directory.
#
# Condensed from AlwaysStrong/module/keybox_fetch.sh: the mirror serves a
# base64-encoded keybox, we decode it, sanity-check it, and atomically replace
# keybox.xml. No repo clone, no device paths, no state tracking.
#
# Set KEYBOX_BASE_URL to override the mirror (the key is served at $BASE_URL/key).
# The old Yurii0307 source can be selected with:
#   KEYBOX_BASE_URL=https://raw.githubusercontent.com/Yurii0307/yurikey/main ./fetch-keybox-now.sh
#
# Exit codes: 0 updated, 2 already up to date, 1 fetch/verify failed.

BASE_URL="${KEYBOX_BASE_URL:-http://evoker.qzz.io}"
KEY_URL="$BASE_URL/key"
TARGET="keybox.xml"
TMP="${TARGET}.tmp.$$"
DECODED="${TARGET}.dec.$$"

log() { echo "fetch-keybox: $*"; }
cleanup() { rm -f "$TMP" "$DECODED"; }
trap cleanup EXIT INT TERM

if command -v curl >/dev/null 2>&1; then
    get() { curl -fsSL --connect-timeout 10 --max-time 30 -o "$1" "$2"; }
elif command -v wget >/dev/null 2>&1; then
    get() { wget -q -T 15 -O "$1" "$2"; }
else
    log "need curl or wget to fetch the keybox"
    exit 1
fi

if ! get "$TMP" "$KEY_URL" || [ ! -s "$TMP" ]; then
    log "download failed ($KEY_URL)"
    exit 1
fi

if ! base64 -d < "$TMP" > "$DECODED" 2>/dev/null; then
    log "base64 decode failed"
    exit 1
fi
if [ ! -s "$DECODED" ]; then
    log "decoded payload is empty"
    exit 1
fi
if ! head -c 4096 "$DECODED" | grep -q "Keybox"; then
    log "decoded payload does not look like a keybox — discarding"
    exit 1
fi

if [ -f "$TARGET" ] && cmp -s "$DECODED" "$TARGET"; then
    log "already up to date"
    exit 2
fi

mv -f "$DECODED" "$TARGET" || { log "could not write $TARGET"; exit 1; }
log "wrote $TARGET ($(wc -c < "$TARGET") bytes)"
exit 0

#!/bin/sh

# usage: ./autopif.sh [--bluejay]
#   --bluejay  fetch only the bluejay (Pixel 6a) fingerprint, no random beta pick

CURRENT_DIR="$(pwd)"
TEMPDIR="$CURRENT_DIR/playintegrityfix_temp"
BLUEJAY=0

for arg in "$@"; do
    case "$arg" in
        --bluejay) BLUEJAY=1 ;;
        *) echo "Unknown option: $arg" ; exit 1 ;;
    esac
done

mkdir -p "$TEMPDIR"
cd "$TEMPDIR" || exit 1

download_fail() {
    dl_domain=$(echo "$1" | awk -F[/:] '{print $4}')
    rm -rf "$TEMPDIR"
    echo "[!] Download failed: $1 ($dl_domain)"
    exit 1
}

download() { curl --connect-timeout 10 -s "$1" > "$2" || download_fail "$1"; }

set_random_beta() {
    if [ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ]; then
        MODEL="Pixel 6"
        PRODUCT="oriole_beta"
    else
        count=$(echo "$MODEL_LIST" | wc -l)
        rand_index=$(( $$ % count ))
        MODEL=$(echo "$MODEL_LIST" | sed -n "$((rand_index + 1))p")
        PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "$((rand_index + 1))p")
    fi
}

# Get latest Pixel Canary information
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML
LATEST_URL=$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1)
download "$LATEST_URL" PIXEL_LATEST_HTML

# Get FI information
FI_URL="https://developer.android.com$(grep -o 'href=".*download.*"' PIXEL_LATEST_HTML | grep 'qpr' | cut -d\" -f2 | head -n1)"
download "$FI_URL" PIXEL_FI_HTML

# Extract device information
MODEL_LIST="$(grep -A1 'tr id=' PIXEL_FI_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>.*;\1;')"
PRODUCT_LIST="$(grep 'tr id=' PIXEL_FI_HTML | sed 's;.*<tr id="\(.*\)">.*;\1_beta;')"

if [ "$BLUEJAY" -eq 1 ]; then
    PRODUCT="bluejay_beta"
    MODEL="Pixel 6a"
elif [ -z "$PRODUCT" ] || ! echo "$PRODUCT_LIST" | grep -q "$PRODUCT"; then
    set_random_beta
fi

# Define required variables for new JSON format
DEVICE="$(echo "$PRODUCT" | sed 's/_beta//')"
BRAND="google"
MANUFACTURER="Google"
# FIRST_API_LEVEL is carried over from the shipped pif.json - never hardcoded here
if [ -z "$FIRST_API_LEVEL" ] && [ -f "$CURRENT_DIR/pif.json" ]; then
    FIRST_API_LEVEL=$(grep -o '"FIRST_API_LEVEL"[[:space:]]*:[[:space:]]*"[^"]*"' "$CURRENT_DIR/pif.json" | head -n1 | sed 's/.*:[[:space:]]*"\(.*\)"$/\1/')
fi
[ -z "$FIRST_API_LEVEL" ] && FIRST_API_LEVEL="32"

# Get device fingerprint and security patch
download https://flash.android.com PIXEL_FLASH_HTML
FLASH_KEY=$(grep -o '<body data-client-config=.*' PIXEL_FLASH_HTML | cut -d\; -f2 | cut -d\& -f1)

curl --connect-timeout 10 -H "Referer: https://flash.android.com" -s "https://content-flashstation-pa.googleapis.com/v1/builds?product=$PRODUCT&key=$FLASH_KEY" > PIXEL_STATION_JSON || download_fail "https://flash.android.com"

tac PIXEL_STATION_JSON | grep -m1 -A13 '"canary": true' > PIXEL_CANARY_JSON
ID="$(grep 'releaseCandidateName' PIXEL_CANARY_JSON | cut -d\" -f4)"
INCREMENTAL="$(grep 'buildId' PIXEL_CANARY_JSON | cut -d\" -f4)"
FINGERPRINT="$BRAND/$PRODUCT/$DEVICE:CANARY/$ID/$INCREMENTAL:user/release-keys"

download https://source.android.com/docs/security/bulletin/pixel PIXEL_SECBULL_HTML
CANARY_ID="$(grep '"id"' PIXEL_CANARY_JSON | sed -e 's;.*canary-\(.*\)".*;\1;' -e 's;^\(.\{4\}\);\1-;')"
SECURITY_PATCH="$(grep "<td>$CANARY_ID" PIXEL_SECBULL_HTML | sed 's;.*<td>\(.*\)</td>;\1;')"

if [ -z "$ID" ] || [ -z "$INCREMENTAL" ]; then
    echo "[!] Failed to get fingerprint data"
    cd "$CURRENT_DIR" || exit 1
    rm -rf "$TEMPDIR"
    exit 1
fi

if [ -z "$SECURITY_PATCH" ]; then
    SECURITY_PATCH="${CANARY_ID}-05"
fi

cat <<EOF > "$CURRENT_DIR/pif.json"
{
  "MANUFACTURER": "$MANUFACTURER",
  "BRAND": "$BRAND",
  "DEVICE": "$DEVICE",
  "PRODUCT": "$PRODUCT",
  "MODEL": "$MODEL",
  "FINGERPRINT": "$FINGERPRINT",
  "SECURITY_PATCH": "$SECURITY_PATCH",
  "FIRST_API_LEVEL": "$FIRST_API_LEVEL"
}
EOF

cd "$CURRENT_DIR" || exit 1
rm -rf "$TEMPDIR"

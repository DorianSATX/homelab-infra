#!/bin/bash
set -e
OUTDIR=/opt/paperless_data/consume
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

DEVICE=$(scanimage -L | grep -o 'epjitsu:libusb:[0-9]*:[0-9]*' | head -1)
if [ -z "$DEVICE" ]; then
    echo "No scanner found" >&2
    exit 1
fi

scanimage -d "$DEVICE" --source "ADF Duplex" --mode Color --resolution 300 --format=jpeg \
  --batch="$TMPDIR/page%d.jpeg" --batch-count=-1

if ls "$TMPDIR"/page*.jpeg >/dev/null 2>&1; then
    img2pdf "$TMPDIR"/page*.jpeg -o "$OUTDIR/scan_$(date +%Y%m%d_%H%M%S).pdf"
fi

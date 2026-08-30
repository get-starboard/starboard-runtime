#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Starboard mount wrapper — injected as /bin/mount inside proot.
#
# proot runs in userspace and cannot perform real kernel mounts, so any port
# script that calls `mount` would fail. This wrapper intercepts those calls:
#
#   - squashfs sources  → extracted with unsquashfs into the destination dir
#   - everything else   → silently succeed (proc, dev, tmpfs, etc. — proot
#                         already fakes these; we just need to not abort)
#
# mount's argument order is always: [flags...] <source> <destination>
# so we grab the last two positional args regardless of what flags precede them.

[ $# -lt 2 ] && exit 0

SRC="${@: -2:1}"   # second-to-last arg = source
DST="${@: -1}"     # last arg           = destination

[ -z "$SRC" ] && exit 0

# --- Squashfs detection (two methods) ---

IS_SQ=0

# Method 1: file extension
case "$SRC" in
    *.squashfs|*.sqsh|*.sfs) IS_SQ=1 ;;
esac

# Method 2: magic bytes (for squashfs files with non-standard extensions).
# Squashfs magic is 0x73717368 ("sqsh") or 0x68737173 ("hsqs") depending on
# endianness. We read 4 bytes and compare as hex.
if [ "$IS_SQ" = "0" ] && [ -f "$SRC" ]; then
    MAGIC=$(od -A n -N 4 -t x1 "$SRC" 2>/dev/null | tr -d ' \n')
    if [ "$MAGIC" = "68737173" ] || [ "$MAGIC" = "73717368" ]; then
        IS_SQ=1
    fi
fi

# --- Squashfs handling ---

if [ "$IS_SQ" = "1" ]; then
    # We track which squashfs was last extracted here via a sentinel file.
    # This lets us skip re-extraction on subsequent runs (idempotent).
    SENTINEL="$DST/.starboard_squashfs_src"
    SRC_NAME="$(basename "$SRC")"

    NEED_EXTRACT=1
    if [ -f "$SENTINEL" ] && [ "$(cat "$SENTINEL" 2>/dev/null)" = "$SRC_NAME" ]; then
        # Already extracted from the same squashfs — nothing to do.
        NEED_EXTRACT=0
    fi

    if [ "$NEED_EXTRACT" = "1" ]; then
        echo "[Starboard] Extracting squashfs $SRC -> $DST" >&2
        rm -rf "$DST"
        unsquashfs -d "$DST" "$SRC" >&2
        # Record which squashfs we extracted so we can detect stale extractions.
        echo "$SRC_NAME" > "$SENTINEL"
    fi
fi

# Always exit 0 — non-squashfs mounts are silently accepted so port scripts
# don't abort on mounts we don't need to handle (proot takes care of them).
exit 0

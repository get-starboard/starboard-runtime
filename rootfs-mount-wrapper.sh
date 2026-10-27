#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Starboard mount wrapper, installed as /usr/local/bin/mount in the rootfs.
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

log() { echo "[Starboard] mount: $*" >&2; }

[ $# -lt 2 ] && { log "too few args ($#) — nothing to do"; exit 0; }

SRC="${@: -2:1}"   # second-to-last arg = source
DST="${@: -1}"     # last arg           = destination

[ -z "$SRC" ] && { log "empty source — nothing to do"; exit 0; }

IS_SQ=0
case "$SRC" in
    *.squashfs|*.sqsh|*.sfs) IS_SQ=1 ;;
esac

# Magic bytes, for squashfs files with other extensions: "hsqs" or "sqsh" by endianness.
if [ "$IS_SQ" = "0" ] && [ -f "$SRC" ]; then
    MAGIC=$(od -A n -N 4 -t x1 "$SRC" 2>/dev/null | tr -d ' \n')
    if [ "$MAGIC" = "68737173" ] || [ "$MAGIC" = "73717368" ]; then
        IS_SQ=1
    fi
fi

# --- Squashfs handling ---

if [ "$IS_SQ" = "1" ]; then
    # Names the squashfs last extracted here, so a re-run skips extraction.
    SENTINEL="$DST/.starboard_squashfs_src"
    SRC_NAME="$(basename "$SRC")"

    NEED_EXTRACT=1
    if [ -f "$SENTINEL" ] && [ "$(cat "$SENTINEL" 2>/dev/null)" = "$SRC_NAME" ]; then
        NEED_EXTRACT=0
    fi

    if [ "$NEED_EXTRACT" = "0" ]; then
        log "$SRC_NAME already extracted at $DST — skipping"
        exit 0
    fi

    log "extracting $SRC -> $DST"
    rm -rf "$DST"
    if ! unsquashfs -d "$DST" "$SRC" >&2; then
        # Clear the directory and leave no sentinel, or a partial extraction
        # reads as complete on every later launch.
        log "unsquashfs FAILED for $SRC_NAME — removing $DST so the next launch retries"
        rm -rf "$DST"
        exit 1
    fi
    echo "$SRC_NAME" > "$SENTINEL"
    log "extracted $SRC_NAME to $DST"
    exit 0
fi

# Non-squashfs mounts succeed so port scripts don't abort on mounts proot
# already handles.
log "not a squashfs, ignoring: $SRC -> $DST"
exit 0

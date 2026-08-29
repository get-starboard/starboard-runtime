#!/bin/bash
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
#
# Every decision is logged. A silent wrapper makes "runtime already extracted",
# "not a squashfs" and "never called" indistinguishable in game.log, which is
# the first thing you need to tell apart when a port fails to find its runtime.

log() { echo "[Starboard] mount: $*" >&2; }

[ $# -lt 2 ] && { log "too few args ($#) — nothing to do"; exit 0; }

SRC="${@: -2:1}"   # second-to-last arg = source
DST="${@: -1}"     # last arg           = destination

[ -z "$SRC" ] && { log "empty source — nothing to do"; exit 0; }

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

    if [ "$NEED_EXTRACT" = "0" ]; then
        log "$SRC_NAME already extracted at $DST — skipping"
        exit 0
    fi

    log "extracting $SRC -> $DST"
    rm -rf "$DST"
    if ! unsquashfs -d "$DST" "$SRC" >&2; then
        # Leave no sentinel: a partial extraction (ENOSPC, interrupted write)
        # otherwise reads as complete forever after, and every later launch
        # skips it — the port then fails on a missing binary with nothing in
        # the log to say why. Clearing the directory forces a clean retry.
        log "unsquashfs FAILED for $SRC_NAME — removing $DST so the next launch retries"
        rm -rf "$DST"
        exit 1
    fi
    echo "$SRC_NAME" > "$SENTINEL"
    log "extracted $SRC_NAME to $DST"
    exit 0
fi

# Non-squashfs mounts still succeed so port scripts don't abort on mounts we
# don't need to handle (proot takes care of them) — but they say so in the log.
log "not a squashfs, ignoring: $SRC -> $DST"
exit 0

# starboard-runtime

[![Latest release](https://img.shields.io/github/v/release/get-starboard/starboard-runtime?label=release)](https://github.com/get-starboard/starboard-runtime/releases/latest)

Runtime distribution for [Starboard](https://github.com/get-starboard/starboard) — an Android app that runs PortMaster Linux games on ARM64 handhelds via proot.

This repo hosts the Debian ARM64 rootfs that Starboard downloads and extracts on first launch. The rootfs provides the glibc + SDL2 + Mesa environment that PortMaster ports expect.

## Download

The latest rootfs is published as a GitHub Release asset:

```
https://github.com/get-starboard/starboard-runtime/releases/latest/download/starboard-rootfs.tar.gz
```

The Starboard app downloads this automatically on first launch (~200 MB compressed, ~400 MB extracted).

Releases are tagged `starboard-rootfs-YYYYMMDD.N`, and the newest is always available via the `releases/latest/download/` URL above.

## Contents

- Debian bookworm-slim ARM64 base
- SDL2 family, Python 3, Mesa/OSMesa, OpenAL, common media libs
- Love2D 11.5 runtime
- gmloadernext binary (for GameMaker ports)

## Version metadata

Each rootfs carries `/etc/starboard-release`, which the app reads and surfaces in its Settings screen:

```
release=starboard-rootfs-YYYYMMDD.N
commit=<source commit sha>
built=<ISO 8601 build timestamp>
```

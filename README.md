# starboard-runtime

[![Latest release](https://img.shields.io/github/v/release/get-starboard/starboard-runtime?label=release)](https://github.com/get-starboard/starboard-runtime/releases/latest)

Runtime distribution for [Starboard](https://github.com/get-starboard/starboard) — an Android app that runs PortMaster Linux games on ARM64 handhelds via proot.

This repo hosts the Debian ARM64 rootfs that Starboard downloads and extracts on first launch. The rootfs provides the glibc + SDL2 + Mesa environment that PortMaster ports expect. It is published here automatically by CI from a private source repo.

## Download

The latest rootfs is published as a GitHub Release asset:

```
https://github.com/get-starboard/starboard-runtime/releases/latest/download/starboard-rootfs.tar.gz
```

The Starboard app downloads this automatically on first launch (~200 MB compressed, ~400 MB extracted).

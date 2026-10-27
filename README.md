# starboard-runtime

[![Build](https://github.com/get-starboard/starboard-runtime/actions/workflows/rootfs.yml/badge.svg)](https://github.com/get-starboard/starboard-runtime/actions/workflows/rootfs.yml)
[![Latest release](https://img.shields.io/github/v/release/get-starboard/starboard-runtime?label=release)](https://github.com/get-starboard/starboard-runtime/releases/latest)

Runtime distribution for [Starboard](https://github.com/get-starboard/starboard) — an Android app that runs PortMaster Linux games on ARM64 handhelds via proot.

CI builds the Debian ARM64 rootfs here and publishes it as a release of this repo, which the Starboard app downloads and extracts on first launch. The rootfs provides the glibc + SDL2 + Mesa environment that PortMaster ports expect.

## Download

The latest rootfs is published as a GitHub Release asset:

```
https://github.com/get-starboard/starboard-runtime/releases/latest/download/starboard-rootfs.tar.gz
```

The Starboard app downloads this automatically on first launch (~600 MB compressed, ~1.3 GB extracted).

Releases are tagged `starboard-rootfs-YYYYMMDD.N`, and the newest is always available via the `releases/latest/download/` URL above.

## Contents

- Debian bookworm-slim ARM64 base
- SDL2 family, Python 3, Mesa/OSMesa, OpenAL, common media libs
- `/opt/sb-mesa`: the GPU-mode GL stack. Mesa 26.2.4 with virgl, Zink, llvmpipe
  (LLVM linked in) and Turnip, built by [get-starboard/starboard-third-party](https://github.com/get-starboard/starboard-third-party)
  (`mesa/`, release `mesa-26.2.4-sb2`) and pinned in the Dockerfile by SHA-256, plus
  Debian's GLVND, Vulkan loader and `eglinfo`/`es2_info`
- `/opt/sb-virgl`: the older GPU-mode payload (Debian's Mesa 22.3.6), kept for app
  versions that predate `/opt/sb-mesa`
- Love2D 11.5 runtime
- gmloadernext binary (for GameMaker ports)
- squashfs mount intercept wrapper

See [Dockerfile](Dockerfile) for the full package list and build steps.

## Version metadata

Each rootfs carries `/etc/starboard-release`, which the app reads and surfaces in its Settings screen:

```
release=starboard-rootfs-YYYYMMDD.N
commit=<source commit sha>
built=<ISO 8601 build timestamp>
```

## Building locally

Requires Docker with ARM64/QEMU support.

```bash
# Enable ARM64 emulation if needed (one-time)
docker run --privileged --rm tonistiigi/binfmt --install arm64

# Build
bash build-rootfs.sh
```

Output: `rootfs.tar.gz` in the repo root.

## CI

Any push to `main` (except README-only changes) triggers a build. Each successful build creates a new versioned release tagged `starboard-rootfs-YYYYMMDD.N` and publishes it as this repo's latest release. Pull request builds are uploaded as a workflow artifact for device testing and never published.

The `announce` job then posts the new release to the Starboard Discord. It only runs for builds of `main` that created a release. Builds of other branches never publish or post. If the post fails, "Re-run failed jobs" retries only the post. "Re-run all jobs" publishes and announces a new `.N` release. The webhook URL is the `DISCORD_RELEASE_WEBHOOK_URL` repo secret.

## Licensing

This repository's own contents — the `Dockerfile`, `build-rootfs.sh` and
`rootfs-mount-wrapper.sh` — are GPL-3.0-or-later, matching the Starboard app.

The rootfs it produces also carries third-party binaries, each redistributed
unmodified with its upstream licence alongside it:

| Path | Licence | Notes |
|---|---|---|
| `runtimes/gmloadernext` | GPL-2.0-only | GMLoader-Next, the GameMaker runtime. `SOURCE.txt` names the upstream repository and build commit; `THIRD_PARTY_NOTICES.txt` covers the libraries compiled into it |
| `runtimes/love_11.5` | zlib | LÖVE |
| `opt/sb-mesa` (Mesa's files) | MIT, with some files under other permissive licences | Starboard's build of Mesa 26.2.4, unmodified source, with LLVM 19 (Apache-2.0 with LLVM exceptions) linked into `libgallium`. `opt/sb-mesa/licenses/` and `SOURCE.txt` give the licence, source tarball and SHA-256, and build options. The Vulkan loader (`libvulkan.so.1`, Apache-2.0) and GLVND (MIT-style) beside it are Debian's |
| `tools/gmtoolkit` | GPL-3.0-or-later (combined) | Offline GameMaker data-file converter. Mixed-licensed upstream: MIT, MPL-2.0 and GPL-3.0-or-later subtrees. `SOURCE.txt` names the upstream repository and build commit, as GPLv3 §6 requires |

Everything else in the image comes from Debian packages under their own
licences. The binaries are invoked over a process boundary (argv, exit codes),
not linked, so they and the scripts that call them remain independently
licensed — "mere aggregation" under GPLv3 §5.

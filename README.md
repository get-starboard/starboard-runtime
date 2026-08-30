# starboard-runtime

[![Build](https://github.com/davestephens/starboard-runtime/actions/workflows/rootfs.yml/badge.svg)](https://github.com/davestephens/starboard-runtime/actions/workflows/rootfs.yml)
[![Latest release](https://img.shields.io/github/v/release/get-starboard/starboard-runtime?label=release)](https://github.com/get-starboard/starboard-runtime/releases/latest)

Runtime distribution for [Starboard](https://github.com/get-starboard/starboard) — an Android app that runs PortMaster Linux games on ARM64 handhelds via proot.

This is the private source repo: CI builds the Debian ARM64 rootfs here and publishes the release to the public [get-starboard/starboard-runtime](https://github.com/get-starboard/starboard-runtime) repo, which the Starboard app downloads and extracts on first launch. The rootfs provides the glibc + SDL2 + Mesa environment that PortMaster ports expect.

## Download

The latest rootfs is published as a GitHub Release asset:

```
https://github.com/get-starboard/starboard-runtime/releases/latest/download/starboard-rootfs.tar.gz
```

The Starboard app downloads this automatically on first launch (~200 MB compressed, ~400 MB extracted).

## Contents

- Debian bookworm-slim ARM64 base
- SDL2 family, Python 3, Mesa/OSMesa, OpenAL, common media libs
- Love2D 11.5 runtime
- gmloadernext binary (for GameMaker ports)
- squashfs mount intercept wrapper

See [Dockerfile](Dockerfile) for the full package list and build steps.

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

Any push to `main` (except README-only changes) triggers a build. Each successful build creates a new versioned release tagged `starboard-rootfs-YYYYMMDD.N` and publishes it as the latest release on the public [get-starboard/starboard-runtime](https://github.com/get-starboard/starboard-runtime) repo (via the `RELEASE_REPO_TOKEN` fine-grained PAT).

## Licensing

This repository's own contents — the `Dockerfile`, `build-rootfs.sh` and
`rootfs-mount-wrapper.sh` — are GPL-3.0-or-later, matching the Starboard app.

The rootfs it produces also carries third-party binaries under `runtimes/`,
each redistributed unmodified with its upstream licence alongside it:

| Runtime | Licence | Notes |
|---|---|---|
| `gmloadernext` | GPL-2.0 | GMLoader-Next, the GameMaker runtime |
| `gmtoolkit` | GPL-3.0-or-later (combined) | Offline GameMaker data-file converter. Mixed-licensed upstream: MIT, MPL-2.0 and GPL-3.0-or-later subtrees. `SOURCE.txt` names the upstream repository and build commit, as GPLv3 §6 requires |
| `love_11.5` | zlib | LÖVE |

Everything else in the image comes from Debian packages under their own
licences. The binaries are invoked over a process boundary (argv, exit codes),
not linked, so they and the scripts that call them remain independently
licensed — "mere aggregation" under GPLv3 §5.

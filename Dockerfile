# Starboard Linux runtime rootfs — Debian bookworm-slim ARM64
#
# Provides the glibc + SDL2 environment that PortMaster ports expect.
# Built for arm64/v8a; extracted by the app on first launch via EngineSetupRepository.
#
# Build + export:
#   bash build-rootfs.sh

# ---------------------------------------------------------------------------
# Fetch Starboard's Mesa build for /opt/sb-mesa
#
# Built by get-starboard/starboard-third-party (mesa/) and pinned here by SHA-256; its
# drivers are listed in /opt/sb-mesa/DRIVERS. This stage runs natively, without emulation.
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS sb-mesa-fetch
ARG SB_MESA_TAG=mesa-26.2.4-sb2
ARG SB_MESA_SHA256=15e9d58ca404394ee9f616919b36fbcb9ff3912570483de92fda9920688ac424
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl ca-certificates xz-utils && \
    curl -fsSL --retry 3 -o /tmp/sb-mesa.tar.xz \
        "https://github.com/get-starboard/starboard-third-party/releases/download/${SB_MESA_TAG}/${SB_MESA_TAG}-aarch64.tar.xz" && \
    echo "${SB_MESA_SHA256}  /tmp/sb-mesa.tar.xz" | sha256sum -c - && \
    mkdir /out && tar -xJf /tmp/sb-mesa.tar.xz -C /out

# ---------------------------------------------------------------------------
# Build libjpeg-turbo with the JPEG 8 ABI
#
# Many PortMaster ports link against libjpeg.so.8 and require LIBJPEG_8.0
# versioned symbols.  Debian only ships the 6.2 ABI (libjpeg62-turbo); the
# 8-ABI variant must be compiled explicitly with -DWITH_JPEG8=1.
# ---------------------------------------------------------------------------
FROM --platform=linux/arm64 debian:bookworm-slim AS libjpeg8-builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        cmake build-essential nasm wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Same source version as Debian Bookworm's libjpeg62-turbo (2.1.5).
RUN wget -q https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/2.1.5.1/libjpeg-turbo-2.1.5.1.tar.gz && \
    tar xzf libjpeg-turbo-2.1.5.1.tar.gz && \
    cmake -S libjpeg-turbo-2.1.5.1 -B /build \
        -DWITH_JPEG8=1 \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DENABLE_STATIC=FALSE && \
    cmake --build /build -j$(nproc)

# ---------------------------------------------------------------------------
# Main rootfs
# ---------------------------------------------------------------------------
FROM --platform=linux/arm64 debian:bookworm-slim

# Core runtime packages for PortMaster ports:
#   - SDL2 and companion libs  (video/audio/input)
#   - Python 3                 (Python-based ports)
#   - Common media/image libs  (ogg, vorbis, opus, mpg123, flac, png, jpeg)
#   - speexdsp                 (audio resampling)
#   - Mesa / OSMesa            (the CPU GL path)
#   - curl                     (some ports self-update or fetch assets)
#   - Xvfb, matchbox, libXtst  (Westonpack games: Starboard runs them on a
#                               virtual X server with a window manager that
#                               fills the screen; libXtst replays input)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libsdl2-2.0-0 \
        libsdl2-image-2.0-0 \
        libsdl2-mixer-2.0-0 \
        libsdl2-ttf-2.0-0 \
        libsdl2-net-2.0-0 \
        libsdl1.2debian \
        python3 \
        python3-sdl2 \
        libogg0 \
        libvorbis0a \
        libopusfile0 \
        libflac12 \
        libmpg123-0 \
        libpng16-16 \
        libjpeg62-turbo \
        zlib1g \
        libopenal1 \
        libsndfile1 \
        libspeexdsp1 \
        libwebp7 \
        libtheora0 \
        libfontconfig1 \
        libcairo2 \
        curl \
        ca-certificates \
        unzip \
        libgl1 \
        libegl1 \
        libegl-mesa0 \
        libgl1-mesa-dri \
        libgles2 \
        libglu1-mesa \
        libosmesa6 \
        squashfs-tools \
        7zip \
        xdelta3 \
        zip \
        libevdev2 \
        procps \
        binutils \
        retroarch \
        xvfb \
        matchbox-window-manager \
        libxtst6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# retroarch has no cores: ports bundle their core and pass it with -L. Its config
# goes to ~/.config/retroarch, in the app's home dir (bound at /home/user).

# Install the JPEG 8 ABI library built above.
# libjpeg62-turbo (above) provides libjpeg.so.62 / LIBJPEG_6.2.
# This adds libjpeg.so.8 / LIBJPEG_8.0 for ports that require it.
COPY --from=libjpeg8-builder /build/libjpeg.so.8* /usr/lib/aarch64-linux-gnu/

RUN ldconfig && \
    ln -sf /usr/lib/aarch64-linux-gnu/dri /usr/lib/dri && \
    ln -sf libdrm.so.2 /usr/lib/aarch64-linux-gnu/libdrm.so && \
    ln -sf libEGL.so.1 /usr/lib/aarch64-linux-gnu/libEGL.so

# Packages not in bookworm pulled from adjacent Debian releases.
# Each block adds the repo at a specific priority, installs only what's needed,
# then removes the repo so subsequent apt commands stay on bookworm.

# Debian 11 (bullseye) — packages removed or replaced in bookworm:
#   libssl1.1 / libcrypto.so.1.1  — bookworm ships OpenSSL 3 only
#   FFmpeg 4.x / libavcodec.so.58 — bookworm ships FFmpeg 5.x (.so.59)
#   libflac8                       — bookworm ships libflac12
#   libzip4 / libzip.so.4          — bookworm ships libzip5 only; gmloadernext builds that
#                                    ports bundle link against libzip.so.4
RUN echo 'deb [arch=arm64] https://archive.debian.org/debian bullseye main' \
        > /etc/apt/sources.list.d/bullseye.list && \
    printf 'Package: *\nPin: release n=bullseye\nPin-Priority: 100\n' \
        > /etc/apt/preferences.d/bullseye && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libssl1.1 \
        libzip4 \
        libavcodec58 libavformat58 libavutil56 libswresample3 libswscale5 \
        libflac8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    rm /etc/apt/sources.list.d/bullseye.list /etc/apt/preferences.d/bullseye

# Debian 13 (trixie): OpenSSL 3.3 adds the OPENSSL_3.x symbols some bundled port libs
# need, and libstdc++6 adds GLIBCXX up to 3.4.33 for ports built on newer distros.
# libstdc++6 brings trixie's glibc, which /opt/sb-mesa needs: don't pin libc6 back.
RUN echo 'deb [arch=arm64] http://deb.debian.org/debian trixie main' \
        > /etc/apt/sources.list.d/trixie.list && \
    printf 'Package: *\nPin: release n=trixie\nPin-Priority: 100\n' \
        > /etc/apt/preferences.d/trixie && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        -t trixie libssl3t64 libstdc++6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    rm /etc/apt/sources.list.d/trixie.list /etc/apt/preferences.d/trixie

# /opt/sb-virgl: Debian's Mesa, for app versions that predate /opt/sb-mesa. Remove it
# once those are gone. Runs after every apt upgrade, so the copies match /usr/lib, and
# before the OSMesa redirects below, so it copies real GLVND.
# libgles1 is unpacked, not installed: ldconfig would undo the GLES1 OSMesa redirect.
RUN mkdir -p /opt/sb-virgl/dri /opt/sb-virgl/lib /opt/sb-virgl/bin && \
    cp -L /usr/lib/aarch64-linux-gnu/dri/virtio_gpu_dri.so /opt/sb-virgl/dri/ && \
    cp -L /usr/lib/aarch64-linux-gnu/dri/swrast_dri.so /opt/sb-virgl/dri/ && \
    cp -L /usr/lib/aarch64-linux-gnu/dri/kms_swrast_dri.so /opt/sb-virgl/dri/ && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libllvm15 libdrm-amdgpu1 libdrm-radeon1 libdrm-nouveau2 mesa-utils-bin \
    && for lib in libGL.so.1 libGLX.so.0 libGLdispatch.so.0 libGLX_mesa.so.0 \
                  libEGL.so.1 libEGL_mesa.so.0 libgbm.so.1 libglapi.so.0 \
                  libdrm.so.2 libdrm_amdgpu.so.1 libdrm_radeon.so.1 libdrm_nouveau.so.2 \
                  libLLVM-15.so.1 libzstd.so.1 libelf.so.1 libsensors.so.5 libxml2.so.2 \
                  libGLESv2.so.2; do \
        src=$(find /usr/lib/aarch64-linux-gnu -maxdepth 2 -name "$lib" 2>/dev/null | head -1); \
        if [ -n "$src" ]; then cp -L "$src" /opt/sb-virgl/lib/; \
        else echo "WARN: $lib not found" >&2; fi; \
    done && \
    cd /tmp && apt-get download libgles1 && \
    dpkg-deb -x libgles1_*.deb /tmp/libgles1 && \
    cp -L /tmp/libgles1/usr/lib/aarch64-linux-gnu/libGLESv1_CM.so.1 /opt/sb-virgl/lib/ && \
    rm -rf /tmp/libgles1 /tmp/libgles1_*.deb && cd / && \
    cp -L /usr/bin/es2_info.aarch64-linux-gnu /opt/sb-virgl/bin/es2_info && \
    cp -L /usr/bin/eglinfo.aarch64-linux-gnu /opt/sb-virgl/bin/eglinfo && \
    chmod +x /opt/sb-virgl/bin/* && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    du -sh /opt/sb-virgl

# /opt/sb-mesa: the GPU-mode tree. The app prefers it to /opt/sb-virgl. Mesa's own
# files come from the sb-mesa-fetch stage. GLVND, the GLES1 library, the Vulkan loader
# and the tools are added here from Debian, with their copyright files, before the
# OSMesa redirects below, so the real GLVND libraries are copied.
# The unversioned names are for games that dlopen them; without them the loader finds
# the rootfs's OSMesa wrapper. Each link is one hop (see the symlink note below).
COPY --from=sb-mesa-fetch /out/opt/sb-mesa /opt/sb-mesa
RUN for lib in libGL.so.1 libGLX.so.0 libGLdispatch.so.0 libEGL.so.1 libGLESv2.so.2; do \
        cp -L "/usr/lib/aarch64-linux-gnu/$lib" /opt/sb-mesa/lib/ || exit 1; \
    done && \
    apt-get update && \
    cd /tmp && apt-get download libgles1 libvulkan1 mesa-utils-bin && \
    for p in libgles1 libvulkan1 mesa-utils-bin; do dpkg-deb -x ${p}_*.deb /tmp/$p || exit 1; done && \
    cp -L /tmp/libgles1/usr/lib/aarch64-linux-gnu/libGLESv1_CM.so.1 /opt/sb-mesa/lib/ && \
    cp -L /tmp/libvulkan1/usr/lib/aarch64-linux-gnu/libvulkan.so.1 /opt/sb-mesa/lib/ && \
    cp /tmp/libvulkan1/usr/share/doc/libvulkan1/copyright /opt/sb-mesa/licenses/vulkan-loader-copyright && \
    cp /tmp/libgles1/usr/share/doc/libgles1/copyright /opt/sb-mesa/licenses/glvnd-copyright && \
    mkdir -p /opt/sb-mesa/bin && \
    cp -L /tmp/mesa-utils-bin/usr/bin/es2_info.aarch64-linux-gnu /opt/sb-mesa/bin/es2_info && \
    cp -L /tmp/mesa-utils-bin/usr/bin/eglinfo.aarch64-linux-gnu /opt/sb-mesa/bin/eglinfo && \
    cp /tmp/mesa-utils-bin/usr/share/doc/mesa-utils-bin/copyright /opt/sb-mesa/licenses/mesa-utils-copyright && \
    rm -rf /tmp/libgles1 /tmp/libvulkan1 /tmp/mesa-utils-bin /tmp/*.deb && cd / && \
    cd /opt/sb-mesa/lib && \
    ln -sf libGL.so.1 libGL.so && \
    ln -sf libEGL.so.1 libEGL.so && \
    ln -sf libGLESv2.so.2 libGLESv2.so && \
    ln -sf libGLESv1_CM.so.1 libGLESv1_CM.so && cd / && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    du -sh /opt/sb-mesa

# Compat symlinks for ports that link against unversioned / wrong-soname libs.
# Done after all apt operations: ldconfig would point libGL.so.1 back at GLVND.
#   libSDL2.so      — some ports link against the bare development name.
#   libGL.so.1      — replace GLVND dispatch with OSMesa (headless proot has no
#                     EGL/GLX context → GLVND silently drops GL calls → black screen).
#   libOpenGL.so.0  — same OSMesa redirect for the modern OpenGL split package.
#   libGLESv2.so    — unversioned soname for ports that link against it directly.
#                     (libGLESv2.so.2 is overwritten by libGLESv2_wrap.so on-device.)
#   libGLESv1_CM.so.1, libGLESv1_CM.so — OSMesa redirect for GLES1 ports.
# Keep each symlink chain to two hops: proot fails with ELOOP at three.
RUN ln -sf libSDL2-2.0.so.0 /usr/lib/aarch64-linux-gnu/libSDL2.so && \
    ln -sf libOSMesa.so.8   /usr/lib/aarch64-linux-gnu/libGL.so.1 && \
    ln -sf libOSMesa.so.8   /usr/lib/aarch64-linux-gnu/libOpenGL.so.0 && \
    ln -sf libGLESv2.so.2   /usr/lib/aarch64-linux-gnu/libGLESv2.so && \
    ln -sf libOSMesa.so.8   /usr/lib/aarch64-linux-gnu/libGLESv1_CM.so.1 && \
    ln -sf libOSMesa.so.8   /usr/lib/aarch64-linux-gnu/libGLESv1_CM.so

# proot bind targets (sb_proot_args.h in the app repo); they must exist before it starts.
#   /home/user   — the app's home dir
#   /roms/ports  — the port's directory (PortMaster's GAMEDIR="/roms/ports/<name>")
#   /tmp/sb      — IPC files and the launcher
#   /opt/sb      — the app's native libraries
RUN mkdir -p /home/user/port /roms/ports /tmp/sb /opt/sb

# PortMaster control directory skeleton.
# - libgl_default.txt is sourced by port scripts for GL settings.
# - libs/ is where harbourmaster (shim) downloads runtime squashfs files; proot binds
#   the app's runtimes dir over it.
# - utils/ is sourced by ports that need first-run installation/patching.
# - xdelta3 symlink: ports use $controlfolder/xdelta3 to patch game data files.
# - 7zzs.aarch64 symlink: ports use it to extract bundled archives.
# The PortMaster shim files are written by the app at first launch, embedded in
# libgame_bridge.so, so none of them are created here.
RUN mkdir -p /opt/system/Tools/PortMaster/libs /opt/system/Tools/PortMaster/utils && \
    ln -sf /usr/bin/7zz     /opt/system/Tools/PortMaster/7zzs.aarch64 && \
    ln -sf /usr/bin/xdelta3 /opt/system/Tools/PortMaster/xdelta3

COPY portmaster/libgl_default.txt /opt/system/Tools/PortMaster/libgl_default.txt

# Love2D 11.5 runtime — pre-built binary + libs copied from runtimes/love_11.5.
#   $controlfolder resolves to /opt/system/Tools/PortMaster on Starboard (matched by
#   the if-block in PortMaster launchers that checks this path first).
COPY runtimes/love_11.5/ /opt/system/Tools/PortMaster/runtimes/love_11.5/
RUN chmod +x /opt/system/Tools/PortMaster/runtimes/love_11.5/love.aarch64

# gmloadernext.aarch64 — swapped in for ports' bundled gmloadernext(.aarch64) at launch.
# Must have texhack (.pvr textures).
RUN mkdir -p /usr/local/lib/starboard
COPY runtimes/gmloadernext/gmloadernext.aarch64 /usr/local/lib/starboard/gmloadernext.aarch64
COPY runtimes/gmloadernext/LICENSE.txt /usr/local/lib/starboard/gmloadernext.LICENSE.txt
COPY runtimes/gmloadernext/SOURCE.txt /usr/local/lib/starboard/gmloadernext.SOURCE.txt
COPY runtimes/gmloadernext/THIRD_PARTY_NOTICES.txt /usr/local/lib/starboard/gmloadernext.THIRD_PARTY_NOTICES.txt
RUN chmod +x /usr/local/lib/starboard/gmloadernext.aarch64

# gmtoolkit.aarch64 — offline data.win → game.droid converter, called by
# RHH-Ports patchscripts.
COPY tools/gmtoolkit/gmtoolkit.aarch64 /opt/system/Tools/PortMaster/gmtoolkit.aarch64
COPY tools/gmtoolkit/LICENSE.txt /opt/system/Tools/PortMaster/gmtoolkit.LICENSE.txt
COPY tools/gmtoolkit/SOURCE.txt /opt/system/Tools/PortMaster/gmtoolkit.SOURCE.txt
RUN chmod +x /opt/system/Tools/PortMaster/gmtoolkit.aarch64

# mount and umount wrappers: proot can't mount (see rootfs-mount-wrapper.sh).
COPY rootfs-mount-wrapper.sh /usr/local/bin/mount
RUN chmod +x /usr/local/bin/mount
RUN printf '#!/bin/bash\nexit 0\n' > /usr/local/bin/umount && chmod +x /usr/local/bin/umount

# Read by EngineSetupRepository.rootfsRelease() for Settings. build-rootfs.sh passes
# these in; local builds get "dev".
ARG STARBOARD_RELEASE=dev
ARG STARBOARD_COMMIT=unknown
ARG STARBOARD_BUILT=unknown
RUN printf 'release=%s\ncommit=%s\nbuilt=%s\n' \
        "$STARBOARD_RELEASE" "$STARBOARD_COMMIT" "$STARBOARD_BUILT" \
        > /etc/starboard-release

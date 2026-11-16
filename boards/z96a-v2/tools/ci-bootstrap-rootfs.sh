#!/bin/bash
# Bootstrap the distribution rootfs tarball inside the pinned build container.
#
# The prebuilt `base-apps` component only ships a Devuan tarball.  When the
# repo is switched to another distribution (currently Ubuntu noble) the
# matching `${DISTRO}-${DISTRO_VERSION}-minimal-rootfs-${ARCH_EXT}.tar.xz`
# does not exist in the input cache.  This script builds it from scratch with
# the project's own `make rootfs` path (mmdebstrap + chroot), which already
# handles Ubuntu keyrings, ports.ubuntu.com sources and package sets.
#
# It is a no-op when the expected tarball is already present, so it is safe to
# call unconditionally from CI.
#
# Env: Z96A_BUILD_IMAGE (default z96a-build:local), BOARD (default z96a-v2).
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$ROOT" || exit 1

BOARD=${BOARD:-z96a-v2}
IMAGE=${Z96A_BUILD_IMAGE:-z96a-build:local}

DISTRO=$(sed -n 's/^DISTRO="\([^"]*\)".*/\1/p' userdata.txt | head -n 1)
DISTRO_VERSION=$(sed -n 's/^DISTRO_VERSION="\([^"]*\)".*/\1/p' userdata.txt | head -n 1)
ARCH_EXT=$(sed -n 's/^ARCH_EXT="\([^"]*\)".*/\1/p' "lib/boards/$BOARD" | head -n 1)
MINIMAL=$(sed -n 's/^MINIMAL_ROOTFS="\([^"]*\)".*/\1/p' custom.txt | head -n 1)
if [ "$MINIMAL" = "true" ]; then
    TARBALL="${DISTRO}-${DISTRO_VERSION}-minimal-rootfs-${ARCH_EXT}.tar.xz"
else
    TARBALL="${DISTRO}-${DISTRO_VERSION}-rootfs-${ARCH_EXT}.tar.xz"
fi

if [ -s "output/tarball/$TARBALL" ]; then
    echo "rootfs bootstrap: $TARBALL already present, skipping"
    exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not available; cannot bootstrap $TARBALL" >&2
    exit 2
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -f "boards/$BOARD/tools/Dockerfile" -t "$IMAGE" .
fi

CA_MOUNT=()
if [ -r /etc/ssl/certs/ca-certificates.crt ]; then
    CA_MOUNT=(-v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro)
fi

echo "rootfs bootstrap: building $TARBALL via 'make rootfs' in $IMAGE"
mkdir -p output/ci
set -o pipefail
docker run --rm --privileged \
    -v "$ROOT:/build" \
    -v /dev:/dev \
    "${CA_MOUNT[@]}" \
    -w /build \
    -e BOARD="$BOARD" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -e TERM="${TERM:-xterm}" \
    "$IMAGE" \
    bash -lc '
        set -e
        # `debootstrap_script()` in lib/function/rootfs symlinks the suite alias
        # (e.g. gutsy -> noble) for every non-Debian distribution.  The build
        # image ships mmdebstrap but not debootstrap, so both the directory and
        # the alias source are missing and `ln -sr` aborts the whole run.
        # mmdebstrap never reads those scripts, so a stub is enough; a real
        # debootstrap install is preferred when the network allows it.
        if [ ! -f /usr/share/debootstrap/scripts/gutsy ]; then
            apt-get update -qq || true
            apt-get install -y --no-install-recommends debootstrap >/dev/null 2>&1 || true
        fi
        mkdir -p /usr/share/debootstrap/scripts
        [ -e /usr/share/debootstrap/scripts/gutsy ] || : > /usr/share/debootstrap/scripts/gutsy
        make rootfs board='"$BOARD"'
        # `make rootfs` runs as root here; hand the products back to the runner
        # user so the following workflow steps can still write to output/.
        chown -R "${HOST_UID}:${HOST_GID}" /build/output /build/board.txt 2>/dev/null || true
    ' 2>&1 | tee output/ci/rootfs-bootstrap.log

[ -s "output/tarball/$TARBALL" ] || {
    echo "rootfs bootstrap failed: output/tarball/$TARBALL not produced" >&2
    exit 1
}
echo "rootfs bootstrap: OK ($TARBALL)"

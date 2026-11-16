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
set -o pipefail
docker run --rm --privileged \
    -v "$ROOT:/build" \
    -v /dev:/dev \
    "${CA_MOUNT[@]}" \
    -w /build \
    -e BOARD="$BOARD" \
    -e TERM="${TERM:-xterm}" \
    "$IMAGE" \
    bash -lc "make rootfs board=$BOARD" 2>&1 | tee output/ci/rootfs-bootstrap.log

[ -s "output/tarball/$TARBALL" ] || {
    echo "rootfs bootstrap failed: output/tarball/$TARBALL not produced" >&2
    exit 1
}
echo "rootfs bootstrap: OK ($TARBALL)"

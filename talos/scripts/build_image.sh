#!/bin/bash
# Build Talos boot assets for DGX Spark / GB10 with the official Talos imager.
#
# Uses the pinned imager, base installer and system extensions from
# talos/config/versions.env. No custom kernel, overlay or modules: Talos
# supports the GB10 platform natively since v1.12, the NVIDIA driver comes
# from the official siderolabs extensions.
#
# The imager runs natively on amd64 or arm64 and only pulls arm64 artifacts,
# no QEMU needed. "metal" (raw disk image) needs --privileged and /dev for
# loop devices; "installer" and "iso" do not.
#
# Usage:
#   ./talos/scripts/build_image.sh [installer|iso|metal] ...
#
# Output (talos/output/):
#   installer -> installer-arm64.tar   (load with: crane push / docker load)
#   iso       -> metal-arm64.iso
#   metal     -> metal-arm64.raw.zst
#
# SecureBoot assets need signing keys; use the Image Factory instead
# (talos/config/schematic.yaml), which signs them with the Sidero Labs keys.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${TALOS_DIR}/output}"

# shellcheck source=SCRIPTDIR/../config/versions.env
source "${TALOS_DIR}/config/versions.env"

kinds=("$@")
if [ "${#kinds[@]}" -eq 0 ]; then
    kinds=(installer iso)
fi

args=(
    --arch "${ARCH}"
    --base-installer-image "${INSTALLER_BASE_IMAGE}"
    --system-extension-image "${EXT_NVIDIA_KMOD}"
    --system-extension-image "${EXT_NVIDIA_TOOLKIT}"
    --system-extension-image "${EXT_REALTEK_FIRMWARE}"
    --system-extension-image "${EXT_MELLANOX_MSTFLINT}"
)
for karg in ${EXTRA_KERNEL_ARGS}; do
    args+=(--extra-kernel-arg "${karg}")
done

mkdir -p "${OUTPUT_DIR}"

echo "🔨 Building Talos ${TALOS_VERSION} (${ARCH}) for DGX Spark / GB10"
echo "   Imager:     ${IMAGER_IMAGE}"
echo "   Extensions: ${EXT_NVIDIA_KMOD##*/} ${EXT_NVIDIA_TOOLKIT##*/} ${EXT_REALTEK_FIRMWARE##*/} ${EXT_MELLANOX_MSTFLINT##*/}"
echo "   Kernel args: ${EXTRA_KERNEL_ARGS}"
echo "   Output:     ${OUTPUT_DIR}"

for kind in "${kinds[@]}"; do
    docker_args=(--rm -v "${OUTPUT_DIR}:/out")
    case "${kind}" in
        installer|iso) ;;
        metal) docker_args+=(--privileged -v /dev:/dev) ;;
        *)
            echo "❌ Unknown output kind: ${kind} (installer|iso|metal)" >&2
            exit 1
            ;;
    esac

    echo ""
    echo "📦 ${kind}"
    docker run "${docker_args[@]}" "${IMAGER_IMAGE}" "${kind}" "${args[@]}"
done

echo ""
echo "✅ Done:"
ls -lh "${OUTPUT_DIR}"

#!/bin/bash
# Re-pin talos/config/versions.env for a Talos release.
#
# Looks up the imager/installer-base digests in the registry and the matching
# official extension refs+digests from the Image Factory, then rewrites the
# EXT_*/IMAGER_*/INSTALLER_* lines in place. Review the diff before committing
# (driver branch changes, new extension names, release notes).
#
# Usage:
#   ./talos/scripts/update_versions.sh v1.14.4
#
# Requires: curl, jq, docker buildx (imagetools inspect).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$(cd "${SCRIPT_DIR}/.." && pwd)/config/versions.env"
TALOS_VERSION="${1:?usage: $0 <talos-version, e.g. v1.14.4>}"
FACTORY="${FACTORY:-https://factory.talos.dev}"

digest() {
    docker buildx imagetools inspect "$1" | awk '/^Digest:/ {print $2; exit}'
}

extensions="$(curl -fsSL "${FACTORY}/version/${TALOS_VERSION}/extensions/official")"

ext_ref() {
    local ref
    ref="$(jq -er --arg n "siderolabs/$1" '.[] | select(.name == $n) | "\(.ref)@\(.digest)"' <<<"${extensions}")" || {
        echo "❌ extension siderolabs/$1 not found for ${TALOS_VERSION}" >&2
        exit 1
    }
    echo "${ref}"
}

imager="ghcr.io/siderolabs/imager:${TALOS_VERSION}"
installer_base="ghcr.io/siderolabs/installer-base:${TALOS_VERSION}"

talosctl_sha256="$(curl -fsSL "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/sha256sum.txt" | awk '$2 == "talosctl-linux-amd64" {print $1}')"

declare -A values=(
    [TALOS_VERSION]="${TALOS_VERSION}"
    [TALOSCTL_LINUX_AMD64_SHA256]="${talosctl_sha256}"
    [IMAGER_IMAGE]="${imager}@$(digest "${imager}")"
    [INSTALLER_BASE_IMAGE]="${installer_base}@$(digest "${installer_base}")"
    [EXT_NVIDIA_KMOD]="$(ext_ref nonfree-kmod-nvidia-production)"
    [EXT_NVIDIA_TOOLKIT]="$(ext_ref nvidia-container-toolkit-production)"
    [EXT_REALTEK_FIRMWARE]="$(ext_ref realtek-firmware)"
    [EXT_MELLANOX_MSTFLINT]="$(ext_ref mellanox-mstflint)"
)

# Lookup failures inside the array assignment do not trip set -e, so check
# every value before writing anything.
for key in "${!values[@]}"; do
    value="${values[${key}]}"
    if [ -z "${value}" ] || { [[ "${key}" == *_IMAGE || "${key}" == EXT_* ]] && [[ "${value}" != *@sha256:* ]]; }; then
        echo "❌ could not resolve ${key}" >&2
        exit 1
    fi
done
for key in "${!values[@]}"; do
    sed -i "s|^${key}=.*|${key}=${values[${key}]}|" "${VERSIONS_FILE}"
done

# The driver and toolkit must carry the same NVIDIA driver version.
kmod_driver="${values[EXT_NVIDIA_KMOD]#*:}"
toolkit_driver="${values[EXT_NVIDIA_TOOLKIT]#*:}"
if [ "${kmod_driver%%-*}" != "${toolkit_driver%%-*}" ]; then
    echo "⚠️  driver mismatch: kmod ${kmod_driver%%-*} vs toolkit ${toolkit_driver%%-*}" >&2
fi

echo "✅ Updated ${VERSIONS_FILE} for ${TALOS_VERSION}; review with: git diff"

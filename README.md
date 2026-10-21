# Talos on DGX Spark (NVIDIA GB10)

Talos Linux boot assets and configuration for NVIDIA GB10 machines: NVIDIA DGX
Spark Founders Edition, ASUS Ascent GX10 and the other OEM GB10 desktops
(Dell, Lenovo, HP, Gigabyte, MSI, Acer). arm64, UEFI/ACPI, ConnectX-7.

**Talos supports GB10 natively since v1.12.** No overlay, custom kernel or
extracted modules are needed: the build uses the stock Talos kernel plus the
official Sidero Labs system extensions and one kernel argument.

| Component | Version (pinned in [talos/config/versions.env](talos/config/versions.env)) |
|---|---|
| Talos | v1.14.4 (Linux 6.18.57) |
| NVIDIA driver | `nonfree-kmod-nvidia-production` 595.91.07 (proprietary modules, required on GB10) |
| Container toolkit | `nvidia-container-toolkit-production` 595.91.07-v1.19.1 |
| Firmware/tools | `realtek-firmware` 20260916 (RTL8127 10GbE), `mellanox-mstflint` 4.34.1-4 |
| Kernel argument | `arm64.nobti` |

## Quick Start

Two ways to get boot media, see [talos/README.md](talos/README.md):

1. **Image Factory** (recommended, SecureBoot-signed): upload
   [talos/config/schematic.yaml](talos/config/schematic.yaml), download the
   arm64 ISO, install with `factory.talos.dev/metal-installer/<id>:v1.14.4`.
2. **Local/CI build** with the pinned imager:
   `./talos/scripts/build_image.sh installer iso`.

Then apply [talos/config/gb10-machine-patch.yaml](talos/config/gb10-machine-patch.yaml)
to load the NVIDIA modules.

## Repository Structure

```
.
├── talos/
│   ├── config/
│   │   ├── versions.env             # pinned Talos/imager/extension refs (digests)
│   │   ├── schematic.yaml           # Image Factory schematic
│   │   └── gb10-machine-patch.yaml  # KernelModuleConfig for the NVIDIA modules
│   ├── scripts/
│   │   ├── build_image.sh           # imager build: installer, iso, metal
│   │   └── update_versions.sh       # re-pin versions.env for a Talos release
│   └── output/                      # build outputs (ignored)
└── .github/workflows/talos-image.yml  # validate on PR, build + push installer on main
```

## Obsolete: ASUS overlay (to be removed)

The original approach in `talos/asus-ascent-gx10-overlay/`, `talos/scripts/ci_*.py`,
`talos/scripts/extract_*.sh`, `talos/scripts/build_overlay.sh`, `talos/config/overlay.yaml`,
`docs/`, `dockerfiles/` and `scripts/` cannot work and is no longer used:

- it copies Ubuntu `6.11.0-1016-nvidia` kernel modules into a Talos image; Talos
  runs its own kernel (6.18) with `module.sig_enforce=1`, so they never load;
- Talos overlay installers write to the boot partition at install time, not to the
  read-only rootfs, and are meant for SBC firmware/DTBs, not drivers;
- it depends on a private copy of the ASUS DGX OS apt repository (GCS bucket) and
  redistributes NVIDIA/linux-firmware blobs that the MIT license does not cover.

These paths are kept only until the removal commit; Git history retains them.

## License

MIT, see [LICENSE](LICENSE). The NVIDIA driver extensions are subject to the
[NVIDIA EULA](https://www.nvidia.com/en-us/drivers/nvidia-license/); Talos Linux
is MPL-2.0 (Sidero Labs).

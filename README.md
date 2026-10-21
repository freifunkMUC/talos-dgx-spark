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
   Schematic ID for the current `schematic.yaml` (v1.14.4): `e834f40f79287c3b0dd134195d577f861f88ba7dbbf60f0dd642dfefe9e2fb7c`;
   ISO `https://factory.talos.dev/image/e834f40f79287c3b0dd134195d577f861f88ba7dbbf60f0dd642dfefe9e2fb7c/v1.14.4/metal-arm64-secureboot.iso`
   (without SecureBoot: `metal-arm64.iso`). The ID changes whenever `schematic.yaml` changes.
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

## History

Forked from [microscaler/talos-dgx-spark](https://github.com/microscaler/talos-dgx-spark), which built a Talos
overlay from Ubuntu `6.11.0-1016-nvidia` kernel modules and firmware out of the ASUS DGX OS repository. That
cannot work (Talos runs its own kernel with `module.sig_enforce=1`; overlays only write to the boot partition)
and is no longer needed, since Talos supports GB10 natively from v1.12 on with the official Sidero Labs
extensions. The overlay was removed; Git history still has it.

## License

MIT, see [LICENSE](LICENSE). The NVIDIA driver extensions are subject to the
[NVIDIA EULA](https://www.nvidia.com/en-us/drivers/nvidia-license/); Talos Linux
is MPL-2.0 (Sidero Labs).

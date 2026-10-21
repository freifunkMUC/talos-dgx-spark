# Talos on NVIDIA GB10 (DGX Spark and OEM variants)

Upstream Talos boots GB10 via UEFI/ACPI with the stock arm64 kernel since
v1.12 (siderolabs/talos#12170). Everything hardware-specific is:

- NVIDIA **proprietary** kernel modules (`nonfree-kmod-nvidia-production`).
  The open modules load on Talos >= 1.13 (Clang/ThinLTO kernel) but CUDA fails
  (`cuInit` = 3, "Addressing Mode: None") or the node crash-loops
  (siderolabs/talos#13019, #14087; Talos docs "NVIDIA GPU (Proprietary drivers)").
- Kernel argument `arm64.nobti`, baked into the UKI. Without it the node
  reboots as soon as `nvidia.ko` loads.
- `KernelModuleConfig` documents for `nvidia`, `nvidia_uvm`, `nvidia_drm`,
  `nvidia_modeset` ([config/gb10-machine-patch.yaml](config/gb10-machine-patch.yaml)).
- `realtek-firmware` for the onboard RTL8127 10GbE (`r8169`, in-tree since 6.16).
  ConnectX-7 (`mlx5_core`, `mlx5_ib`) and NVMe are in the base kernel.

## Building boot media

### Image Factory (recommended)

```bash
id=$(curl -sSf -X POST --data-binary @talos/config/schematic.yaml https://factory.talos.dev/schematics | jq -r .id)
echo "https://factory.talos.dev/image/${id}/v1.14.4/metal-arm64.iso"             # SecureBoot off
echo "https://factory.talos.dev/image/${id}/v1.14.4/metal-arm64-secureboot.iso"  # SecureBoot on
echo "factory.talos.dev/metal-installer/${id}:v1.14.4"                           # installer
```

The factory signs SecureBoot assets with the Sidero Labs keys and picks the
extension versions matching the Talos release.

### Local or CI build

```bash
./talos/scripts/build_image.sh installer iso   # -> talos/output/installer-arm64.tar, metal-arm64.iso
./talos/scripts/build_image.sh metal           # raw disk image, needs --privileged (handled by the script)
crane push talos/output/installer-arm64.tar ghcr.io/<org>/installer-dgx-spark:v1.14.4
```

Runs the pinned `ghcr.io/siderolabs/imager` on amd64 or arm64 (no QEMU). The
output is not SecureBoot-signed. CI does the same on `main` and pushes the
installer to `ghcr.io/<owner>/installer-dgx-spark:<talos-version>`.

### Updating

```bash
./talos/scripts/update_versions.sh v1.14.5   # re-pins imager, installer-base, extensions, talosctl
git diff talos/config/versions.env
```

Extension tags are bound to the Talos release (`<driver>-<talos>`), so always
update them together. Check the Talos/extensions release notes for NVIDIA
driver branch changes (`production` vs `lts`).

## Installing

```bash
talosctl gen config <cluster> https://<endpoint>:6443 \
  --install-image factory.talos.dev/metal-installer/<id>:v1.14.4 \
  --config-patch @talos/config/gb10-machine-patch.yaml
```

Talos 1.14 writes the installer image to an `UnattendedInstallConfig` document
(replaces `.machine.install`). Kernel arguments come from the UKI; with
systemd-boot `extraKernelArgs` in the machine config has no effect. For
upgrades use the same installer image (`talosctl upgrade --image ...`).

GPU in Kubernetes: `RuntimeClass` `nvidia`, then NVIDIA GPU Operator >= v26.3.1
with `driver.enabled=false`, `toolkit.enabled=false`,
`hostPaths.driverInstallDir=/usr/local` (or the k8s-device-plugin alone).

## Bring-up checklist (needs real hardware)

| Area | Check |
|---|---|
| Firmware | Update UEFI/EC/CX-7 firmware first (DGX OS or OEM tool); Talos cannot apply capsules yet (siderolabs/talos#14333). |
| Boot | USB ISO boots via UEFI (PiKVM: mass storage as CD/DVD, not "Flash"). PXE (booter) needs SecureBoot off and network stack on. |
| SecureBoot | With the factory SecureBoot ISO: firmware in setup mode, keys auto-enroll (`if-safe` only in VMs; enroll from the boot menu). Otherwise disable SecureBoot. |
| NVMe | `talosctl get disks`: internal NVMe visible; install disk selector matches it. |
| Ethernet | `talosctl get links`: RTL8127 (`r8169`) link up, no firmware error in `talosctl dmesg \| grep r8169`. |
| ConnectX-7 | `mlx5_core` probes both QSFP ports; for RoCE add `rdma_ucm`/`ib_umad` (commented in the patch). |
| GPU | `talosctl read /proc/cmdline` contains `arm64.nobti`; `talosctl read /proc/modules \| grep nvidia`; `talosctl read /proc/driver/nvidia/version` shows 595.91.07 (not "Open Kernel Module"). |
| CUDA | Pod with `runtimeClassName: nvidia`: `nvidia-smi` shows `NVIDIA GB10`; `nvidia-smi -q` "Addressing Mode" is not `None`; a `cuInit(0)` test returns 0. |
| Services | `talosctl services`: `ext-nvidia-persistenced` running. |
| Reboot | Reboot and upgrade once; if kexec reboots hang, add `kexec_load_disabled=1` to the schematic (used in the siderolabs/contrib GB10 example). |

## Variant notes

All GB10 systems share the SoC and NVIDIA's reference design; differences are
in firmware, ports and cooling. Verify on the target unit:

- **Serial console**: on the Founders Edition `earlycon=uart,mmio32,0x16A00000 console=ttyS0,921600`
  (siderolabs/talos#12170). Talos defaults to `console=ttyAMA0 console=tty0`.
  Add to `EXTRA_KERNEL_ARGS`/schematic only if the variant exposes the UART.
- **UEFI**: AMI on the Founders Edition; menu names for SecureBoot, PXE and
  network stack differ per OEM.
- **10GbE/CX-7**: check `lspci` (DGX OS) for RTL8127 and the CX-7 port count.
- **Wi-Fi** (MediaTek MT7925) is not built into the Talos kernel; not needed.
- **Storage**: SKUs ship 1-4 TB NVMe; adjust disk selectors.

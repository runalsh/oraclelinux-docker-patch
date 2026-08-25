# Oracle Linux Docker Patch Images

Automated build of Docker images for exact Oracle Linux point releases (**8.10**, **9.0** .. **9.8**, **10.0**, **10.1**) converted from official QCOW/QCOW2 templates directly into **`runalsh/oraclelinux-patch`** and **`ghcr.io/runalsh/oraclelinux-patch`**.

---

## ❓ Problem Statement

The official Docker Hub registry (`library/oraclelinux`) publishes **only major tags** (e.g., `oraclelinux:8`, `oraclelinux:9`, `latest`).

Official tags like `oraclelinux:8.10`, `oraclelinux:9.5`, or `oraclelinux:10.1` **do not exist** or are continuously updated with newer packages.

### Key Issues:
1. **Testing on specific distribution patch versions**: Impossibility of running tests or simulating environments locked to a specific point release (e.g., `8.10`, `9.5`, `10.1`).
2. **Build Reproducibility**: The base `oraclelinux:9` image changes over time as packages are updated, which can alter software behavior.
3. **Security Audits & Forensics**: Difficulty in reproducing system environments as they existed at a specific point release date.

---

## 🚀 Solution

This repository addresses the problem by:
- Reading download URLs from **`releases.txt`** (extracted from `/root/lima` git history).
- Downloading official Oracle Linux QCOW/QCOW2 templates.
- Mounting QCOW/QCOW2 disk images via `qemu-nbd` and LVM kernel modules.
- Dynamically detecting root file systems by verifying `/etc/oracle-release` or `/etc/os-release`.
- Exporting container rootfs archives and importing them into Docker.
- Automatically publishing ready-to-use Docker images to **Docker Hub** (`runalsh/oraclelinux-patch`) and **GitHub Container Registry** (`ghcr.io/runalsh/oraclelinux-patch`).

---

## 📦 Available Images and Registries

### Oracle Linux 8

| Tag | OS Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|
| `8.10` | `Oracle Linux 8.10` | [`runalsh/oraclelinux-patch:8.10`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:8.10`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |

### Oracle Linux 9

| Tag | OS Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|
| `9.0` | `Oracle Linux 9.0` | [`runalsh/oraclelinux-patch:9.0`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.0`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.1` | `Oracle Linux 9.1` | [`runalsh/oraclelinux-patch:9.1`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.1`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.2` | `Oracle Linux 9.2` | [`runalsh/oraclelinux-patch:9.2`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.2`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.3` | `Oracle Linux 9.3` | [`runalsh/oraclelinux-patch:9.3`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.3`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.4` | `Oracle Linux 9.4` | [`runalsh/oraclelinux-patch:9.4`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.4`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.5` | `Oracle Linux 9.5` | [`runalsh/oraclelinux-patch:9.5`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.5`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.6` | `Oracle Linux 9.6` | [`runalsh/oraclelinux-patch:9.6`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.6`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.7` | `Oracle Linux 9.7` | [`runalsh/oraclelinux-patch:9.7`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.7`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `9.8` | `Oracle Linux 9.8` | [`runalsh/oraclelinux-patch:9.8`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:9.8`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |

### Oracle Linux 10

| Tag | OS Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|
| `10.0` | `Oracle Linux 10.0` | [`runalsh/oraclelinux-patch:10.0`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:10.0`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |
| `10.1` | `Oracle Linux 10.1` | [`runalsh/oraclelinux-patch:10.1`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:10.1`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |

---


---

## ✂️ What is Stripped from the Rootfs (Size Optimization)

Official Oracle Linux KVM VM templates contain Linux kernels (`kernel-uek`), bootloaders (`grub2`), firmware files, and package caches meant for bare-metal/hypervisor VMs that are unnecessary inside Docker containers.

The build script strips non-container bloat, reducing the uncompressed image from **~768 MB** down to **~490 MB** (saving over **280 MB** per image):

| Component / Path | What it is | Why it is safe to remove in Docker | Disk Space Saved |
|---|---|---|---|
| **UEK Kernel & Modules** (`/usr/lib/modules`, `/lib/modules`, `/boot/vmlinuz*`, `/boot/initramfs*`) | Oracle Unbreakable Enterprise Kernel binaries and drivers | Docker containers share the host Linux kernel; internal kernel files are never loaded. | **~100 MB** |
| **GRUB Bootloader** (`/usr/lib/grub*`, `/boot/grub*`, `/etc/grub.d`) | GRUB2 EFI/BIOS bootloader tools | Containers are spawned directly via `runc` without BIOS/EFI boot. | **~40 MB** |
| **GeoIP Databases** (`/usr/share/GeoIP`) | Offline IP geolocation databases (`geolite2-city`) | Not needed in minimal base container runtime. | **~60 MB** |
| **DNF / YUM Package Caches** (`/var/cache/dnf/*`, `/var/cache/yum/*`) | Downloaded RPM metadata caches from build time | Refreshed automatically during `dnf update` / `dnf install`. | **~30 MB** |
| **Documentation & Manuals** (`/usr/share/{doc,man,info}`) | Package changelogs and man pages | Not used by headless automated daemons or CI/CD test jobs. | **~40 MB** |
| **Temporary Files & Logs** (`/tmp/*`, `/var/log/*`, `/var/tmp/*`) | VM template bootstrap install logs | Re-generated on demand during runtime. | **~10 MB** |
| **Total Savings** | | | **~280+ MB** |

---
## 🛠 Quick Start

### Docker Hub

```bash
docker run --rm -it runalsh/oraclelinux-patch:8.10 cat /etc/oracle-release
docker run --rm -it runalsh/oraclelinux-patch:9.5 cat /etc/oracle-release
docker run --rm -it runalsh/oraclelinux-patch:10.1 cat /etc/oracle-release
```

### GitHub Container Registry (GHCR)

```bash
docker run --rm -it ghcr.io/runalsh/oraclelinux-patch:8.10 cat /etc/oracle-release
docker run --rm -it ghcr.io/runalsh/oraclelinux-patch:9.5 cat /etc/oracle-release
docker run --rm -it ghcr.io/runalsh/oraclelinux-patch:10.1 cat /etc/oracle-release
```

### Local Build

The `releases.txt` file contains a list of tags and direct download URLs for QCOW/QCOW2 images.

To convert and import all versions locally:

```bash
chmod +x build.sh
TEST_VERSION=true PUSH_TO_DOCKERHUB=false PUSH_TO_GHCR=false ./build.sh
```

---

## 🔧 Environment Variables

The `build.sh` script supports the following configuration environment variables:

| Variable | Default | Description |
|---|---|---|
| `TEST_VERSION` | `true` | When set to `true`, verifies container functionality and validates `/etc/oracle-release` after import. |
| `PUSH_TO_DOCKERHUB` | `false` | When set to `true`, automatically pushes built images to Docker Hub (`runalsh/oraclelinux-patch:<tag>`). |
| `PUSH_TO_GHCR` | `false` | When set to `true`, automatically pushes built images to GitHub Packages / GHCR (`ghcr.io/runalsh/oraclelinux-patch:<tag>`). |
| `CLEANUP_DOCKER_IMAGES` | `false` | When set to `true`, deletes local Docker images (`docker rmi`) after build and push to conserve disk space. |
| `SKIP_EXISTS_CHECK` | `false` | When set to `false`, checks if the image tag already exists and skips download/conversion if present. Set to `true` to force building all tags regardless of remote registry status. |

---

## ⚙️ Repository Structure

```text
.
├── .github/workflows/
│   └── build-and-push.yml  # Automated CI pipeline for building, testing, scanning, and pushing to Docker Hub & GHCR
├── build.sh                 # Script for downloading QCOW/QCOW2 images, converting via qemu-nbd, verifying, and pushing
├── releases.txt             # Registry of URLs with QCOW/QCOW2 versions
└── README.md                # Project documentation
```

---

## 🔐 GitHub Actions Secrets

The CI workflow requires the following secrets in GitHub Secrets:
- `DOCKERHUB_USERNAME`: Your Docker Hub username (`runalsh`)
- `DOCKERHUB_TOKEN`: Docker Hub Personal Access Token
- `${{ secrets.GITHUB_TOKEN }}`: Automatically provided by GitHub for GHCR publishing

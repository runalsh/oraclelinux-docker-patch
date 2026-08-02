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
- Generating SPDX SBOM files and scanning for vulnerabilities using **Trivy** without blocking the pipeline.
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
| `ENABLE_TRIVY_SCAN` | `false` | When set to `true` (or when `trivy` binary is present), generates SPDX SBOM reports (`trivy-reports/sbom-<tag>.json`) and logs vulnerabilities to stdout without failing the build pipeline (`--exit-code 0`). |

---

## 🛡 Security & Trivy Scanning

During build execution, images are scanned using [Trivy](https://github.com/aquasecurity/trivy):
- **SBOM Generation**: Exported in SPDX-JSON format (`trivy-reports/sbom-<tag>.json`) and saved to GitHub Actions Job Artifacts (`oraclelinux-sbom-reports`).
- **Vulnerability Logging**: Vulnerabilities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL) are logged to build stdout. Scans execute with `--exit-code 0`, ensuring pipeline continuity regardless of identified CVEs.

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

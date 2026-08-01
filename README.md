# Oracle Linux Docker Patch Images

Automated build of Docker images for exact Oracle Linux point releases (**8.10**, **9.0** .. **9.8**) converted from VMDK/OVA VM templates into **`runalsh/oraclelinux-patch`**.

---

## ❓ Problem Statement

The official Docker Hub registry (`library/oraclelinux`) publishes **only major tags** (e.g., `oraclelinux:8`, `oraclelinux:9`, `latest`).

Official tags like `oraclelinux:8.10` or `oraclelinux:9.5` **do not exist** or are continuously updated with newer packages.

### Key Issues:
1. **Testing on specific distribution patch versions**: Impossibility of running tests or simulating environments locked to a specific point release (e.g., `8.10`, `9.5`).
2. **Build Reproducibility**: The base `oraclelinux:9` image changes over time as packages are updated, which can alter software behavior.
3. **Security Audits & Forensics**: Difficulty in reproducing system environments as they existed at a specific point release date.

---

## 🚀 Solution

This repository addresses the problem by:
- Reading download URLs from **`releases.txt`** (extracted from Oracle templates & `lima-vm/lima` git history).
- Downloading official Oracle Linux OVA/VMDK virtual machine templates.
- Converting OVA/VMDK images into Docker container rootfs archives using [`ova-to-docker`](https://github.com/executeatwill/ova-to-docker).
- Validating `/etc/oracle-release` and `/etc/os-release` in the container.
- Automatically publishing ready-to-use Docker images to Docker Hub: **`runalsh/oraclelinux-patch`**.

---

## 📦 Available Images and Tags

### Oracle Linux 8

| Tag | Version in `/etc/oracle-release` | Download Image |
|---|---|---|
| `runalsh/oraclelinux-patch:8.10` | `Oracle Linux Server release 8.10` | `OL8U10_x86_64-aws-b288.vmdk` |

### Oracle Linux 9

| Tag | Version in `/etc/oracle-release` | Download Image |
|---|---|---|
| `runalsh/oraclelinux-patch:9.0` | `Oracle Linux Server release 9.0` | `OL9U0_x86_64-olvm-b138.ova` |
| `runalsh/oraclelinux-patch:9.1` | `Oracle Linux Server release 9.1` | `OL9U1_x86_64-olvm-b158.ova` |
| `runalsh/oraclelinux-patch:9.2` | `Oracle Linux Server release 9.2` | `OL9U2_x86_64-olvm-b197.ova` |
| `runalsh/oraclelinux-patch:9.3` | `Oracle Linux Server release 9.3` | `OL9U3_x86_64-olvm-b211.ova` |
| `runalsh/oraclelinux-patch:9.4` | `Oracle Linux Server release 9.4` | `OL9U4_x86_64-olvm-b234.ova` |
| `runalsh/oraclelinux-patch:9.5` | `Oracle Linux Server release 9.5` | `OL9U5_x86_64-olvm-b259.ova` |
| `runalsh/oraclelinux-patch:9.6` | `Oracle Linux Server release 9.6` | `OL9U6_x86_64-olvm-b265.ova` |
| `runalsh/oraclelinux-patch:9.7` | `Oracle Linux Server release 9.7` | `OL9U7_x86_64-olvm-b289.ova` |
| `runalsh/oraclelinux-patch:9.8` | `Oracle Linux Server release 9.8` | `OL9U8_x86_64-olvm-b293.ova` |

---

## 🛠 Quick Start

### Using pre-built images from Docker Hub

```bash
docker run --rm -it runalsh/oraclelinux-patch:8.10 cat /etc/oracle-release
docker run --rm -it runalsh/oraclelinux-patch:9.5 cat /etc/oracle-release
docker run --rm -it runalsh/oraclelinux-patch:9.8 cat /etc/oracle-release
```

### Local Build

The `releases.txt` file contains a list of tags and direct download URLs for VMDK/OVA images.

To convert and import all versions locally:

```bash
chmod +x build.sh
TEST_VERSION=true PUSH_TO_DOCKERHUB=false ./build.sh
```

---

## ⚙️ Repository Structure

```text
.
├── .github/workflows/
│   └── build-and-push.yml  # Automated CI pipeline for building, testing, and pushing to Docker Hub
├── build.sh                 # Script for downloading VMDK/OVAs, converting via ova-to-docker, verifying, and pushing
├── releases.txt             # Registry of URLs with VMDK/OVA versions
└── README.md                # Project documentation
```

---

## 🔐 GitHub Actions Secrets

The CI workflow requires the following secrets in GitHub Secrets:
- `DOCKERHUB_USERNAME`: Your Docker Hub username (`runalsh`)
- `DOCKERHUB_TOKEN`: Docker Hub Personal Access Token

#!/usr/bin/env python3
import os
import re
import sys
import json
import urllib.request

MAJOR_TRACKS = ["ol8", "ol9", "ol10"]
RELEASES_FILE = "releases.txt"
README_FILE = "README.md"

def load_existing_releases(releases_path):
    existing = set()
    if not os.path.exists(releases_path):
        return existing
    with open(releases_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                parts = line.split()
                if parts:
                    existing.add(parts[0])
    return existing

def update_readme_table(tag, track_major):
    if not os.path.exists(README_FILE):
        return
    with open(README_FILE, "r", encoding="utf-8") as f:
        lines = f.readlines()

    new_row = f"| `{tag}` | `Oracle Linux {tag}` | [`runalsh/oraclelinux-patch:{tag}`](https://hub.docker.com/r/runalsh/oraclelinux-patch/tags) | [`ghcr.io/runalsh/oraclelinux-patch:{tag}`](https://github.com/users/runalsh/packages/container/package/oraclelinux-patch) |\n"

    inserted = False
    new_lines = []
    
    for i, line in enumerate(lines):
        new_lines.append(line)
        # Find position after existing track rows e.g. | `9.8`
        if f"| `{track_major}." in line and "| [`runalsh/oraclelinux-patch" in line and not inserted:
            if i + 1 >= len(lines) or not lines[i + 1].startswith(f"| `{track_major}."):
                new_lines.append(new_row)
                inserted = True

    if inserted:
        with open(README_FILE, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
        print(f"Updated {README_FILE} table with tag {tag}.")

def main():
    existing_tags = load_existing_releases(RELEASES_FILE)
    print(f"Loaded existing Oracle tags from {RELEASES_FILE}: {sorted(list(existing_tags))}")

    new_discoveries = []

    # 1. Scan JSON metadata endpoints
    for t in MAJOR_TRACKS:
        print(f"Scanning Oracle Linux track {t} metadata...")
        json_url = f"https://yum.oracle.com/templates/OracleLinux/{t}-template.json"
        
        try:
            req = urllib.request.Request(json_url, headers={"User-Agent": "Mozilla/5.0"})
            data = json.loads(urllib.request.urlopen(req).read().decode("utf-8"))
            
            ver = data.get("version")
            rel = data.get("release")
            base_url = data.get("base_url")
            kvm_img = data.get("kvm", {}).get("image")

            if ver and rel and base_url and kvm_img:
                tag = f"{ver}.{rel}"
                full_url = f"https://yum.oracle.com{base_url}/{kvm_img}"

                if tag not in existing_tags:
                    print(f"✨ NEW RELEASE DISCOVERED VIA METADATA JSON! Tag: {tag} -> {full_url}")
                    new_discoveries.append({
                        "tag": tag,
                        "url": full_url,
                        "track_major": ver
                    })
                    existing_tags.add(tag)
                else:
                    print(f"Track {t} metadata release {tag} already present in releases.txt.")
        except Exception as e:
            print(f"Error checking {t} metadata: {e}")

    # 2. Scan oracle-linux-templates.html page
    print("\nScanning oracle-linux-templates.html page for additional releases...")
    try:
        page_url = "https://yum.oracle.com/oracle-linux-templates.html"
        req = urllib.request.Request(page_url, headers={"User-Agent": "Mozilla/5.0"})
        html = urllib.request.urlopen(req).read().decode("utf-8")
        links = re.findall(r"https://yum\.oracle\.com/templates/OracleLinux/OL(\d+)/u(\d+)/x86_64/(OL\d+U\d+_x86_64-kvm-[^\s\"'>]+\.(?:qcow2|qcow))", html)
        
        for major, minor, filename in links:
            if major in ["8", "9", "10"]:
                tag = f"{major}.{minor}"
                full_url = f"https://yum.oracle.com/templates/OracleLinux/OL{major}/u{minor}/x86_64/{filename}"
                if tag not in existing_tags:
                    print(f"✨ NEW RELEASE DISCOVERED VIA TEMPLATES HTML! Tag: {tag} -> {full_url}")
                    new_discoveries.append({
                        "tag": tag,
                        "url": full_url,
                        "track_major": major
                    })
                    existing_tags.add(tag)
    except Exception as e:
        print(f"Error scanning oracle-linux-templates.html: {e}")

    if not new_discoveries:
        print("\nNo new Oracle Linux point releases found. Everything up to date!")
        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write("NEW_RELEASE_FOUND=false\n")
        return

    print(f"\nDiscovered {len(new_discoveries)} new release(s):")
    for item in new_discoveries:
        print(f" - {item['tag']}: {item['url']}")

    # Update releases.txt and README.md
    with open(RELEASES_FILE, "a", encoding="utf-8") as f:
        for item in new_discoveries:
            f.write(f"{item['tag']} {item['url']}\n")
            update_readme_table(item['tag'], item['track_major'])

    print(f"Updated {RELEASES_FILE} and {README_FILE}.")

    # Set GitHub Actions output environment variables
    first_new = new_discoveries[0]
    if "GITHUB_ENV" in os.environ:
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
            f.write("NEW_RELEASE_FOUND=true\n")
            f.write(f"NEW_TAG={first_new['tag']}\n")
            f.write(f"NEW_URL={first_new['url']}\n")

if __name__ == "__main__":
    main()

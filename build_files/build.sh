#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Hyprland + end-4 illogical-impulse dependencies
# Mirrors sdata/dist-fedora/install-deps.sh from https://github.com/end-4/dots-hyprland,
# but installs into the image instead of onto a running system.

DOTS_REF="main"
DOTS_RAW="https://raw.githubusercontent.com/end-4/dots-hyprland/${DOTS_REF}"
DEPS_TOML=/tmp/feddeps.toml
curl -fsSL --retry 3 -o "$DEPS_TOML" "${DOTS_RAW}/sdata/dist-fedora/feddeps.toml"

# Not useful on an image-based system (bootloader/login themes are managed by the base image)
SKIP_PACKAGES="grub2-breeze-theme sddm-breeze"

mapfile -t COPRS < <(python3 -c '
import sys, tomllib
print("\n".join(tomllib.load(open(sys.argv[1], "rb")).get("copr", {}).get("repos", [])))
' "$DEPS_TOML")

for copr in "${COPRS[@]}"; do
    dnf5 -y copr enable "$copr"
done

# Prebuilt quickshell-git / matugen RPMs published by end-4
II_REPO=/tmp/ii-repo
mkdir -p "$II_REPO"
dnf5 install -y createrepo_c
curl -fsSL --retry 3 https://api.github.com/repos/end-4/ii-package-builds/releases/tags/packages-fedora |
    python3 -c 'import json, sys; print("\n".join(a["browser_download_url"] for a in json.load(sys.stdin)["assets"]))' |
    while read -r url; do
        curl -fsSL --retry 3 -o "$II_REPO/$(basename "$url")" "$url"
    done
createrepo_c "$II_REPO"

# One "group|install opts|packages" line per dependency group
python3 -c '
import sys, tomllib
skip = set(sys.argv[2].split())
for name, group in tomllib.load(open(sys.argv[1], "rb"))["groups"].items():
    opts = " ".join(group.get("install_opts", []))
    pkgs = " ".join(sorted(set(group.get("packages", [])) - skip))
    print(f"{name}|{opts}|{pkgs}")
' "$DEPS_TOML" "$SKIP_PACKAGES" |
    while IFS='|' read -r group opts pkgs; do
        echo "Installing dependency group: $group"
        # Bazzite replaces some Fedora packages with its own builds (e.g. terra-wireplumber);
        # keep those instead of pulling in the conflicting Fedora version
        missing=""
        for pkg in $pkgs; do
            rpm -q --quiet --whatprovides "$pkg" || missing="$missing $pkg"
        done
        pkgs="$missing"
        [[ -z "${pkgs// /}" ]] && continue
        if [[ "$group" == "illogical-impulse" ]]; then
            opts="$opts --repofrompath=illogical-impulse,file://$II_REPO --setopt=illogical-impulse.gpgcheck=0"
        fi
        # shellcheck disable=SC2086
        dnf5 install -y $opts $pkgs
    done

# Disable COPRs so they don't end up enabled on the final image
for copr in "${COPRS[@]}"; do
    dnf5 -y copr disable "$copr"
done

### SDDM login theme: https://github.com/Keyitdev/sddm-astronaut-theme
SDDM_THEME_COMMIT="abb3163c724935af888ba5ea9ac0c4f22afd8048"
SDDM_THEME_VARIANT="hyprland_kath"
SDDM_THEME_DIR=/usr/share/sddm/themes/sddm-astronaut-theme

dnf5 install -y qt6-qtsvg qt6-qtvirtualkeyboard qt6-qtmultimedia
mkdir -p "$SDDM_THEME_DIR"
curl -fsSL --retry 3 "https://github.com/Keyitdev/sddm-astronaut-theme/archive/${SDDM_THEME_COMMIT}.tar.gz" |
    tar -xz --strip-components=1 -C "$SDDM_THEME_DIR"
sed -i "s#^ConfigFile=.*#ConfigFile=Themes/${SDDM_THEME_VARIANT}.conf#" "$SDDM_THEME_DIR/metadata.desktop"
mkdir -p /usr/share/fonts/sddm-astronaut
cp -a "$SDDM_THEME_DIR"/Fonts/. /usr/share/fonts/sddm-astronaut/
mkdir -p /usr/lib/sddm/sddm.conf.d
cat > /usr/lib/sddm/sddm.conf.d/zz-hyprzite-theme.conf <<'EOF'
[Theme]
Current=sddm-astronaut-theme

[General]
InputMethod=qtvirtualkeyboard
EOF

### Changes the dotfiles' setup step would otherwise make under the read-only /usr

# ydotool ships only a system unit; the dotfiles run it as a user service
if [[ ! -e /usr/lib/systemd/user/ydotool.service ]]; then
    ln -s ../../system/ydotool.service /usr/lib/systemd/user/ydotool.service
fi

### Require this repo's cosign signature when updating the image
python3 - <<'EOF'
import json
path = "/etc/containers/policy.json"
with open(path) as f:
    policy = json.load(f)
policy.setdefault("transports", {}).setdefault("docker", {})["ghcr.io/teddybusted/hyprzite"] = [{
    "type": "sigstoreSigned",
    "keyPath": "/etc/pki/containers/hyprzite.pub",
    "signedIdentity": {"type": "matchRepository"},
}]
with open(path, "w") as f:
    json.dump(policy, f, indent=4)
EOF

#### Services

systemctl enable podman.socket

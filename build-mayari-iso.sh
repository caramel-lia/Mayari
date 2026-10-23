#!/bin/bash
#
# build-mayari-iso.sh
# Builds a bootable, installable Mayari ISO on top of Void Linux's own
# live-image tooling (void-mklive). Run this ON a Void Linux machine
# (or Void in a VM) with root and internet access — NOT inside a chroot
# or container without loop-device / squashfs support.
#
# What this does:
#   1. Clones/updates void-mklive
#   2. Builds a live ISO that includes:
#        - XFCE desktop (lightdm login)
#        - The full Mayari tool list (packages-mayari.lst)
#        - Mayari branding: os-release, issue, MOTD, prompt, wallpaper
#        - Categorized application menu (Information Gathering, Web, etc.)
#   3. Output: mayari-<date>-x86_64.iso in this directory
#
# After building, the ISO boots to a live XFCE session (user: anon,
# passwordless) with a "Install" shortcut that runs void-installer —
# exactly like Kali/Parrot's live-then-install flow.
#
set -Eeuo pipefail

log()  { printf '\n\033[1;35m[Mayari build]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[Mayari warning]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[Mayari error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo ./build-mayari-iso-fixed.sh"
command -v xbps-install >/dev/null 2>&1 || die "This script requires Void Linux with XBPS installed."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$SCRIPT_DIR/.mklive-work"
MKLIVE_DIR="$WORKDIR/void-mklive"
PKG_FILE="$SCRIPT_DIR/packages-mayari.lst"
INCLUDE_DIR="$SCRIPT_DIR/include"
OUT_NAME="mayari-$(date +%Y%m%d)-x86_64.iso"

[[ -f $PKG_FILE ]] || die "Missing package list: $PKG_FILE"
[[ -d $INCLUDE_DIR ]] || die "Missing branding directory: $INCLUDE_DIR"

# Package names, not command names: xorriso supplies ISO creation tools.
# libisoburn is a source/library name, not a required separate XBPS package.
BUILD_PACKAGES=(git squashfs-tools xorriso grub-i386-efi grub-x86_64-efi mtools erofs-utils dialog bash)

log "Synchronizing XBPS repository metadata"
xbps-install -S || die "Cannot synchronize XBPS repositories. Check network/repository configuration."

missing=()
for package in "${BUILD_PACKAGES[@]}"; do
  if xbps-query -i "$package" >/dev/null 2>&1; then
    log "Already installed: $package"
  else
    log "Missing dependency: $package"
    missing+=("$package")
  fi
done

if (( ${#missing[@]} > 0 )); then
  log "Installing missing build dependencies: ${missing[*]}"
  xbps-install -y "${missing[@]}" || die "Dependency installation failed. Verify that the repositories support these packages."
else
  log "All build dependencies are installed"
fi

for tool in git xorriso mksquashfs; do
  command -v "$tool" >/dev/null 2>&1 || die "Required tool '$tool' is unavailable even after installing dependencies."
done

mkdir -p "$WORKDIR"
if [[ ! -d "$MKLIVE_DIR/.git" ]]; then
  [[ ! -e "$MKLIVE_DIR" ]] || die "$MKLIVE_DIR exists but is not a Git repository. Move it aside and retry."
  log "Cloning void-mklive"
  git clone --depth 1 https://github.com/void-linux/void-mklive.git "$MKLIVE_DIR"
else
  log "Updating void-mklive"
  git -C "$MKLIVE_DIR" pull --ff-only || die "Cannot fast-forward void-mklive checkout. Resolve local changes first."
fi

[[ -x "$MKLIVE_DIR/mkiso.sh" ]] || die "mkiso.sh was not found or is not executable in void-mklive."

# Trim comments/blank lines and combine package names as space-separated arguments.
# Reject malformed entries instead of feeding them to XBPS as packages.
packages=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  read -r -a words <<< "$line"
  for pkg in "${words[@]}"; do
    [[ "$pkg" =~ ^[[:alnum:]_+.-]+$ ]] || die "Invalid package name in $PKG_FILE: $pkg"
    packages+=("$pkg")
  done
done < "$PKG_FILE"

if (( ${#packages[@]} == 0 )); then
  warn "Package list is empty; generating standard XFCE live ISO with Mayari branding."
fi

log "Building XFCE live image with installer and Mayari customizations"
cd "$MKLIVE_DIR"
# mkiso.sh adds the installer, XFCE, desktop services, and bootloader packages.
# Additional mklive.sh flags follow --, per upstream documentation.
./mkiso.sh -a x86_64 -b xfce -- \
  -p "${packages[*]}" \
  -I "$INCLUDE_DIR" \
  -T "Mayari Live" \
  -o "$SCRIPT_DIR/$OUT_NAME"

[[ -s "$SCRIPT_DIR/$OUT_NAME" ]] || die "Build exited but ISO is missing or empty."
log "Done: $SCRIPT_DIR/$OUT_NAME"
printf 'To write to a USB drive (replace /dev/sdX with the correct whole disk):\n'
printf '  sudo dd if=%q of=/dev/sdX bs=4M status=progress conv=fsync\n' "$SCRIPT_DIR/$OUT_NAME"
printf 'Or attach the ISO as a virtual CD/DVD in VMware or VirtualBox.\n'


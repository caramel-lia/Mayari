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
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./build-mayari-iso.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$SCRIPT_DIR/.mklive-work"
MKLIVE_DIR="$WORKDIR/void-mklive"

log()  { printf '\n\033[1;35m[Mayari build] %s\033[0m\n' "$1"; }

log "Installing build dependencies"
xbps-install -Sy git squashfs-tools xorriso grub-i386-efi grub-x86_64-efi \
  mtools erofs-utils libisoburn dialog bash

mkdir -p "$WORKDIR"
if [[ ! -d "$MKLIVE_DIR" ]]; then
  log "Cloning void-mklive"
  git clone https://github.com/void-linux/void-mklive.git "$MKLIVE_DIR"
else
  log "Updating void-mklive"
  git -C "$MKLIVE_DIR" pull
fi

PKG_LIST=$(grep -v '^\s*#' "$SCRIPT_DIR/packages-mayari.lst" | grep -v '^\s*$' | tr '\n' ' ')

OUT_NAME="mayari-$(date +%Y%m%d)-x86_64"

log "Building ISO (this takes a while — downloads every package above)"
cd "$MKLIVE_DIR"
./mklive.sh \
  -a x86_64 \
  -p "$PKG_LIST" \
  -I "$SCRIPT_DIR/include" \
  -T "Mayari Live" \
  -o "$SCRIPT_DIR/${OUT_NAME}.iso"

log "Done: $SCRIPT_DIR/${OUT_NAME}.iso"
echo "Flash it with: sudo dd if=${OUT_NAME}.iso of=/dev/sdX bs=4M status=progress"
echo "Or attach it directly as a VMware CD/DVD image to boot and install."

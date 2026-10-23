#!/bin/bash
#
# mayari-postinstall.sh
# Turns an EXISTING Void Linux install into "Mayari": installs the tool
# catalog from packages-mayari.lst, then applies branding + boot theme by
# overlaying include/ onto the live filesystem (same files the ISO builder
# uses) and running the activation steps GRUB/Plymouth need.
#
# Run this FROM the extracted mayari-build/ directory:
#   chmod +x mayari-postinstall.sh
#   sudo ./mayari-postinstall.sh            # full install
#   sudo ./mayari-postinstall.sh --minimal  # skip wireless/exploit/forensics/msf/wordlists
#
set -uo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo ./mayari-postinstall.sh)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIMAL=false
[[ "${1:-}" == "--minimal" ]] && MINIMAL=true

log()  { printf '\n\033[1;35m[Mayari] %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$1"; }

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ---------------------------------------------------------------------------
# 1. System update + tool catalog (from packages-mayari.lst)
# ---------------------------------------------------------------------------
log "Updating xbps and the base system"
xbps-install -Sy xbps
xbps-install -Suy

PKG_FILE="$SCRIPT_DIR/packages-mayari.lst"
if [[ ! -f "$PKG_FILE" ]]; then
  warn "packages-mayari.lst not found next to this script — skipping tool install"
else
  log "Installing tool catalog from packages-mayari.lst"
  while read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if $MINIMAL && [[ "$pkg" =~ ^(aircrack-ng|reaver|bettercap|kismet|horst|mdk4|pixiewps|hcxtools|binwalk|radare2|rizin|gdb|gdb-multiarch|gdb-peda|ltrace|strace|capstone|yara|upx-ucl|ropper|nasm|exploitdb|sleuthkit|foremost|scalpel|testdisk|exiv2|hashdeep|bulk-extractor|ext4magic|extundelete|plaso|rifiuti2|regripper|samdump2|chntpw)$ ]]; then
      continue
    fi
    if xbps-query -R "$pkg" >/dev/null 2>&1; then
      xbps-install -y "$pkg" || warn "Failed to install $pkg, skipping"
    else
      warn "$pkg not found in repo pool, skipping"
    fi
  done < "$PKG_FILE"
fi

log "Installing Python-based tools via pip (user-level)"
sudo -u "$REAL_USER" python3 -m pip install --user --upgrade impacket pwntools requests \
  || warn "Some pip packages failed — check network/pip output above"

if ! $MINIMAL; then
  log "Cloning SecLists (wordlists) to /usr/share/seclists"
  if [[ ! -d /usr/share/seclists ]]; then
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists \
      || warn "SecLists clone failed — check network"
  fi
fi

for svc in dbus; do
  if [[ -d "/etc/sv/$svc" && ! -e "/var/service/$svc" ]]; then
    ln -s "/etc/sv/$svc" /var/service/
  fi
done

# ---------------------------------------------------------------------------
# 2. Branding + boot theme: overlay include/ onto the live filesystem
# ---------------------------------------------------------------------------
if [[ -d "$SCRIPT_DIR/include" ]]; then
  log "Applying Mayari branding + boot theme (copying include/ over /)"
  cp -a "$SCRIPT_DIR/include/." /
  chmod +x /usr/local/bin/mayari-* 2>/dev/null || true
  chmod +x /etc/profile.d/mayari-prompt.sh 2>/dev/null || true
else
  warn "include/ directory not found next to this script — skipping branding"
fi

# ---------------------------------------------------------------------------
# 3. Activate the boot theme: Plymouth needs the dracut module + a rebuilt
#    initramfs, GRUB needs its config regenerated to pick up /etc/default/grub
# ---------------------------------------------------------------------------
log "Activating boot splash + GRUB theme"

if ! xbps-query -R plymouth >/dev/null 2>&1; then
  warn "plymouth not in repo pool — boot splash will not be active"
elif ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
  xbps-install -y plymouth || warn "Failed to install plymouth"
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme -R mayari \
    || warn "plymouth-set-default-theme failed — check /usr/share/plymouth/themes/mayari/mayari.script for syntax issues"
else
  warn "plymouth-set-default-theme not found; skipping splash activation"
fi

if command -v grub-mkconfig >/dev/null 2>&1; then
  if [[ -d /sys/firmware/efi ]]; then
    GRUB_CFG="/boot/grub/grub.cfg"
  else
    GRUB_CFG="/boot/grub/grub.cfg"
  fi
  grub-mkconfig -o "$GRUB_CFG" || warn "grub-mkconfig failed — re-run manually after checking /etc/default/grub"
else
  warn "grub-mkconfig not found (GRUB not installed as bootloader?) — skipping GRUB theme activation"
fi

# ---------------------------------------------------------------------------
# 4. Default wallpaper for the real user's XFCE session (system-wide xfconf
#    default in include/ covers NEW users; this applies it to the existing one)
# ---------------------------------------------------------------------------
if command -v xfconf-query >/dev/null 2>&1 && [[ -f /usr/share/backgrounds/mayari/mayari-wallpaper.png ]]; then
  log "Setting default wallpaper for $REAL_USER"
  sudo -u "$REAL_USER" DISPLAY=:0 xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
    -s /usr/share/backgrounds/mayari/mayari-wallpaper.png 2>/dev/null \
    || warn "Could not set wallpaper live (no X session running) — it will apply on next login via the shipped xfconf default"
fi

chown -R "$REAL_USER":"$REAL_USER" "$REAL_HOME/.local" 2>/dev/null || true

log "Mayari setup complete."
echo "Reboot to see the GRUB theme and Plymouth boot splash."
echo "Re-login (or run 'exec bash -l') to see the new prompt and MOTD."
echo "Run 'mayari-help' for the tool catalog, 'mayari-extra-tools list' for the rest."

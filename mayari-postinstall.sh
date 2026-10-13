#!/bin/bash
#
# mayari-setup.sh
# Turns a fresh Void Linux install into "Mayari" — a Void-based distro
# branded and preloaded for offensive security work.
#
# Usage:
#   chmod +x mayari-setup.sh
#   sudo ./mayari-setup.sh            # full install
#   sudo ./mayari-setup.sh --minimal  # core tools only, skip heavy/GUI stuff
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this as root (sudo ./mayari-setup.sh)" >&2
  exit 1
fi

MINIMAL=false
[[ "${1:-}" == "--minimal" ]] && MINIMAL=true

MAYARI_VERSION="1.0"
MAYARI_CODENAME="Bathala"

log()  { printf '\n\033[1;35m[Mayari] %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$1"; }

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ---------------------------------------------------------------------------
# 1. System update
# ---------------------------------------------------------------------------
log "Updating xbps and the base system"
xbps-install -Sy xbps
xbps-install -Suy

# ---------------------------------------------------------------------------
# 2. Package groups
# ---------------------------------------------------------------------------
CORE_PKGS=(
  git curl wget tmux vim neovim python3 python3-pip python3-devel
  base-devel ruby ruby-devel go rust unzip zip tree jq
)
RECON_PKGS=(
  nmap masscan whois dnsutils bind-utils netcat-openbsd socat
  traceroute tcpdump wireshark-qt amass
)
WEB_PKGS=( nikto sqlmap gobuster ffuf whatweb )
PASSWORD_PKGS=( john hashcat hydra-gtk medusa )
WIRELESS_PKGS=( aircrack-ng reaver bettercap )
EXPLOIT_PKGS=( binwalk radare2 gdb gdb-multiarch )
FORENSICS_PKGS=( foremost sleuthkit exiftool steghide )

install_group() {
  local name="$1"; shift
  log "Installing: $name"
  for pkg in "$@"; do
    if xbps-query -R "$pkg" >/dev/null 2>&1; then
      xbps-install -y "$pkg" || warn "Failed to install $pkg, skipping"
    else
      warn "$pkg not found in repo pool, skipping"
    fi
  done
}

install_group "Core / build tools" "${CORE_PKGS[@]}"
install_group "Recon / network" "${RECON_PKGS[@]}"
install_group "Web app testing" "${WEB_PKGS[@]}"
install_group "Password attacks" "${PASSWORD_PKGS[@]}"

if ! $MINIMAL; then
  install_group "Wireless" "${WIRELESS_PKGS[@]}"
  install_group "Binary / exploit dev" "${EXPLOIT_PKGS[@]}"
  install_group "Forensics" "${FORENSICS_PKGS[@]}"
fi

log "Installing Python-based tools via pip (user-level)"
sudo -u "$REAL_USER" python3 -m pip install --user --upgrade impacket pwntools requests \
  || warn "Some pip packages failed — check network/pip output above"

if ! $MINIMAL; then
  log "Installing Metasploit Framework (Rapid7 installer)"
  if [[ ! -d /opt/metasploit-framework ]]; then
    curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
      -o /tmp/msfinstall || warn "Could not fetch Metasploit installer"
    if [[ -s /tmp/msfinstall ]]; then
      chmod 755 /tmp/msfinstall
      /tmp/msfinstall || warn "Metasploit installer failed — install manually later"
    fi
  else
    log "Metasploit already present, skipping"
  fi
fi

for svc in dbus; do
  if [[ -d "/etc/sv/$svc" && ! -e "/var/service/$svc" ]]; then
    ln -s "/etc/sv/$svc" /var/service/
  fi
done

if ! $MINIMAL; then
  log "Cloning SecLists (wordlists) to /usr/share/seclists"
  if [[ ! -d /usr/share/seclists ]]; then
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists \
      || warn "SecLists clone failed — check network"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Branding: os-release, issue, MOTD, ASCII logo, prompt
# ---------------------------------------------------------------------------
log "Applying Mayari branding"

# /etc/os-release — this is what neofetch, GNOME, GTK file pickers, etc. read
cat > /etc/os-release <<EOF
NAME="Mayari"
PRETTY_NAME="Mayari GNU/Linux ${MAYARI_VERSION} (${MAYARI_CODENAME})"
ID=mayari
ID_LIKE=void
VERSION="${MAYARI_VERSION} (${MAYARI_CODENAME})"
VERSION_ID="${MAYARI_VERSION}"
BUILD_ID=rolling
ANSI_COLOR="1;35"
HOME_URL="https://example.com/mayari"
LOGO=mayari-logo
EOF

# Keep a record of the original Void identity for package tooling that checks it
if [[ ! -f /etc/mayari-release ]]; then
  echo "Mayari ${MAYARI_VERSION} \"${MAYARI_CODENAME}\" (built on Void Linux)" > /etc/mayari-release
fi

# ASCII logo shown at login (pre-session, via /etc/issue) and in MOTD
cat > /etc/mayari-logo.txt <<'LOGO'
   /\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
  /  M   A   Y   A   R   I          \\
 /   Void-based offensive security     \\
/_______________________________________\\
LOGO

cat > /etc/issue <<EOF
\e[1;35m
$(cat /etc/mayari-logo.txt)
\e[0m
Mayari ${MAYARI_VERSION} "${MAYARI_CODENAME}" \n \l

EOF

# MOTD shown after login
mkdir -p /etc/mayari
cat > /etc/mayari/motd <<EOF
\033[1;35m$(cat /etc/mayari-logo.txt)\033[0m

Mayari GNU/Linux ${MAYARI_VERSION} "${MAYARI_CODENAME}"
Base: Void Linux  |  Kernel: \$(uname -r)
Toolset: recon, web, password, wireless, exploit-dev, forensics

Type 'mayari-help' for an overview of installed tool categories.
EOF

if ! grep -q 'cat /etc/mayari/motd' /etc/profile 2>/dev/null; then
  cat >> /etc/profile <<'EOF'

# Mayari welcome banner (interactive shells only)
if [ -n "$PS1" ] && [ -f /etc/mayari/motd ]; then
  echo -e "$(cat /etc/mayari/motd)"
fi
EOF
fi

# Custom prompt accent so shells are visibly "Mayari", not vanilla Void
PROFILE_D=/etc/profile.d
mkdir -p "$PROFILE_D"
cat > "$PROFILE_D/mayari-prompt.sh" <<'EOF'
# Mayari shell prompt
export PS1='\[\e[1;35m\][mayari]\[\e[0m\] \[\e[1;34m\]\u@\h\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '
EOF
chmod +x "$PROFILE_D/mayari-prompt.sh"

# mayari-help: quick reference command
cat > /usr/local/bin/mayari-help <<'EOF'
#!/bin/bash
echo "Mayari tool categories:"
echo "  Recon:       nmap, masscan, whois, amass, tcpdump, wireshark"
echo "  Web:         nikto, sqlmap, gobuster, ffuf, whatweb"
echo "  Passwords:   john, hashcat, hydra, medusa"
echo "  Wireless:    aircrack-ng, reaver, bettercap"
echo "  Exploit dev: binwalk, radare2, gdb, pwntools, metasploit (if installed)"
echo "  Forensics:   foremost, sleuthkit, exiftool, steghide"
echo "  Wordlists:   /usr/share/seclists"
EOF
chmod +x /usr/local/bin/mayari-help

chown -R "$REAL_USER":"$REAL_USER" "$REAL_HOME/.local" 2>/dev/null || true

log "Mayari setup complete."
echo "Re-login (or run 'exec bash -l') to see the new prompt and MOTD."
echo "Run 'mayari-help' anytime for the tool category reference."

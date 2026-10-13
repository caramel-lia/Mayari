# Mayari

A Void Linux–based offensive-security distro, structured like Kali/Parrot:
a curated tool catalog, a categorized application menu, and distro-level
branding, built as an installable live ISO.

## Project layout

```
mayari-build/
├── build-mayari-iso.sh      # Master builder — produces the bootable ISO
├── packages-mayari.lst      # Full tool list, grouped by category
├── mayari-postinstall.sh    # Alternative: brand+tool an EXISTING Void install
└── include/                 # Files copied verbatim into the live rootfs
    ├── etc/
    │   ├── os-release               # Distro identifies as "Mayari"
    │   ├── issue                    # Boot-time banner
    │   ├── mayari/motd              # Post-login message
    │   ├── mayari/packages-mayari.lst
    │   ├── profile.d/mayari-prompt.sh
    │   ├── lightdm/lightdm-gtk-greeter.conf
    │   └── xdg/menus/applications-merged/mayari.menu
    └── usr/
        ├── share/desktop-directories/mayari-*.directory   # Menu categories
        ├── share/applications/mayari-*.desktop             # Tool launchers
        ├── share/backgrounds/mayari/mayari-wallpaper.svg
        └── local/bin/
            ├── mayari-help           # Prints the tool category cheat sheet
            ├── mayari-get-wordlists  # Clones SecLists
            └── mayari-msf-install    # Installs Metasploit (not in Void repos)
```

## Two ways to use this

### A. Build a real bootable ISO (the "like Kali/Parrot" option)

This uses Void's own live-image builder, `void-mklive`, the same tool the
Void project uses to build official live images.

**Requirements:** run this on a real or virtual Void Linux machine with
root and internet access — not inside this sandboxed container (no network
or loop-device access here, so the build itself can't be run or tested from
this chat).

```bash
chmod +x build-mayari-iso.sh
sudo ./build-mayari-iso.sh
```

This clones `void-mklive`, pulls every package in `packages-mayari.lst`,
overlays everything in `include/` onto the live filesystem, and outputs
`mayari-YYYYMMDD-x86_64.iso` — a live-boot ISO with XFCE, branding, and the
full toolset, with the standard Void installer (`void-installer`) available
from the live session for installing to disk, exactly like the Kali/Parrot
live-then-install flow.

Boot it in VMware the same way you booted the original Void ISO (attach as
CD/DVD, power on), try it live, then run `void-installer` to put it on disk.

### B. Brand + tool an existing Void install (quicker, no ISO)

If you don't want to build an ISO right now, `mayari-postinstall.sh` (the
script from earlier in this conversation) does the same branding and tool
install directly on a system you've already installed Void onto. Good for
testing the tool list and menu before committing to a full ISO build.

## Tool coverage vs. Kali

Kali's ~600-tool catalog leans heavily on Debian-specific packaging (and a
few Debian-only metapackages like `kali-linux-everything`). Void's repo is
much smaller, so Mayari covers things in two tiers:

1. **`packages-mayari.lst`** — every Kali-listed tool that has a real Void
   package, grouped into the same categories Kali uses (Recon, Vuln
   Analysis, Web, Passwords, Wireless, Exploitation/RE, Sniffing/Spoofing,
   Forensics, Reporting).
2. **`mayari-extra-tools`** (installed to `/usr/local/bin`) — everything
   else: tools with no Void package at all, installed via `go install`,
   `pip`, `gem`, or a `git clone`, plus pointers to the handful of tools
   that need a manual, licensed, or Docker-based install no script should
   do blindly (Burp Suite Community, OWASP ZAP, BloodHound CE, Ghidra,
   Autopsy, Dradis, Faraday). Run `mayari-extra-tools list` on the live
   system for the full category breakdown, or `mayari-extra-tools all` to
   pull everything it can install non-interactively.

A few tools from Kali's list genuinely can't appear here regardless of
packaging: **Mimikatz** reads Windows LSASS memory and only runs on
Windows — it's not something you install on a Linux distro, Kali included
(Kali ships it only as a Windows payload to drop on a target).

## Customizing

- **Tool list**: edit `packages-mayari.lst`. Verify package names with
  `xbps-query -Rs <name>` since Void repo names shift over time.
- **Menu categories**: add more `.desktop` files to
  `include/usr/share/applications/`, each with a `Categories=Mayari-X;` line
  matching one of the categories defined in
  `include/etc/xdg/menus/applications-merged/mayari.menu`.
- **Branding**: `include/etc/os-release`, `include/etc/issue`, and
  `include/usr/share/backgrounds/mayari/mayari-wallpaper.svg` control the
  name, boot banner, and wallpaper. Swap the SVG for a PNG/JPG logo if you
  have real artwork — just update the `background=` path in
  `lightdm-gtk-greeter.conf` to match.
- **Codename/version**: set near the top of `build-mayari-iso.sh`'s
  companion branding files (`include/etc/os-release`,
  `include/etc/mayari-release`).

## Notes / honest limitations

- This isn't a from-scratch distro (no distro is, really) — it's Void with
  a curated package set, menu, and branding layer, which is exactly how
  Kali (Debian-based) and Parrot (also Debian-based) are built too.
- `void-mklive` requires real build tooling (squashfs, xorriso, loop
  devices) that isn't available in this sandboxed environment, so the ISO
  build itself needs to run on your own machine/VM.
- Metasploit has no Void package, so it's installed via Rapid7's official
  installer script (`mayari-msf-install`) rather than baked into the ISO,
  keeping build size down and avoiding an unofficial package.

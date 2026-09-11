# 🐧 Clean CachyOS Installation Guide for Dotfiles

*Read this in other languages:* [Español](cachyos-install-guide.es.md)

This guide documents the recommended package selection for installing **CachyOS** in a clean mode (**CLI / No Desktop**), applicable to both desktop workstations (**Desktop**) and portable computers (**Laptop**).

The goal is to establish an ultra-lightweight, optimized base free of redundant or conflicting packages, preparing the system to seamlessly deploy the modular dotfiles ecosystem (`dotfiles`, `dotfiles-mangowm`, `dotfiles-bspwm`, `dotfiles-system`).

---

## ⚙️ 1. Initial System Configuration

When starting the CachyOS installer (Calamares GUI or `cachyos-cli-installer`):

| Option | Recommended Selection | Rationale |
| :--- | :--- | :--- |
| **Bootloader** | **Limine** (or `systemd-boot`) | Minimalist, blazing fast, and free of heavy bloat layers. |
| **Filesystem** | **Btrfs** (or Ext4) | Optimized subvolumes and transparent ZSTD compression. |
| **Kernel** | **`linux-cachyos`** (Default) | Optimal performance with CPU optimizations and the BORE scheduler. |
| **Desktop Environment** | **`No Desktop` / `None` / `CLI`** | Pure CLI base without preinstalled graphical environments or display managers that could collide with dotfiles. |

---

## 📦 2. Additional Packages Selection (Installation Checklist)

On the **"Additional Packages"** selection screen after choosing *No Desktop*, configure the checkboxes according to the following lists.

### 🚫 CachyOS Packages & Overrides (Critical: Uncheck All)
> [!WARNING]
> Unchecking these packages is essential. They inject global configurations into `/etc` or templates into `$HOME` that collide with GNU Stow modular package management.

- [ ] `cachyos-settings` *(Critical to uncheck: injects global default configs into `/etc`)*
- [ ] `cachyos-zsh-config` *(Critical to uncheck: collides with the dotfiles Zsh suite)*
- [ ] `cachyos-fish-config`
- [ ] `cachyos-micro-settings` *(Critical to uncheck: overrides `micro` editor configs)*
- [ ] `cachyos-hello`
- [ ] `cachyos-packageinstaller`
- [ ] `cachyos-wallpapers`

---

### 🌐 Network & Connectivity
- [x] `networkmanager` *(Essential: unified network management for Ethernet and Wi-Fi)*
- [x] `dnsutils` *(DNS diagnostics utilities such as `dig` and `nslookup`)*
- [x] `ethtool` *(Wired network interface diagnostics)*
- [x] `wpa_supplicant` *(Wi-Fi backend. **Keep checked** if the machine has Wi-Fi or is a Laptop; optional on wired-only Desktops)*
- [x] `wireless-regdb` *(Regional Wi-Fi regulatory frequency database. **Keep checked** if using Wi-Fi)*
- [ ] `modemmanager` *(**Uncheck** unless your machine has an integrated WWAN/LTE SIM slot or USB cellular modem)*
- [ ] `usb_modeswitch` *(**Uncheck** unless using USB mobile broadband modems)*
- [ ] `iwd` *(**Uncheck**: can cause conflicts with the default NetworkManager backend)*
- [ ] `dnsmasq` *(**Uncheck**: unnecessary unless running a dedicated local DNS server)*
- [ ] `nss-mdns` *(Local `.local` domain resolution, unnecessary for most setups)*
- [ ] `networkmanager-openvpn` *(Optional if you manage OpenVPN connections directly through NetworkManager)*
- [ ] `zl2tpd` *(Legacy L2TP VPN protocol)*

---

### 📶 Bluetooth
> [!NOTE]
> If your machine is a desktop without an internal Bluetooth card or USB Bluetooth dongle, you can safely uncheck all packages in this group.

- [x] `bluez` *(Bluetooth protocol stack for headphones, keyboards, mice, and game controllers)*
- [x] `bluez-utils` *(CLI tools including `bluetoothctl`)*
- [x] `bluez-libs`
- [x] `bluez-hid2hci` *(Mode switching support for USB Bluetooth adapters/dongles)*
- [ ] `bluez-obex` *(Bluetooth file transfer daemon, generally unnecessary)*

---

### 🔋 Power Management
- [x] `power-profiles-daemon` *(Recommended: standard Performance / Balanced / Power-saver profile manager, integrated with Waybar and Polybar)*
- [x] `upower` *(Essential on **Laptops**: exports battery percentage and charge state to status bars. Optional on Desktops)*
- [ ] `cpupower` *(**Uncheck**: can conflict with `power-profiles-daemon`)*

---

### 🔊 Audio & Multimedia
- [x] `pipewire-pulse` *(PulseAudio emulation layer over PipeWire)*
- [x] `wireplumber` *(Native PipeWire session manager)*
- [x] `pipewire-alsa` *(ALSA routing to PipeWire)*
- [x] `alsa-utils` *(Basic console audio tools such as `alsamixer`)*
- [x] `alsa-firmware` *(Firmware for traditional sound cards and chipsets)*
- [x] `sof-firmware` *(Sound Open Firmware: **critical** for modern Intel/AMD laptops and recent motherboards for audio/microphone support)*
- [x] `pavucontrol` *(Fast, lightweight graphical audio mixer)*
- [x] `realtime-privileges` *(Real-time priority group for low-latency audio)*

---

### 🛡️ Security & Firewall
- [x] `ufw` *(Simple, straightforward firewall to protect the machine)*
- [ ] `ufw-extras`

---

### 📦 Package Management & Maintenance
- [x] `shelly` *(Official high-speed CachyOS package manager CLI with repository and AUR support)*
- [x] `pacman-contrib` *(Includes utilities like `paccache` for automated cache cleanup)*
- [x] `pkgfile` *(Locates which package owns an uninstalled command)*
- [x] `rebuild-detector` *(Detects packages that need rebuilding after shared library updates)*
- [x] `reflector` *(Retrieves and sorts the fastest Pacman mirrors)*

---

### 🔤 System Fonts
- [x] `ttf-meslo-nerd` *(Default Nerd Font used across terminal emulators, Starship prompt, and icons)*
- [x] `noto-fonts` *(Universal fallback font for character coverage)*
- [x] `noto-fonts-emoji` *(Official emoji font support)*
- [x] `noto-fonts-cjk` *(Asian character coverage for web browsing and documents)*
- [x] `ttf-dejavu` *(Standard universal mono and sans fallback fonts)*
- [x] `ttf-liberation` *(Metric-compatible replacements for common document fonts)*
- [ ] `awesome-terminal-fonts` *(Redundant with Nerd Fonts)*
- [ ] `cantarell-fonts` *(GNOME-specific font)*
- [ ] `ttf-bitstream-vera`, `ttf-opensans`

---

### 🔌 Hardware Diagnostics & Firmware
- [x] `linux-firmware` *(Official hardware firmware for processors, GPUs, and wireless chipsets)*
- [x] `hwdetect` *(Native CachyOS hardware detection tool)*
- [x] `dmidecode` *(Tool for inspecting hardware specifications and BIOS/SMBIOS data)*
- [x] `mesa-utils` *(OpenGL and Vulkan graphics diagnostics such as `glxinfo`)*
- [x] `mtools` *(FAT32 compatibility tools for USB drives and EFI partitions)*
- [x] `smartmontools` *(Health monitoring for SSD and NVMe drives)*
- [ ] `hdparm` *(Unnecessary on modern SSD/NVMe drives; only relevant for mechanical HDDs)*
- [ ] `dmraid` *(Legacy hardware RAID controllers)*
- [ ] `lsscsi`, `sg3_utils`

---

### 🖼️ Desktop Integration & Codecs
- [x] `bash-completion` *(Standard programmable completion for Bash)*
- [x] `xdg-user-dirs` *(Standard user directories generation: `~/Downloads`, `~/Documents`, etc.)*
- [x] `xdg-utils` *(Standard desktop integration utilities such as `xdg-open`)*
- [x] `ffmpegthumbnailer` *(Video thumbnail generation for Yazi and graphical file managers)*
- [x] `poppler-glib` *(PDF rendering and preview generation)*
- [x] `libgsf`, `libopenraw` *(Thumbnails for documents and RAW image files)*
- [x] `gst-libav`, `gst-plugin-pipewire`, `gst-plugins-bad`, `gst-plugins-ugly` *(Multimedia codecs)*
- [x] `plocate` *(Blazing fast indexed file search CLI)*
- [x] `unzip`, `unrar` *(Archive extraction utilities)*
- [ ] `accountservice` *(Unnecessary without GNOME/GDM display managers)*
- [ ] `libdvdcss`, `vlc-plugins-all`

---

### 💻 Terminal Utilities & Core Tools
- [x] `git` *(Essential version control for cloning and updating dotfiles)*
- [x] `openssh` *(SSH utilities and key generation tools)*
- [x] `micro` *(Default lightweight terminal text editor)*
- [x] `ripgrep` *(High-performance text search tool)*
- [x] `btop` *(Modern system resource monitor for CPU, memory, disks, and network)*
- [x] `fastfetch` *(Clean system information display for terminal sessions)*
- [x] `wget`, `rsync` *(File download and synchronization CLI tools)*
- [x] `pv` *(Pipe Viewer: terminal data throughput monitor)*
- [ ] `alacritty` *(**Uncheck**: the dotfiles installer deploys and configures the optimal terminal for your session: `foot` for MangoWM or `alacritty` for BSPWM)*
- [ ] `nano`, `vim` *(Optional: default editors configured in dotfiles are `micro` or `nvim`)*
- [ ] `duf`, `glances`, `hwinfo`, `meld`

---

## 🚀 3. Next Step: Deploying Dotfiles

Once the CachyOS installation is complete, reboot the computer, remove the installation medium, and log in to the console (TTY) with your user account:

```bash
# 1. Ensure basic connectivity and tools are present
sudo pacman -S --needed git bash

# 2. Launch the interactive dotfiles installer
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

The interactive installer will guide you through:
1. Detecting whether the hardware is a Desktop or Laptop (automatically configuring battery and backlight modules).
2. Selecting your preferred compositor or window manager (**MangoWM** on Wayland or **BSPWM** on X11).
3. Configuring wallpapers, color themes, and system components.

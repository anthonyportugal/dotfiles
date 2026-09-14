# MangoWM Dotfiles

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles-mangowm/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles-mangowm/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://wayland.freedesktop.org"><img src="https://img.shields.io/badge/Display-Wayland-00599C?style=flat-square&logo=wayland&logoColor=white" alt="Wayland"></a>
  <a href="https://github.com/mangowm/mango"><img src="https://img.shields.io/badge/WM-MangoWM-orange?style=flat-square" alt="MangoWM"></a>
  <a href="https://mangowm.github.io/showcase/"><img src="https://img.shields.io/badge/Showcase-MangoWM-orange?style=flat-square&logo=github" alt="MangoWM Showcase"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-cba6f7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Read this in other languages:* [Español](README.es.md)

Autonomous, modular, and minimal Wayland session optimized for **Arch Linux** using [MangoWM](https://github.com/mangowm/mango) as the primary dynamic tiling compositor, officially featured in the [MangoWM Showcase](https://mangowm.github.io/showcase/), and styled with the **Catppuccin Mocha** palette (supporting all 14 hot-swappable accents). It functions completely standalone or composed with the primary modular dotfiles ecosystem.

<p align="center">
  <img src="assets/screenshot.webp" alt="MangoWM Desktop Preview" width="100%">
</p>

> [!TIP]
> 🧩 **Modular Dotfiles Ecosystem:**  
> [Base & CLI](https://github.com/anthonyportugal/dotfiles) • **MangoWM (Wayland) [Current]** • [BSPWM (X11)](https://github.com/anthonyportugal/dotfiles-bspwm) • [Wallpapers](https://github.com/anthonyportugal/walls) • [System](https://github.com/anthonyportugal/dotfiles-system)
> 
> This repository provides a standalone, production-ready Wayland desktop environment and seamlessly integrates with the base dotfiles ecosystem.

---

## ✨ Key Highlights

- 🚀 **Dynamic Wayland Tiling:** Next-generation dynamic tiling compositor with runtime layout switching (*Dwindle, Tile, Grid, Monocle, Scroller*).
- 🎨 **Atomic Dynamic Theming:** Built-in `mango-theme` engine compiles palette tokens into runtime configs for MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, and Wlogout with 14 hot-swappable Mocha accents.
- 📊 **Tailored Waybar & Notifications:** Sleek status bar with interactive popups, live media controls, network status, battery monitors, and Mako notifications.
- 💻 **Integrated Laptop & Recording:** Out-of-the-box hardware brightness control (`brightnessctl`) and Wayland screen recording (`wf-recorder`).
- 🌙 **Eye Comfort & Night Light:** Integrated Gammastep warm color temperature with real-time toggle and status in Waybar.
- 🔒 **GNU Stow & Zero Bloat:** Clean 2-tier architecture (`core`, `desktop`) with built-in dry-run safety and health checks (`doctor`).

---

## 🧱 Modular Architecture

The MangoWM configuration is organized into cumulative profiles managed with [GNU Stow](https://www.gnu.org/software/stow/):

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      MANGO DESKTOP ECOSYSTEM (WAYLAND)                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    DESKTOP PROFILE (UX & Shell)                  │  │
│  │  • Status Bar: Waybar (Catppuccin Mocha, 14 Accents)             │  │
│  │  • App Launcher & Power Menu: Fuzzel, Wlogout                    │  │
│  │  • Notifications & Lock: Mako, Swaylock-effects, Swayidle        │  │
│  │  • Wallpaper & Media: Swaybg, Playerctl, MPV-MPRIS               │  │
│  │  • Night Light & Recording: Gammastep, WF-Recorder               │  │
│  │  • Hardware Backlight & Audio: Brightnessctl, WirePlumber        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      CORE PROFILE (Minimal Wayland)              │  │
│  │  • Window Manager: MangoWM (Dynamic Tiling Compositor)           │  │
│  │  • Terminal: Foot (Wayland Native, Catppuccin Theme)             │  │
│  │  • App Launcher & Portals: Fuzzel, XDG Desktop Portals           │  │
│  │  • Theme Engine: mango-theme (Dynamic Atomic Compilation)        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Profile Breakdown

| Profile | Stow Package | Contents | Intended Target |
| :--- | :--- | :--- | :--- |
| **`core`** | `mango` | Compositor, terminal, launcher, notifications, screen locker, idle daemon, portals, and `mango-theme` engine. | Minimal systems, servers with Wayland, headless setups. |
| **`desktop`** | Reuses `mango` | Core + Waybar status bar, Wlogout power menu, Swaybg wallpapers, Gammastep, Satty screenshot editor, WF-Recorder, and brightness controls. | Full desktop workstations, laptops, and VMs. |

---

## 🛠️ Approved Tech Stack

| Capability | Component | Purpose |
| :--- | :--- | :--- |
| **Compositor** | [`mangowm`](https://github.com/mangowm/mango) | Dynamic tiling Wayland compositor |
| **Status Bar** | `waybar` | Highly customizable CSS-powered Wayland status bar |
| **App Launcher** | `fuzzel` | Fast, lightweight Wayland application launcher |
| **Terminal** | `foot` | Blazing fast, lightweight Wayland-native terminal emulator |
| **Notifications** | `mako` | Lightweight Wayland notification daemon |
| **Screen Locker** | `swaylock` | Screen locker with idle management via `swayidle` |
| **Power Menu** | `wlogout` | Interactive session logout, suspend, and reboot menu |
| **Wallpaper** | `swaybg` | Lightweight Wayland wallpaper setter |
| **Night Light** | `gammastep` | Warm color temperature adjustment |
| **Audio / Media** | PipeWire & Playerctl | Modern audio stack with MPRIS media control |
| **Screenshots** | `satty` & `grim` | Region capture with interactive annotation editor |
| **Screen Recording** | `wf-recorder` | Hardware-accelerated screen video recording |

---

## 🚀 Installation & Profiles

The included `./bin/mango` CLI handles package installation, configuration symlinking, and dynamic theming with built-in dry-run safety.

### 1. Interactive Setup Wizard (Recommended)

Run the interactive setup wizard to configure your profile, installation scope, and choose from all 14 Catppuccin Mocha accent colors:

```bash
# Launch interactive wizard (default: English)
./bin/mango setup

# Or launch directly in Spanish
./bin/mango setup --lang es
```

### 2. Manual Command-Line Bootstrap

If you prefer scripted or non-interactive deployment, use `bootstrap`:

- **Full Desktop Experience:**
  ```bash
  ./bin/mango bootstrap --profile desktop --apply
  ```
- **Minimal Core Session (Window Manager Only):**
  ```bash
  ./bin/mango bootstrap --profile core --apply
  ```

### Helpful Bootstrap Flags

- **Dry-run simulation (Safe check):** Omit `--apply` to preview actions without touching the filesystem:
  ```bash
  ./bin/mango bootstrap --profile desktop
  ```
- **Diagnostics:** Check health, dependencies, and symlink integrity:
  ```bash
  ./bin/mango doctor --profile desktop
  ```
- **Unlink / Clean:** Remove managed symlinks safely:
  ```bash
  ./bin/mango unlink --profile desktop --apply
  ```
- **AUR Backend:** Automatically detected (`shelly`, `paru`, `yay`), or manually specified via `--backend <name>`.

---

## 🔗 Integration with Base Dotfiles

While this repository operates **100% standalone**, it seamlessly integrates with the primary modular dotfiles ecosystem:

- 🌐 **Primary Repository:** [anthonyportugal/dotfiles](https://github.com/anthonyportugal/dotfiles)
- **Shared Ecosystem:** When installed alongside the base repository, MangoWM automatically syncs global dark-mode preferences, shared shell aliases, Neovim configs, and GTK theme tokens via `$HOME/.local/lib/dotfiles/session-preferences`.

---

## 🎨 Theme & Appearance

The desktop is styled with **Catppuccin Mocha**, supporting all **14 official accent palettes** (*Rosewater, Flamingo, Pink, Mauve, Red, Maroon, Peach, Yellow, Green, Teal, Sky, Sapphire, Blue, Lavender*) with **Pink (`#f5c2e7`)** configured as the initial default.

- **Interactive Theme Selector:** Press `Super + Alt + T` to switch color palettes in real-time via Fuzzel.
- **Dynamic Theming CLI (`mango-theme`):**
  ```bash
  # Open interactive theme menu
  mango-theme menu

  # Set a specific accent directly (e.g., mauve, blue, teal, peach)
  mango-theme set catppuccin-mocha-mauve

  # List all available Catppuccin Mocha flavors
  mango-theme list

  # Display current active theme
  mango-theme current
  ```
- **Atomic Rendering:** The `mango-theme` engine compiles palette tokens into runtime configs for MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, and Wlogout under `$XDG_STATE_HOME/mangowm/theme/current/` with atomic symlink promotion and zero background daemons.

---

## ⌨️ Primary Keybindings

### Applications & Launchers

| Shortcut | Action |
| :--- | :--- |
| `Super + Return` | Open Foot terminal (Tiling) |
| `Super + Shift + Return` | Open floating Foot terminal |
| `Super + D` | Open Fuzzel application launcher |
| `Super + B` | Open default web browser (Brave) |
| `Super + E` | Open graphical file manager (Thunar) |
| `Super + F1` / `Super + Shift + ?` | Open interactive keybindings cheat sheet |

### Window & Layout Management

| Shortcut | Action |
| :--- | :--- |
| `Super + C` / `Super + Shift + C` | Close / Kill focused window |
| `Super + T` | Cycle tiling layouts (*Dwindle, Tile, Grid, Monocle, Scroller*) |
| `Super + Escape` | Reload MangoWM configuration |
| `Super + Shift + Escape` | Quit MangoWM session |

### System & Utilities

| Shortcut | Action |
| :--- | :--- |
| `Super + Alt + T` | Open interactive Catppuccin Mocha theme switcher (Fuzzel) |
| `Super + L` | Lock screen immediately (Swaylock) |
| `Super + X` | Open session power menu (Wlogout) |
| `Super + Shift + P` | Open interactive Power Profiles selector (Fuzzel) |
| `Super + Shift + W` | Open interactive Wi-Fi network selector (Fuzzel) |
| `Super + V` | Open interactive audio volume control menu (Fuzzel) |
| `Super + N` | Toggle warm night light (Gammastep with real-time Waybar status) |
| `Super + W` / `Super + Ctrl + W` | Select wallpaper from gallery via Fuzzel (Swaybg) |
| `Print` / `Super + Print` / `Super + Shift + S` | Interactive region screenshot with Satty annotation editor |
| `Shift + Print` | Fullscreen screenshot with Satty editor |
| `Ctrl + Print` | Copy region screenshot directly to clipboard |
| `Super + R` / `Super + Shift + R` | Fullscreen / Interactive region screen recording (wf-recorder) |
| `Super + Alt + R` | Screen recording menu with audio options (Fuzzel) |

---

## 🧪 Testing & Verification

Run the automated test suite locally to verify links, package manifests, and session integrity:

```bash
./tests/scaffold-smoke.sh
./tests/bootstrap-smoke.sh
./tests/session-smoke.sh
```

---

## 👤 Author

Architected and maintained by [Anthony Portugal](https://anthonyportugal.github.io).

---

## 📄 License

Original code and configurations are licensed under the [MIT License](LICENSE).
Catppuccin color palettes and third-party notices are attributed in `THIRD_PARTY_NOTICES.md`.

# MangoWM Dotfiles

<p align="center">
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://wayland.freedesktop.org"><img src="https://img.shields.io/badge/Display-Wayland-00599C?style=flat-square&logo=wayland&logoColor=white" alt="Wayland"></a>
  <a href="https://github.com/mangowm/mango"><img src="https://img.shields.io/badge/WM-MangoWM-orange?style=flat-square" alt="MangoWM"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha_Pink-f5c2e7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Read this in other languages:* [Español](README.es.md)

Autonomous, modular, and minimal Wayland session optimized for **Arch Linux** and **CachyOS** using [MangoWM**](https://github.com/mangowm/mango)** as the primary dynamic tiling compositor, styled with the Catppuccin Mocha palette with Pink accents. It functions completely standalone or composed with the primary modular dotfiles ecosystem.

<p align="center">
  <img src="assets/screenshot.webp" alt="MangoWM Desktop Preview" width="100%">
</p>

> [!TIP]
> This repository provides a standalone, production-ready Wayland desktop environment and seamlessly integrates with the base dotfiles ecosystem.

---

## ✨ Key Highlights

- 🚀 **Dynamic Wayland Tiling:** Next-generation dynamic tiling compositor with runtime layout switching (*Dwindle, Tile, Grid, Monocle, Scroller*).
- 🎨 **Atomic Dynamic Theming:** Built-in `mango-theme` engine compiles palette tokens into runtime configs for MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, and Wlogout.
- 📊 **Tailored Waybar & Notifications:** Sleek status bar with interactive popups, live media controls, network status, battery monitors, and Mako notifications.
- 💻 **Laptop & Creator Features:** Optional, on-demand modules for hardware brightness (`brightnessctl`) and screen recording (`wf-recorder`).
- 🌙 **Eye Comfort & Night Light:** Integrated Gammastep warm color temperature with real-time toggle and status in Waybar.
- 🔒 **GNU Stow & Zero Bloat:** Layered architecture (`core`, `desktop`, `features`) with built-in dry-run safety and health checks (`doctor`).

---

## 🧱 Modular Architecture

This repository uses a **layered modular architecture** managed via [GNU Stow](https://www.gnu.org/software/stow/). Each component is isolated into packages, allowing tailored installations for desktops, laptops, or minimal systems with zero bloat.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     LAYER 3: FEATURES (On-Demand)                      │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐  │
│  │         mango-laptop         │    │       mango-recording        │  │
│  │  • Hardware backlight        │    │  • Lightweight screen        │  │
│  │    control (brightnessctl)   │    │    recording (wf-recorder)   │  │
│  │  • Fn brightness shortcuts   │    │  • Super+Ctrl+R keybinding   │  │
│  │  • Battery status hooks      │    │  • Recording status badge    │  │
│  └──────────────────────────────┘    └──────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────┤
│                  LAYER 2: DESKTOP PROFILE (UX & Shell)                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                          mango-desktop                           │  │
│  │  • Status bar (Waybar)             • Power menu (wlogout)        │  │
│  │  • Wallpaper engine (Swaybg)       • Night light (Gammastep)     │  │
│  │  • Screenshot editor (Satty)       • Multimedia audio control    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────┤
│                    LAYER 1: CORE (Minimal Foundation)                  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                              mango                               │  │
│  │  • MangoWM tiling compositor       • Terminal (Foot)             │  │
│  │  • App launcher (Fuzzel)           • Screen locker (Swaylock)    │  │
│  │  • Notifications (Mako)            • Catppuccin theme engine     │  │
│  │  • Wayland Desktop Portals         • Core window management      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Layer Breakdown

| Package | Purpose | When to Install |
| :--- | :--- | :--- |
| **`mango`** *(Core)* | Indispensable foundation: compositor configs, terminal, launcher, screen locker, notifications, and theme renderer. | **Always required.** |
| **`mango-desktop`** | Full desktop experience: status bar (`Waybar`), power menu (`wlogout`), wallpapers (`Swaybg`), night light, and screenshot editor (`Satty`). | **Standard Desktops & VMs.** |
| **`mango-laptop`** | Hardware backlight control (`brightnessctl`), Fn brightness bindings, and power hooks. | **Laptops only.** |
| **`mango-recording`** | Dedicated screen recording shortcut and script using `wf-recorder`. | **Content creators / On-demand.** |

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
| **Power Menu** | `wlogout` | Wayland-native logout, suspend, and reboot menu |
| **Wallpaper** | `swaybg` | Lightweight Wayland wallpaper engine |
| **Night Light** | `gammastep` | Smooth display color temperature adjustment for eye comfort |
| **Audio / Media** | PipeWire & Playerctl | Modern audio stack with MPRIS media integration |
| **Screenshots** | `satty` & `grim` | Fast region selection with interactive annotation editor |
| **Screen Recording** | `wf-recorder` | Hardware-accelerated Wayland screen recorder |

---

## 🚀 Installation & Profiles

The included `./bin/mango` CLI handles package installation and GNU Stow symlinking with built-in dry-run safety.

### 1. Standard Desktop / Virtual Machine (Recommended)

Installs `mango` core and `mango-desktop`:

```bash
./bin/mango bootstrap --profile desktop --apply
```

### 2. Laptop Setup

Installs `mango` + `mango-desktop` + `mango-laptop` (adds brightness keys and battery integrations):

```bash
./bin/mango bootstrap --profile desktop --feature laptop --apply
```

### 3. Full Workstation (with Screen Recording)

```bash
./bin/mango bootstrap --profile desktop --feature laptop --feature recording --apply
```

### 4. Minimal Core (Window Manager Only)

Installs only the compositor, terminal, and launcher without status bars or desktop daemons:

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

## 🎨 Theme & Palette

The desktop is styled with **Catppuccin Mocha** featuring **Pink (`#f5c2e7`)** as the primary semantic accent.

- **Palette Configuration:** `themes/catppuccin-mocha-pink/palette.conf`
- **Dynamic Atomic Rendering:** The `mango-theme` script parses palette tokens and generates runtime configuration files for MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, and Wlogout under `$XDG_STATE_HOME/mangowm/theme/current/`.

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
| `Super + L` | Lock screen immediately (Swaylock) |
| `Super + X` | Open session power menu (Wlogout) |
| `Super + Shift + P` | Open interactive Power Profiles selector (Fuzzel) |
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

## 📄 License

Original code and configurations are licensed under the [MIT License](LICENSE).
Catppuccin color palettes and third-party notices are attributed in `THIRD_PARTY_NOTICES.md`.

# MangoWM Dotfiles

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://wayland.freedesktop.org"><img src="https://img.shields.io/badge/Display-Wayland-00599C?style=flat-square&logo=wayland&logoColor=white" alt="Wayland"></a>
  <a href="https://github.com/mangowm/mango"><img src="https://img.shields.io/badge/WM-MangoWM-orange?style=flat-square" alt="MangoWM"></a>
  <a href="https://mangowm.github.io/showcase/"><img src="https://img.shields.io/badge/Showcase-MangoWM-orange?style=flat-square&logo=github" alt="MangoWM Showcase"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-cba6f7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="../../../LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Read this in other languages:* [Español](README.es.md)

Autonomous, modular, and minimal Wayland session optimized for **Arch Linux** using [MangoWM](https://github.com/mangowm/mango) as the primary dynamic tiling compositor, officially featured in the [MangoWM Showcase](https://mangowm.github.io/showcase/), and styled with the **Catppuccin Mocha** palette (supporting all 14 hot-swappable accents). It is a layer of the dotfiles monorepo.

> [!TIP]
> 🧩 **Dotfiles monorepo layer:**
> [Base & CLI](../../../README.md) • [BSPWM (X11)](../bspwm/README.md) • **MangoWM (Wayland) [Current]**
>
> This is a layer of the dotfiles monorepo. It is installed with the repository's `bin/dotfiles --wm mangowm`.

---

## ✨ Key Highlights

- 🚀 **Dynamic Wayland Tiling:** Next-generation dynamic tiling compositor with runtime layout switching (*Dwindle, Tile, Grid, Monocle, Scroller*).
- 🎨 **Atomic Dynamic Theming:** MangoWM ships templates for the shared `dotfiles-theme` engine (desktop layer), which renders MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, and Wlogout configs with 14 hot-swappable Mocha accents.
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
│  │  • Theme: templates for the shared dotfiles-theme engine         │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Profile Breakdown

| Profile | Stow Package | Contents | Intended Target |
| :--- | :--- | :--- | :--- |
| **`core`** | `mango` | Compositor, terminal, launcher, notifications, screen locker, idle daemon, portals, and `mango-theme` menu (theme templates for `dotfiles-theme`). | Minimal systems, servers with Wayland, headless setups. |
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

## 🚀 Installation

This window manager is a layer of the dotfiles monorepo (`layers/wm/mangowm`). It
has no CLI of its own: the repository's `bin/dotfiles` installs it with the
shared engine, together with the base it builds on.

```bash
./bin/dotfiles setup                                   # guided wizard
./bin/dotfiles bootstrap --wm mangowm --apply             # base + MangoWM
./bin/dotfiles bootstrap --wm mangowm --wm-profile core --apply
./bin/dotfiles doctor --wm mangowm
./bin/dotfiles unlink --wm mangowm --apply
```

`sync` and `update` re-apply the selection saved on each machine, so the layer
stays installed without passing `--wm` again.

### Layer contract

- `layer.conf`: profiles (`core desktop`), receipt name and the directories
  whose orphan links are pruned.
- `packages/`: `repo`, `aur`, `aur/*-fallback` and `cachyos` manifests per profile.
- `home/`: GNU Stow packages.
- `hooks/validate`: ownership, syntax and portability checks run before
  linking (unlink only checks ownership).
- `hooks/post-link`: renders the initial theme under the target's XDG state.

---

## 🎨 Theme & Appearance

The desktop is styled with **Catppuccin Mocha**, supporting all **14 official accent palettes** (*Rosewater, Flamingo, Pink, Mauve, Red, Maroon, Peach, Yellow, Green, Teal, Sky, Sapphire, Blue, Lavender*) with **Pink (`#f5c2e7`)** configured as the initial default.

- **Interactive Theme Selector:** Press `Super + Alt + T` to switch color palettes in real-time via Fuzzel.
- **Theming CLI (`mango-theme`, a front end for `dotfiles-theme`):**
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
- **Atomic Rendering:** The layer only contributes templates (`~/.local/share/dotfiles/theme/templates/mangowm/`) and a live reload hook (`reload.d/mangowm`). The shared `dotfiles-theme` engine renders them from `themes/palettes/` into `$XDG_STATE_HOME/dotfiles/theme/current/mangowm/` with atomic symlink promotion and zero background daemons; see `themes/README.md` at the repository root.

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

Run the repository suite from the monorepo root. It drives this layer through
`bin/dotfiles` and runs its session tests:

```bash
./tests/smoke.sh
```

---

## 👤 Author

Architected and maintained by [Anthony Portugal](https://anthonyportugal.github.io).

---

## 📄 License

Original code and configurations are licensed under the [MIT License](../../../LICENSE).
Catppuccin color palettes and third-party notices are attributed in the repository's [`THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md).

# BSPWM Dotfiles

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://www.x.org"><img src="https://img.shields.io/badge/Display-X11-red?style=flat-square&logo=xorg&logoColor=white" alt="X11"></a>
  <a href="https://github.com/baskerville/bspwm"><img src="https://img.shields.io/badge/WM-BSPWM-black?style=flat-square" alt="BSPWM"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-cba6f7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="../../../LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Read this in other languages:* [Español](README.es.md)

Autonomous, modular, and minimal X11 desktop session optimized for **Arch Linux** based on [BSPWM](https://github.com/baskerville/bspwm) and styled with the **Catppuccin Mocha** palette (supporting 14 hot-swappable accents). It is a layer of the dotfiles monorepo.

> [!TIP]
> 🧩 **Dotfiles monorepo layer:**
> [Base & CLI](../../../README.md) • [MangoWM (Wayland)](../mangowm/README.md) • **BSPWM (X11) [Current]**
>
> This is a layer of the dotfiles monorepo. It is installed with the repository's `bin/dotfiles --wm bspwm`.

---

## ✨ Key Highlights

- ⚡ **Lightweight & Blazing Fast:** Minimal memory footprint on X11 with instant binary-tree window partitioning.
- 🎨 **Catppuccin Mocha Aesthetics:** 14 hot-swappable Mocha accent palettes (Pink, Mauve, Blue, Lavender, etc.) via `bspwm-theme` and interactive Rofi menu (`Super + Shift + T`).
- 🖥️ **Multi-Monitor Aware:** Dynamic workspace balancing across outputs, focused-monitor screen recording, and ergonomic monitor navigation hotkeys.
- 📊 **Dynamic Polybar:** Real-time auto-detection of active network interfaces (Wi-Fi/Ethernet), battery status, and MPRIS playback.
- 🎛️ **Ergonomic Hotkeys:** Intuitive keybinding architecture driven by `sxhkd` with integrated interactive help menu (`Super + ?`).
- 🔋 **Power & Night Light:** Built-in Redshift warm display control and interactive power profile selector (`power-profiles-daemon`).
- 🔒 **GNU Stow & Zero Bloat:** Cumulative profiles (`core`, `desktop`) with built-in dry-run safety and health diagnostics (`doctor`).

---

## 🧱 Modular Architecture

The BSPWM configuration is organized into cumulative profiles managed with [GNU Stow](https://www.gnu.org/software/stow/):

```text
┌────────────────────────────────────────────────────────────────────────┐
│                       BSPWM DESKTOP ECOSYSTEM (X11)                    │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    DESKTOP PROFILE (UX & Tools)                  │  │
│  │  • Status Bar: Polybar (Catppuccin Mocha, 14 Accents)            │  │
│  │  • App Launcher & Power Menu: Rofi                               │  │
│  │  • Notifications: Dunst                                          │  │
│  │  • Compositor & Shadows: Picom (GLX / XRender)                   │  │
│  │  • Wallpaper & Media: Feh, Playerctl, MPV-MPRIS                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      CORE PROFILE (Minimal X11)                  │  │
│  │  • Window Manager: BSPWM (Binary Space Partitioning)             │  │
│  │  • Hotkey Daemon: SXHKD                                          │  │
│  │  • X11 Auth & Keyboard Layouts: Xauth, Setxkbmap (US / Latam)    │  │
│  │  • Terminal: Alacritty (Catppuccin Theme)                        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Profile Breakdown

| Profile | Stow Package | Contents | Intended Target |
| :--- | :--- | :--- | :--- |
| **`core`** | `bspwm` | BSPWM configuration, SXHKD key daemon, Xauth, Setxkbmap, and Alacritty styling. | Minimal systems, servers with X11, headless setups. |
| **`desktop`** | Reuses `bspwm` | Core + Polybar, Rofi app launcher, Dunst notifications, Picom compositor, Feh, Satty, FFmpeg recording, and brightness/audio hooks. | Full desktop workstations, laptops, and VMs. |

---

## 🛠️ Approved Tech Stack

| Capability | Component | Purpose |
| :--- | :--- | :--- |
| **Window Manager** | [`bspwm`](https://github.com/baskerville/bspwm) | Binary space partitioning tiling manager |
| **Hotkey Daemon** | `sxhkd` | Simple X hotkey daemon |
| **Status Bar** | `polybar` | Edge-to-edge status bar with dynamic battery and network detection |
| **App Launcher** | `rofi` | Application launcher and power menu |
| **Compositor** | `picom` | Smooth shadows, window transparency, and GLX rendering |
| **Terminal** | `alacritty` | GPU-accelerated terminal emulator themed with Catppuccin |
| **Notifications** | `dunst` | Customizable, lightweight notification daemon |
| **Wallpaper** | `feh` | Wallpaper setter with interactive selector |
| **Night Light** | `redshift` | Screen color temperature adjustment |
| **Audio / Media** | PipeWire & Playerctl | Modern audio stack with MPRIS media control |
| **Screenshots** | `satty` & `maim` | Fullscreen and region capture with interactive annotation editor |

---

## 🚀 Installation

This window manager is a layer of the dotfiles monorepo (`layers/wm/bspwm`). It
has no CLI of its own: the repository's `bin/dotfiles` installs it with the
shared engine, together with the base it builds on.

```bash
./bin/dotfiles setup                                   # guided wizard
./bin/dotfiles bootstrap --wm bspwm --apply             # base + BSPWM
./bin/dotfiles bootstrap --wm bspwm --wm-profile core --apply
./bin/dotfiles doctor --wm bspwm
./bin/dotfiles unlink --wm bspwm --apply
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

---

## 🎨 Theme & Appearance

The desktop is styled with **Catppuccin Mocha**, supporting all **14 official accent palettes** (*Rosewater, Flamingo, Pink, Mauve, Red, Maroon, Peach, Yellow, Green, Teal, Sky, Sapphire, Blue, Lavender*) with **Pink (`#f5c2e7`)** configured as the initial default.

- **Interactive Theme Selector:** Press `Super + Shift + T` to switch color palettes in real-time via Rofi.
- **Dynamic Theming CLI (`bspwm-theme`):**
  ```bash
  # Open interactive theme menu
  bspwm-theme menu

  # Set a specific accent directly (e.g., mauve, blue, teal, peach)
  bspwm-theme set catppuccin-mocha-mauve

  # List all available Catppuccin Mocha flavors
  bspwm-theme list

  # Display current active theme
  bspwm-theme current
  ```
- **Shared Engine:** `bspwm-theme` is a thin wrapper: `menu` opens the Rofi picker and every other command runs `dotfiles-theme`, the single engine stowed by the `desktop` layer (see [`themes/README.md`](../../../themes/README.md)). This layer only ships templates under `~/.local/share/dotfiles/theme/templates/bspwm/` for the BSPWM borders (`bspwm.env`), Polybar, Rofi and Dunst colors; they render to `$XDG_STATE_HOME/dotfiles/theme/current/bspwm/` with atomic symlink promotion. Picom and Alacritty are not themed by this engine. After `set`, the `reload.d/bspwm` hook recolors the borders and restarts Polybar and Dunst; linking the layer renders the current theme.

---

## ⌨️ Primary Keybindings

### Applications & Launchers

| Shortcut | Action |
| :--- | :--- |
| `Super + Return` | Open Alacritty terminal (Tiling) |
| `Super + Shift + Return` | Open floating Alacritty terminal |
| `Super + D` | Open Rofi application launcher |
| `Super + B` | Open default web browser (Brave) |
| `Super + E` | Open graphical file manager (Thunar) |
| `Super + ?` / `Super + Shift + ?` | Open interactive keybindings cheat sheet |

### Window Management

| Shortcut | Action |
| :--- | :--- |
| `Super + C` / `Super + Shift + C` | Close / Kill focused window |
| `Super + T` | Toggle layout (*Tiled / Monocle*) |
| `Super + {1-9}` | Focus workspace 1–9 |
| `Super + Shift + {1-9}` | Move focused window to workspace 1–9 |
| `Super + ,` / `Super + .` | Focus previous / next monitor |
| `Super + Shift + ,` / `Super + Shift + .` | Move focused window to previous / next monitor |
| `Super + Escape` | Restart BSPWM session and reload SXHKD |
| `Super + Shift + Escape` | Quit BSPWM session |

### System & Utilities

| Shortcut | Action |
| :--- | :--- |
| `Super + Shift + T` | Open Catppuccin Mocha accent theme switcher (Rofi) |
| `Super + L` | Lock screen immediately (slock / i3lock) |
| `Super + X` | Open session power menu (Rofi) |
| `Super + Shift + P` | Open interactive Power Profiles selector (Rofi) |
| `Super + N` | Toggle warm night light (Redshift) |
| `Super + W` | Select wallpaper from gallery via Rofi (Feh) |
| `Super + Shift + W` | Open interactive Wi-Fi network menu (Rofi) |
| `Alt + Space` | Toggle keyboard layout between US and Latin America |
| `Print` / `Super + S` | Fullscreen screenshot |
| `Super + Shift + S` | Interactive region screenshot with Satty annotation editor |
| `Super + R` / `Super + Shift + R` | Fullscreen / Interactive region screen recording (FFmpeg) |
| `Super + Alt + R` | Open screen recording audio options menu (Rofi) |

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

Original code and configuration are licensed under the [MIT License](../../../LICENSE).
Catppuccin color schemes and third-party notices are attributed in the repository's [`THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md).

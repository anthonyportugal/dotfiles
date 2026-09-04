# MangoWM Dotfiles

*Read this in other languages:* [Español](README.es.md)

Autonomous, modular, and minimal Wayland session configured for **CachyOS** and **Arch Linux** using [MangoWM](https://github.com/DreamMaoMao/mangowm) as the primary dynamic tiling compositor with the Catppuccin Mocha theme.

> [!NOTE]
> **Work in progress:** This repository is actively maintained. P11 standalone candidate completed and initial validation started in a VM where MangoWM boots, followed by physical hardware validation on HP ProBook 440 G10 (CachyOS + LUKS + Limine + Ly). It is designed to work standalone or integrated with the main modular dotfiles ecosystem at [anthonyportugal/dotfiles](https://github.com/anthonyportugal/dotfiles) (currently on branch `refactor/modular-dotfiles`).

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

- **Diagnostics:** Check health and link integrity:

  ```bash
  ./bin/mango doctor --profile desktop
  ```

- **Unlink / Clean:** Remove managed symlinks safely:

  ```bash
  ./bin/mango unlink --profile desktop --apply
  ```

- **Supported AUR/Package Helpers:** `auto` (detects `shelly`, `paru`, `yay`), or specify via `--backend <name>`.

---

## 🔗 Integration with Base Dotfiles

While this repository operates **100% standalone**, it seamlessly integrates with the primary modular dotfiles ecosystem:

- 🌐 **Primary Repository:** [anthonyportugal/dotfiles](https://github.com/anthonyportugal/dotfiles) *(Active branch: `refactor/modular-dotfiles`)*
- **Shared Ecosystem:** When installed alongside the base repository, MangoWM automatically syncs global dark-mode preferences, shared shell aliases, Neovim configs, and GTK theme tokens via `$HOME/.local/lib/dotfiles/session-preferences`.

---

## 🎨 Theme & Palette

The desktop is styled with **Catppuccin Mocha** featuring **Pink (`#f5c2e7`)** as the primary semantic accent.

- Palette configuration: `themes/catppuccin-mocha-pink/palette.conf`
- **Dynamic Atomic Rendering:** The `mango-theme` script parses palette tokens and generates runtime configuration files for MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, and Wlogout under `$XDG_STATE_HOME/mangowm/theme/current/`.

---

## ⌨️ Primary Keybindings

| Shortcut | Action |
| :--- | :--- |
| `Super + Return` | Open Foot terminal |
| `Super + Shift + Return` | Open floating Foot terminal |
| `Super + D` | Open Fuzzel application launcher |
| `Super + B` | Open default web browser (Brave) |
| `Super + Shift + E` | Open graphical file manager (Thunar) |
| `Super + L` | Lock screen immediately (Swaylock) |
| `Super + X` | Open session power menu (Wlogout) |
| `Super + Shift + P` | Open interactive Power Profiles selector (Fuzzel) |
| `Super + Shift + Q` | Quit MangoWM session |
| `Super + Shift + R` | Reload MangoWM configuration |
| `Super + T` | Cycle tiling layouts (*Dwindle, Tile, Grid, Monocle, Scroller*) |
| `Super + N` | Toggle warm night light (Gammastep with real-time Waybar status) |
| `Super + W` / `Super + Ctrl + W` | Select wallpaper from gallery via Fuzzel (Swaybg) |
| `Super + F1` / `Super + Shift + ?` | Open interactive keybindings cheat sheet |
| `Print` / `Super + Print` / `Super + Shift + S` | Interactive region screenshot with Satty annotation editor |
| `Shift + Print` | Fullscreen screenshot with Satty editor |
| `Ctrl + Print` | Copy region screenshot directly to clipboard |
| `Super + Ctrl + R` | Toggle screen recording *(requires recording feature)* |

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

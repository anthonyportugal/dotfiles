# Dotfiles (Base Repository)

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://www.gnu.org/software/stow/"><img src="https://img.shields.io/badge/Manager-GNU_Stow-informational?style=flat-square" alt="GNU Stow"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-f5c2e7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Read this in other languages:* [Español](README.es.md)

Public, modular, and portable base configuration optimized for **Arch Linux** environments. It establishes a consistent shell experience, essential CLI tools, common cross-session applications, and system preferences completely independent of the chosen Window Manager or compositor.

> [!TIP]
> 🧩 **Modular Dotfiles Ecosystem:**  
> **Base & CLI [Current]** • [MangoWM (Wayland)](https://github.com/anthonyportugal/dotfiles-mangowm) • [BSPWM (X11)](https://github.com/anthonyportugal/dotfiles-bspwm) • [Wallpapers](https://github.com/anthonyportugal/walls) • [System](https://github.com/anthonyportugal/dotfiles-system)
> 
> This repository provides the standalone foundation for user environments and seamlessly integrates with independent window managers, compositors, and an optional private configuration layer.

---

## ✨ Key Highlights

- ⚡ **Instant CLI & Shell:** High-performance Zsh environment with Starship prompt, syntax-highlighting, auto-suggestions, Fzf, and Zoxide.
- 🛡️ **Fail-Closed Privacy:** Strict 3-tier precedence (`base` ──► `private` ──► `local`) ensuring work identities, signing keys, and secrets never leak to public repositories.
- 🎛️ **Multi-WM Orchestration:** Seamlessly coordinates standalone window managers ([dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm) for Wayland and [dotfiles-bspwm](https://github.com/anthonyportugal/dotfiles-bspwm) for X11).
- 🔄 **Safe Lifecycle CLI:** Built-in `sync`, `update` (with working-tree protection against overwriting dirty state), and system `doctor` diagnostics.
- 🚀 **One-Command Bootstrap:** Interactive onboarding wizard deployable directly via `curl` on fresh machine installations.
- 🎨 **Unified Aesthetic:** Seamless Catppuccin Mocha theming across Starship, Bat, Micro, Yazi, Foot, and Alacritty.

---

## 🧱 Modular Architecture

This repository forms the **core foundation** of a multi-repository modular setup. Window Managers (like BSPWM) and Wayland Compositors (like MangoWM) live in their own standalone repositories and can be installed independently or composed with this base.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        MODULAR DOTFILES ECOSYSTEM                      │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                  BASE DOTFILES (This Repository)                 │  │
│  │  • Shell: Zsh (Autosuggestions, Syntax Highlighting, Starship)   │  │
│  │  • CLI Tools: Bat, Git, Micro, Yazi, Ripgrep, Fzf                │  │
│  │  • Common Apps: Alacritty, Brave, MPV, Zathura, Thunar           │  │
│  │  • Preferences: GTK Prefer-Dark, Fonts, Global Session Hooks     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                  │                                     │
│             ┌────────────────────┴────────────────────┐                │
│             ▼                                         ▼                │
│  ┌──────────────────────┐                  ┌──────────────────────┐    │
│  │    dotfiles-bspwm    │                  │   dotfiles-mangowm   │    │
│  │  • X11 Session       │                  │  • Wayland Session   │    │
│  │  • Polybar, Rofi,    │                  │  • Waybar, Fuzzel,   │    │
│  │    Picom, Dunst      │                  │    Swaylock, wlogout │    │
│  └──────────────────────┘                  └──────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Packages & Profiles

Configurations are structured into small packages managed with [GNU Stow](https://www.gnu.org/software/stow/):

| Package | Contents | Included In |
| :--- | :--- | :--- |
| **`git`** | Fail-closed Git configuration template (requires explicit identity setup) | `core`, `desktop` |
| **`zsh`** | Clean Zsh configuration with auto-suggestions, syntax-highlighting, and aliases | `core`, `desktop` |
| **`bat`** | Catppuccin themes for `bat` (syntax-highlighting `cat`) | `cli`, `desktop` |
| **`micro`** | Terminal text editor with Catppuccin Mocha theme | `cli`, `desktop` |
| **`starship`** | Cross-shell modern prompt theme | `cli`, `desktop` |
| **`yazi`** | Blazing fast terminal file manager with Catppuccin Mocha theme | `cli`, `desktop` |
| **`foot`** | Lightweight Wayland terminal emulator with Catppuccin Mocha theme | `desktop` |
| **`alacritty`** | Cross-platform terminal emulator with Catppuccin Mocha theme | `desktop` |
| **`xdg-defaults`** | GTK 3/4 `prefer-dark` settings, default mimeapps, and session hooks | `desktop` |

---

## 🔒 Integration with Optional Private Dotfiles

The base repository enforces a strict **3-tier configuration precedence**:

```text
Public Base Defaults  ──►  Optional Private Layer  ──►  Local Machine Overrides
   (~/.config/...)            (dotfiles-private)            (*.local.*)
```

1. **Git Multi-Identity:** `home/git/.config/git/config` loads `~/.config/git/private.gitconfig` (if present) for personal/work emails and signing keys, followed by machine-specific `~/.config/git/local.gitconfig`.
2. **Shell Environment:** `home/zsh/.zshrc` automatically sources `~/.config/zsh/private.zsh` (if present) for private aliases, environment variables, and work paths, followed by `~/.config/zsh/local.zsh`.
3. **Fail-Closed & Independent:** The absence of the private layer never breaks the public setup. No secrets, credentials, or private keys are ever tracked in public repositories.

---

## 🚀 Installation & Quickstart

### 1. One-Line Installation (Recommended for New Machines)

Deploy the entire ecosystem with a single command. It automatically clones the base repository into `~/.dotfiles/base` and launches the interactive setup wizard:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

The wizard detects existing components in `$HOME/.dotfiles/`, offers to clone missing ones, configures selected Window Managers (MangoWM, BSPWM, both, or none), the wallpapers layer, and the private layer (or local Git identity fallback).

### 2. If You Already Cloned the Repository

If you already have `~/.dotfiles/base` locally, run the interactive orchestrator launcher directly:

```bash
# Option A: Launch the interactive menu (defaults to English, or prompts for language)
./bin/dotfiles setup

# Option B: Launch in Spanish explicitly
./bin/dotfiles setup --lang es

# Option C: Via the bootstrap installer
./install.sh
```

The setup menu allows you to choose between:
- **Guided Full Setup:** Step-by-step onboarding for the base system and delegates automatically to sub-module wizards (`mango setup`, `bspwm setup`, `walls setup`, `install.sh`, `dotfiles-private setup`).
- **Individual Module Configuration:** Directly launch any component's standalone setup wizard or perform environment lifecycle maintenance (`sync`, `update`, `doctor`, `unlink`).

### 3. Manual Command-Line Orchestration

You can also orchestrate components directly using explicit flags:

- **Full Desktop Profile:**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop --apply
  ```
- **Minimal Core Profile (Shell + Git only):**
  ```bash
  ./bin/dotfiles bootstrap --profile core --apply
  ```
- **Compose with WMs, Wallpapers, and Private Layer:**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
    --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" \
    --wallpapers --wallpapers-path "$HOME/.dotfiles/walls" \
    --private --private-path "$HOME/.dotfiles/private" \
    --apply
  ```

### 4. Lifecycle Management: Local Sync & Remote Updates

- **Local Synchronization (`sync`):** Re-applies GNU Stow symlinks, validates packages, and renders local session configurations without touching Git or altering commit history:
  ```bash
  ./bin/dotfiles sync
  ```
- **Remote Update (`update`):** Safely checks Git status in all managed repositories under `$HOME/.dotfiles/` (`base`, `wm/*`, `walls`, `private`). Repositories with uncommitted working tree changes are safely skipped to protect local work, clean repositories perform `git pull --ff-only`, followed by an automatic local `sync`:
  ```bash
  ./bin/dotfiles update
  ```
- **System Diagnostics (`doctor`):** Inspects link integrity, shells, and system dependencies:
  ```bash
  ./bin/dotfiles doctor --profile desktop
  ```
- **Unlink / Clean (`unlink`):** Safely removes managed symlinks:
  ```bash
  ./bin/dotfiles unlink --profile desktop --apply
  ```

---

## 🌐 Connected Repositories

| Repository | Capability | Display Protocol |
| :--- | :--- | :--- |
| **[dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm)** | Modern Wayland dynamic tiling session (Waybar + Fuzzel + Swaylock + Satty) | Wayland |
| **[dotfiles-bspwm](https://github.com/anthonyportugal/dotfiles-bspwm)** | Standalone classic tiling session (Polybar + Rofi + Picom + Dunst) | X11 |
| **[walls](https://github.com/anthonyportugal/walls)** | Curated WebP wallpaper collection and management CLI | Multi-display |
| **[dotfiles-system](https://github.com/anthonyportugal/dotfiles-system)** | System-level configurations (Ly display manager, Limine bootloader, DNS-over-TLS) | Linux System |
| **`dotfiles-private`** | Private layer for identities, signing keys, and work profiles | Local / Secure |

---

## 🧪 Testing

Run the automated smoke test suite locally:

```bash
./tests/bootstrap-smoke.sh
```

---

## 📄 License

Distributed under the [MIT License](LICENSE).
Catppuccin color schemes and third-party notices are documented in `THIRD_PARTY_NOTICES.md`.

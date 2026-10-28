# Dotfiles (Base Repository)

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://www.gnu.org/software/stow/"><img src="https://img.shields.io/badge/Manager-GNU_Stow-informational?style=flat-square" alt="GNU Stow"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-cba6f7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Read this in other languages:* [Español](README.es.md)

Public, modular, and portable base configuration optimized for **Arch Linux** environments. It establishes a consistent shell experience, essential CLI tools, common cross-session applications, and system preferences completely independent of the chosen Window Manager or compositor.

> [!TIP]
> 🧩 **Modular Dotfiles Ecosystem:**  
> **Base & CLI [Current]** • [MangoWM (Wayland)](https://github.com/anthonyportugal/dotfiles-mangowm) • [BSPWM (X11)](https://github.com/anthonyportugal/dotfiles-bspwm) • [Wallpapers](https://github.com/anthonyportugal/walls) • [System](https://github.com/anthonyportugal/dotfiles-system) • [Agent Harness](https://github.com/anthonyportugal/agent-harness)
> 
> This repository provides the standalone foundation for user environments and seamlessly integrates with independent window managers, compositors, AI agent toolchains, and an optional private configuration layer.

---

## ✨ Key Highlights

- ⚡ **Instant CLI & Shell:** High-performance Zsh environment with Starship prompt, syntax-highlighting, auto-suggestions, and Fzf.
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
| **`xdg-defaults`** | GTK 3/4 `prefer-dark` settings and session hooks | `desktop` |
| **`theme`** | `dotfiles-theme`, the single theme engine shared by every window manager (see [`themes/README.md`](themes/README.md)) | `desktop` |

### Opt-in layers

Some layers are never part of a profile and apply only when asked for with `--layer` (they pull in the layers they require). Their features add heavier stacks on top, and choosing a feature also applies its layer:

| Layer / feature | Contents |
| :--- | :--- |
| **`dev`** | Development tools: `actionlint`, `github-cli`, `jq`, `shellcheck`, `shfmt`; Docker doctor checks. Requires `cli`. |
| **`dev-containers`** | Feature of `dev`: `docker`, `docker-compose`, `lazydocker` |
| **`dev-js`** | Feature of `dev`: `pnpm`, with its global binaries on `PATH` |

`~/.config/mimeapps.list` is generated, not linked: applications write to it, so a link would let them edit the checkout. The `desktop` layer merges
[`layers/desktop/mimeapps/defaults.list`](layers/desktop/mimeapps/defaults.list) into it on every apply. The repo's keys always win, and every other entry an application registered is kept. `doctor` warns when a repo key drifted.

---

## 🔒 Integration with Optional Private Dotfiles

The base repository enforces a strict **3-tier configuration precedence**:

```text
Public Base Defaults  ──►  Optional Private Layer  ──►  Local Machine Overrides
   (~/.config/...)            (dotfiles-private)            (*.local.*)
```

1. **Git Multi-Identity:** `layers/core/home/git/.config/git/config` loads `~/.config/git/private.gitconfig` (if present) for personal/work emails and signing keys, followed by machine-specific `~/.config/git/local.gitconfig`.
2. **Shell Environment:** `layers/core/home/zsh/.zshrc` automatically sources `~/.config/zsh/private.zsh` (if present) for private aliases, environment variables, and work paths, followed by `~/.config/zsh/local.zsh`.
3. **Fail-Closed & Independent:** The absence of the private layer never breaks the public setup. No secrets, credentials, or private keys are ever tracked in public repositories.
4. **Overlay:** the private repository uses the same layer format (`layers/<name>/layer.conf`, `packages/`, `home/`) and is applied with `--overlay ~/.dotfiles-private`. Each of its layers applies on its own once every layer it `requires` is selected (for example `requires=core`, or `requires=dev` to apply only with the opt-in `dev` layer); its features work like public ones. The overlay path is saved in the selection receipt, so `sync` and `update` re-apply and pull it; `--no-overlay` stops applying it. Overlay layer names cannot reuse a public layer name.

---

## 🚀 Installation & Quickstart

### 1. One-Line Installation (Recommended for New Machines)

Deploy the entire ecosystem with a single command. It automatically clones the base repository into `~/.dotfiles/base` and launches the interactive setup wizard:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

The wizard detects existing components in `$HOME/.dotfiles/`, offers to clone missing ones, configures selected Window Managers (MangoWM, BSPWM, both, or none), the wallpapers component (`dotfiles add walls`), and the private layer (or local Git identity fallback).

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
- **Guided Full Setup:** Step-by-step onboarding for the base system and offers the optional components (wallpapers through `dotfiles add walls`, the system layer through `dotfiles system`).
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
- **Opt-in Development Layer (with Docker):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop --layer dev --feature dev-containers --apply
  ```
- **Compose with WMs and the Private Overlay:**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm mangowm --wm bspwm \
    --overlay "$HOME/.dotfiles-private" \
    --apply
  ```
- **External Components (`add`):** Repositories that are not layers, such as the [walls](https://github.com/anthonyportugal/walls) wallpaper collection, are declared in [`components.conf`](components.conf), one per line: `name url ref [src=dst ...]`, where `ref` is the full commit SHA the component is pinned to, `src` a path inside the component and `dst` a path inside your home. `add` clones the component into `~/.local/share/dotfiles/<name>`, checks out the pinned commit and links every `dst` to its `src`. An existing symlink at `dst` (such as the old `~/.local/share/wallpapers` link) is replaced; a real file or directory is refused before anything changes. The component is recorded in `~/.local/state/dotfiles/components.receipt`, so `sync` re-applies it and `update` moves it to the commit a pulled `components.conf` pins. `--wallpapers` and `--wallpapers-path` were removed in favour of this command:
  ```bash
  ./bin/dotfiles add walls --dry-run  # print the plan only
  ./bin/dotfiles add walls
  ```

### 4. Lifecycle Management: The 5 Canonical Commands

- **Interactive Guided Setup (`setup`):** Launches the interactive wizard with bilingual support:
  ```bash
  ./bin/dotfiles setup            # English by default
  ./bin/dotfiles setup --lang es  # Spanish interface
  ```
- **Local Synchronization (`sync`):** Re-applies the selection saved on this machine (profile, features, opt-in layers and WM layers, recorded in `~/.local/state/dotfiles/dotfiles.receipt` by every applied bootstrap, plus the components added with `add`), and validates packages without touching Git. The one exception is a component: sync fetches it when the commit pinned in `components.conf` is not in its local checkout yet (for example after a pull changed `components.conf`). Explicit flags such as `--profile` override the saved values:
  ```bash
  ./bin/dotfiles sync
  ```
- **Remote Update (`update`):** Safely checks Git status of the public repository and of the overlay of the saved selection (the WM and system layers live inside it under `layers/`; components are never pulled, they follow the commit pinned in `components.conf`). Repositories with uncommitted working tree changes are safely skipped to protect your work; clean repositories perform `git pull --ff-only`. If updates are found, it prompts interactively before synchronizing (or pass `-y` / `--yes` for unattended updates):
  ```bash
  ./bin/dotfiles update
  ./bin/dotfiles update -y
  ```
- **System Diagnostics (`doctor`):** Inspects link integrity, shells, and dependencies for base, auto-detects active WM layers and checks every added component (checkout present, at its pinned commit, links in place; a failure suggests `dotfiles add <name>`) to produce a composite diagnostics report:
  ```bash
  ./bin/dotfiles doctor             # Composite diagnostics across active layers
  ./bin/dotfiles doctor --base-only # Isolated diagnostics for base repository only
  ./bin/dotfiles doctor --all       # Audit all repositories available on disk
  ```
- **Unlink / Clean (`unlink`):** Safely removes managed GNU Stow symlinks and the links of added components that point into their checkout; component checkouts stay in `~/.local/share/dotfiles/`:
  ```bash
  ./bin/dotfiles unlink --apply
  ```
- **Optional System Layer (`system`):** Applies [`layers/system`](layers/system/README.md) (Ly display manager, Limine theme, DNS-over-TLS) to `/etc` and `/boot` under an explicit `sudo`. It is opt-in: `bootstrap`, `sync` and `update` never run it, and `update` only warns when a pulled change touched it. The applied selection is saved in `~/.local/state/dotfiles/system.receipt`:
  ```bash
  ./bin/dotfiles system setup --ly --dns --provider quad9 --install
  ./bin/dotfiles system doctor
  ```

---

## 🌐 Connected Repositories

| Repository | Capability | Display Protocol / Domain |
| :--- | :--- | :--- |
| **[dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm)** | Modern Wayland dynamic tiling session (featured in official MangoWM showcase) | Wayland |
| **[dotfiles-bspwm](https://github.com/anthonyportugal/dotfiles-bspwm)** | Standalone classic tiling session (Polybar + Rofi + Picom + Dunst) | X11 |
| **[walls](https://github.com/anthonyportugal/walls)** | Curated WebP wallpaper collection, added with `dotfiles add walls` (see `components.conf`) | Multi-display |
| **[dotfiles-system](https://github.com/anthonyportugal/dotfiles-system)** | System-level configurations (Ly display manager, Limine bootloader, DNS-over-TLS) | Linux System |
| **`dotfiles-private`** | Private layer for identities, signing keys, and work profiles | Local / Secure |
| **[agent-harness](https://github.com/anthonyportugal/agent-harness)** | Independent project (AI coding agent harness); installed with its own installer, not by these dotfiles | AI Engineering |

---

## 🧪 Testing

Run the automated smoke test suite locally:

```bash
./tests/smoke.sh
```

---

## 👤 Author

Architected and maintained by [Anthony Portugal](https://anthonyportugal.github.io).

---

## 📄 License

Distributed under the [MIT License](LICENSE).
Catppuccin color schemes and third-party notices are documented in `THIRD_PARTY_NOTICES.md`.

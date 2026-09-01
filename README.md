# Dotfiles (Base Repository)

*Read this in other languages:* [Español](README.es.md)

Public, modular, and portable base configuration for **CachyOS** and **Arch Linux** environments. It establishes a consistent shell experience, essential CLI tools, common cross-session applications, and system preferences completely independent of the chosen Window Manager or compositor.

> [!NOTE]
> **Work in progress:** This repository is undergoing active refactoring on branch `refactor/modular-dotfiles` ([github.com/anthonyportugal/dotfiles](https://github.com/anthonyportugal/dotfiles)).
> It provides the standalone foundation for user environments and seamlessly integrates with independent window managers, compositors, and an optional private configuration layer.

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
| **`starship`** | Cross-shell modern prompt theme | `desktop` |
| **`alacritty`** | Alacritty terminal emulator with Catppuccin Mocha theme | `desktop` |
| **`bat`** | Catppuccin themes for `bat` (syntax-highlighting `cat`) | `desktop` |
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

### 1. Clone the Base Repository

```bash
mkdir -p "$HOME/.dotfiles"
git clone --branch refactor/modular-dotfiles \
  https://github.com/anthonyportugal/dotfiles.git "$HOME/.dotfiles/base"
cd "$HOME/.dotfiles/base"
```

### 2. Bootstrap the Base System

- **Desktop Profile (Recommended):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop --apply
  ```
- **Minimal Core Profile (Shell + Git only):**
  ```bash
  ./bin/dotfiles bootstrap --profile core --apply
  ```

### 3. Optional: Compose with a Window Manager
The base CLI can orchestrate the installation of standalone WM repositories via `--wm-path`:

- **Compose with MangoWM (Wayland):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm-path "$HOME/.dotfiles/wm/mangowm" \
    --wm-profile desktop --apply
  ```
- **Compose with BSPWM (X11):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm-path "$HOME/.dotfiles/wm/bspwm" \
    --wm-profile desktop --apply
  ```

### Helpful Bootstrap Flags
- **Dry-run simulation (Safe check):** Omit `--apply` to inspect planned operations without modifying files:
  ```bash
  ./bin/dotfiles bootstrap --profile desktop
  ```
- **Diagnostics:** Verify links and configuration health:
  ```bash
  ./bin/dotfiles doctor --profile desktop
  ```
- **Unlink:** Safely remove managed symlinks:
  ```bash
  ./bin/dotfiles unlink --profile desktop --apply
  ```

---

## 🌐 Connected Repositories

- 🪟 **[dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm):** Dynamic tiling Wayland session (MangoWM + Waybar + Swaylock + Catppuccin Mocha).
- 🪟 **[bspwm](https://github.com/anthonyportugal/bspwm):** Standalone X11 tiling session (BSPWM + Polybar + Rofi + Picom + Dunst).
- 🔒 **Private Dotfiles (`dotfiles-private`):** Optional layer for non-secret personal and work configurations.

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

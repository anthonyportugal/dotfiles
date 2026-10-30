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

Deploy the entire ecosystem with a single command. It clones the repository into `~/.dotfiles` and launches the interactive setup wizard; no SSH key is needed, it clones over HTTPS:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"

# Somewhere else, e.g. next to your other repositories:
DOTFILES_BASE_DIR=~/dev/personal/dotfiles bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

| Variable | Default | Effect |
| :--- | :--- | :--- |
| `DOTFILES_BASE_DIR` | `~/.dotfiles` | Where the repository is cloned. Links point into this checkout, so keep it there. |
| `DOTFILES_REPO` / `DOTFILES_BRANCH` | this repository / `main` | Clone another remote or branch. |
| `DOTFILES_OVERLAY_DIR` | the checkout path plus `-private` | Where `setup` looks for the overlay and clones it (`~/.dotfiles-private`, or `~/dev/personal/dotfiles-private` for the example above). |

The wizard is one short guided flow (see below): profile, window managers, overlay and extras, then the plan.

### 2. If You Already Cloned the Repository

If you already cloned the repository (anywhere), run the guided setup from it:

```bash
# Option A: Launch the guided setup (language follows $LANG: es_* is Spanish, anything else English)
./bin/dotfiles setup

# Option B: Launch in Spanish explicitly
./bin/dotfiles setup --lang es

# Option C: Via the bootstrap installer
./install.sh
```

When the target still has links of another install (the previous `~/.dotfiles` ecosystem or another monorepo checkout, detected like `switch` does), `setup` first shows what it found (the install, its profile, WMs, extras, overlay, the links to replace and anything `Not migrated:`) and asks `migrate`, `continue` or `cancel` (the default, also at the end of input). `migrate` runs the `switch` logic for this checkout: it shows the switch plan and asks `apply`, `dry-run` or `cancel`; apply checks collisions, keeps the manifest and rolls back on failure (setup then exits non-zero), and on success setup ends with the selection applied and tells you that `dotfiles switch --rollback --apply` undoes it; the next `setup` starts from that receipt. `continue` goes on to the questions and leaves the old links alone. When an install is there but the switch cannot be prepared (for example no selection receipt, or an `--overlay` without `layers/`), setup shows the switch's error and what to do, and asks `continue` or `cancel` (the default); when a change was left unfinished it also offers `rollback`, which shows the rollback plan and asks `apply` or `cancel`, so `dotfiles switch --rollback --apply` is never needed. On a fresh home or one already on this checkout nothing is shown.

`setup` asks four questions, then shows the plan:

1. **Profile:** `server` (shell, Git and CLI tools, the `cli` layer) or `desktop` (adds the graphical session).
2. **Window managers** (desktop only): none, one or several of the layers under `layers/wm/`.
3. **Overlay:** an overlay with `layers/` found next to the checkout (`<checkout>-private`, e.g. `~/.dotfiles-private`; `DOTFILES_OVERLAY_DIR` overrides it) or recorded in the receipt is offered with Yes by default; otherwise paste a Git URL, cloned there only when you apply, or press Enter to skip. Without an overlay the public Git config stays fail-closed until you configure an identity.
4. **Extras:** nothing is checked by default. The list is built at run time from the opt-in layers, the features declared in `layer.conf` and the components in `components.conf`, each with its `description`, plus the features of the overlay chosen in the previous question (an overlay given by URL is cloned on apply, so its features are offered on the next run), and only shows what fits the chosen profile and window managers. A new layer, feature or component appears without changing the wizard.

On a machine set up before, every question starts from the selection saved in the receipt: the saved profile is the default, saved WMs and extras are marked `[x]`, and the saved overlay is offered with Yes. Enter keeps the marked entries, `-` clears them and any other answer replaces them, so pressing Enter on every question changes nothing. Whatever you uncheck (an extra, a WM, the overlay, or `server` instead of `desktop`) is retired: the plan lists it in a `Retiring:` line (`Se retiran:` in Spanish) and apply removes its links.

Then choose `apply`, `dry-run` or `cancel` (the default). Apply runs the same path as `bootstrap --apply` and then adds the selected components. Answer with numbers or names; an empty answer or the end of input takes the default, so the wizard can also be driven by piped input. Flags such as `--stow-only`, `--target` and `--lang` still apply. Maintenance stays in its own commands (`sync`, `update`, `doctor`, `unlink`), and the system layer is applied separately with `dotfiles system`.

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
- **External Components (`add`):** Repositories that are not layers, such as the [walls](https://github.com/anthonyportugal/walls) wallpaper collection, are declared in [`components.conf`](components.conf), one per line: `name url ref [src=dst ...] [-- description]`, where `ref` is the full commit SHA the component is pinned to, `src` a path inside the component and `dst` a path inside your home. `add` clones the component into `~/.local/share/dotfiles/<name>`, checks out the pinned commit and links every `dst` to its `src`. An existing symlink at `dst` (such as the old `~/.local/share/wallpapers` link) is replaced; a real file or directory is refused before anything changes. The component is recorded in `~/.local/state/dotfiles/components.receipt`, so `sync` re-applies it and `update` moves it to the commit a pulled `components.conf` pins. `--wallpapers` and `--wallpapers-path` were removed in favour of this command:
  ```bash
  ./bin/dotfiles add walls --dry-run  # print the plan only
  ./bin/dotfiles add walls
  ```

### 4. Lifecycle Management: Commands

- **Guided Setup (`setup`):** The short guided flow described above, in English or Spanish:
  ```bash
  ./bin/dotfiles setup            # language from $LANG
  ./bin/dotfiles setup --lang es  # Spanish interface
  ```
- **Flag-driven install (`bootstrap`):** The same install without questions; without `--apply` it only prints the plan. See the examples in section 3.
- **Retiring a dropped selection:** when an applied `bootstrap`, `sync` or `setup` selects less than the receipt recorded (an opt-in layer, a feature, a WM layer, a lower profile such as `desktop` to `cli`, or the overlay changed or cleared with `--no-overlay`), the links of what was dropped are removed before the new selection is linked. The plan names it first in one `Retiring:` line; a dry-run prints the line and changes nothing. Only links into this checkout or the recorded overlay are removed (`stow --delete`), foreign files and links are left alone, and installed packages stay installed. `--packages-only` never retires links. Retiring and linking are one transaction: when any step after the retire fails, the retired links come back and whatever the run linked goes, so the home is left as it was. The preflight already counts the links being retired as replaceable, so a new layer may take over a path a retired one linked.
- **Shell completion (`completion`):** `./bin/dotfiles completion zsh` (or `bash`) prints the completion script.
- **Local Synchronization (`sync`):** Re-applies the selection saved on this machine (profile, features, opt-in layers and WM layers, recorded in `~/.local/state/dotfiles/dotfiles.receipt` by every applied bootstrap, plus the components added with `add`), and validates packages without touching Git. The one exception is a component: sync fetches it when the commit pinned in `components.conf` is not in its local checkout yet (for example after a pull changed `components.conf`). Explicit flags such as `--profile` override the saved values, and what that drops is retired as described above (an opt-in layer that requires `cli` keeps `cli` selected):
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
- **Switching the active checkout (`switch`):** Moves a home to another checkout, for example from the previous multi-repository install under `~/.dotfiles` (base, `wm/<x>`, private, walls) to this monorepo, or between two monorepo checkouts such as `~/dev/personal/dotfiles` and `~/.dotfiles`. `setup` offers this same migration when it finds an old install, so you only need the command in scripts. Without `--apply` it only prints the plan:
  ```bash
  ./bin/dotfiles switch ~/dev/personal/dotfiles            # plan: what migrates and what does not
  ./bin/dotfiles switch ~/dev/personal/dotfiles --apply    # switch (links only)
  ./bin/dotfiles switch --rollback --apply                 # undo the last switch
  ```
  The current install is detected from `~/.local/bin/dotfiles` (or `~/.dotfiles/base`; `--from DIR` overrides it). Its selection is translated: the base packages that are linked set the profile, `wm/<x>` becomes the WM layer `<x>` (its receipt keeps its profile), the old private install becomes the overlay (`--overlay DIR`, else the recorded overlay, else a sibling `DIR-private` or `dotfiles-private` next to the new checkout; the plan says which) with `development` mapped to the `dev` layer and each work component `<w>` to the overlay feature `work-<w>`, the old walls links become the `walls` component, the theme selected for the WM the shared theme points to becomes `~/.local/state/dotfiles/theme/selected`, and a `mimeapps.list` linked into the old checkout is kept as a real file with every association apps wrote through it. A monorepo checkout keeps its recorded selection. Whatever has no equivalent is listed as `No migrado:` (agent-harness and system keep their own installers) and its links stay.

  Before anything changes, the new checkout's own dry-run checks collisions: a real file or a link that points anywhere but the replaced checkouts aborts the switch with nothing changed and every path listed. Then a manifest of every link being replaced (path and old destination) and a snapshot of the state directory are saved under `~/.local/state/dotfiles/transactions/`; only links into the replaced checkouts are removed and the selection is applied through the new checkout's `bootstrap` (`--stow-only` unless `--with-packages`). If any step fails, the target is restored as it was. `switch --rollback --apply` restores the last switch later: old links, files and receipts come back, and files that appeared since are moved aside to `transactions/displaced-*`, never deleted, including inside directories the switch created. A change interrupted before its manifest was written changed nothing and is discarded with a warning. Neither checkout is ever modified.
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

# Dotfiles

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

Public, modular, and portable configuration for **Arch Linux**, in one repository. The shell, CLI tools, desktop, window managers and system settings are layers you choose, all driven by a single `dotfiles` command.

> [!TIP]
> 🧩 **Inside this repository:**  
> [MangoWM (Wayland)](layers/wm/mangowm/README.md) • [BSPWM (X11)](layers/wm/bspwm/README.md) • [System](layers/system/README.md) • [Themes](themes/README.md) • external: [Wallpapers](https://github.com/anthonyportugal/walls)
>
> The previous multi-repository install lives on the [`legacy`](https://github.com/anthonyportugal/dotfiles/tree/legacy) branch; `dotfiles setup` offers to migrate it.

---

## ✨ Key Highlights

- ⚡ **Instant CLI & Shell:** High-performance Zsh environment with Starship prompt, syntax-highlighting, auto-suggestions, and Fzf.
- 🛡️ **Fail-Closed Privacy:** Strict 3-tier precedence (`base` ──► `private` ──► `local`) ensuring work identities, signing keys, and secrets never leak to public repositories.
- 🎛️ **Multi-WM Orchestration:** MangoWM (Wayland) and BSPWM (X11) are layers that share one theme engine; install one or both.
- 🔄 **Safe Lifecycle CLI:** Built-in `sync`, `update` (with working-tree protection against overwriting dirty state), and system `doctor` diagnostics.
- 🚀 **One-Command Bootstrap:** Interactive onboarding wizard deployable directly via `curl` on fresh machine installations.
- 🎨 **Unified Aesthetic:** One theme engine (`dotfiles-theme`, see `themes/README.md`) renders the active palette (Catppuccin Mocha by default, plus the Sanctuary compline, vespers and matins themes) for GTK, the terminals, Yazi and the CLI tools.

---

## 🧱 Modular Architecture

Everything lives in this repository except what is private or heavy. A layer applies with the layers it requires, so choosing a window manager brings the desktop, the CLI tools and the core with it.

```text
dotfiles (this repository)
├── bin/dotfiles, lib/    one CLI and its engine
├── layers/
│   ├── core              Zsh and fail-closed Git
│   ├── cli               requires core: Bat, Micro, Starship, Yazi, Lazygit, Btop, Fastfetch, Eza, Zoxide
│   ├── desktop           requires cli: Alacritty, Foot, theme engine, GTK preferences
│   ├── wm/mangowm        requires desktop: Wayland session (Waybar, Fuzzel, Swaylock, wlogout)
│   ├── wm/bspwm          requires desktop: X11 session (Polybar, Rofi, Picom, Dunst)
│   ├── dev               opt-in: development tools, with Docker and pnpm features
│   └── system            opt-in, needs sudo: Ly, Limine, DNS-over-TLS
├── themes/               palettes shared by every window manager
└── components.conf       external repositories pinned to a commit (walls)

private overlay           optional repository of your own, in the same layer format
```

---

## 📦 Packages & Profiles

Configurations are structured into small packages managed with [GNU Stow](https://www.gnu.org/software/stow/):

| Package | Contents | Included In |
| :--- | :--- | :--- |
| **`git`** | Fail-closed Git configuration template (requires explicit identity setup) | `core`, `desktop` |
| **`zsh`** | Clean Zsh configuration with auto-suggestions, syntax-highlighting, and aliases | `core`, `desktop` |
| **`bat`** | `bat` (syntax-highlighting `cat`) with the theme engine's colors | `cli`, `desktop` |
| **`micro`** | Terminal text editor with the theme engine's colors | `cli`, `desktop` |
| **`starship`** | Cross-shell modern prompt theme | `cli`, `desktop` |
| **`yazi`** | Blazing fast terminal file manager with the theme engine's colors | `cli`, `desktop` |
| **`foot`** | Lightweight Wayland terminal emulator with the theme engine's colors | `desktop` |
| **`alacritty`** | Cross-platform terminal emulator with the theme engine's colors | `desktop` |
| **`xdg-defaults`** | GTK 3/4 `prefer-dark` settings and session hooks | `desktop` |
| **`theme`** | `dotfiles-theme`, the single theme engine shared by every window manager (see [`themes/README.md`](themes/README.md)) | `desktop` |

### Opt-in layers

Some layers are never part of a profile and apply only when asked for with `--layer` (they pull in the layers they require). Their features add heavier stacks on top, and choosing a feature also applies its layer:

| Layer / feature | Contents |
| :--- | :--- |
| **`dev`** | Development tools: Neovim with LazyVim (`nvim`, see below), `actionlint`, `direnv` (hooked into zsh), `github-cli`, `hyperfine`, `jq`, `oha`, `shellcheck`, `shfmt`, `xh`; Docker doctor checks. Requires `cli`. |
| **`dev-containers`** | Feature of `dev`: `docker`, `docker-compose`, `lazydocker` |
| **`dev-js`** | Feature of `dev`: `pnpm`, with its global binaries on `PATH` |
| **`dev-go`** | Feature of `dev`: `go`, `golangci-lint`, `delve` |
| **`dev-tauri`** | Feature of `dev`: `rustup` and the Tauri v2 system libraries (`webkit2gtk-4.1`, `libayatana-appindicator`, ...). `rustup` conflicts with the `rust` package: remove `rust` first (`sudo pacman -Rns rust`). After installing, run `rustup default stable` once. |
| **`dev-herdr`** | Feature of `dev`: `herdr-bin` from AUR (needs an AUR helper such as Shelly, paru or yay), the herdr TUI to supervise several coding agents in one terminal. |

#### Neovim (LazyVim)

The `dev` layer links `~/.config/nvim` from [`layers/dev/home/nvim`](layers/dev/home/nvim/.config/nvim). It is built in three levels:

- **[lazy.nvim](https://github.com/folke/lazy.nvim)** is the plugin manager. On the first `nvim` it clones itself and installs every plugin, recording the exact commits in `~/.config/nvim/lazy-lock.json` (a local file, not part of this repo). `:Lazy` shows and updates them.
- **[LazyVim](https://www.lazyvim.org)** is a plugin set on top of it: editor defaults, LSP, completion, treesitter, a picker and git integration.
- **Extras** add one language or tool each: its language server, treesitter parsers and formatter/linter. [`lua/config/lazy.lua`](layers/dev/home/nvim/.config/nvim/lua/config/lazy.lua) imports TypeScript/React, Vue, Angular, Astro, Tailwind, Go, Rust, JSON, YAML, TOML, Docker, Markdown, Prettier, ESLint, the debugger and the test runner. A new stack is one more import (for example `lang.dart` for Flutter); `:LazyExtras` lists them all. New to Vim? `:Tutor` is Neovim's interactive 30-minute tutorial.

Colors follow the active palette: the `dotfiles` colorscheme reads the palette that `dotfiles-theme` renders (desktop layer), and `dotfiles-theme set` re-applies it in running Neovim instances. Without a rendered palette Neovim uses tokyonight.

With `nvim` installed, the layer's zsh file makes it the editor: `EDITOR`, `VISUAL` and `GIT_EDITOR` (replacing only the `micro` defaults of `core`: an editor you exported yourself is kept, and git follows it too). Micro stays installed by `cli` and remains the editor without the `dev` layer.

Mason (`:Mason`) installs the language servers under `~/.local/share/nvim`. The TypeScript-family servers need Node.js with `npm` (feature `dev-js`), and the Go tools need `go` (feature `dev-go`).

`~/.config/mimeapps.list` is generated, not linked: applications write to it, so a link would let them edit the checkout. The `desktop` layer merges
[`layers/desktop/mimeapps/defaults.list`](layers/desktop/mimeapps/defaults.list) into it on every apply. The repo's keys always win, and every other entry an application registered is kept. `doctor` warns when a repo key drifted.

---

## 🔒 Integration with Optional Private Dotfiles

The base repository enforces a strict **3-tier configuration precedence**:

```text
Public Base Defaults  ──►  Optional Private Layer  ──►  Local Machine Overrides
   (~/.config/...)            (private overlay)             (*.local.*)
```

1. **Git Multi-Identity:** `layers/core/home/git/.config/git/config` loads `~/.config/git/private.gitconfig` (if present) for personal/work emails and signing keys, followed by machine-specific `~/.config/git/local.gitconfig`.
2. **Shell Environment:** `layers/core/home/zsh/.zshrc` automatically sources `~/.config/zsh/private.zsh` (if present) for private aliases, environment variables, and work paths, followed by `~/.config/zsh/local.zsh`.
3. **Fail-Closed & Independent:** The absence of the private layer never breaks the public setup. No secrets, credentials, or private keys are ever tracked in public repositories.
4. **Overlay:** a private repository of your own can add layers: it uses the same format (`layers/<name>/layer.conf`, `packages/`, `home/`) and is applied with `--overlay ~/.dotfiles-private`. Each of its layers applies on its own once every layer it `requires` is selected (for example `requires=core`, or `requires=dev` to apply only with the opt-in `dev` layer); its features work like public ones. The overlay path is saved in the selection receipt, so `sync` and `update` re-apply and pull it; `--no-overlay` stops applying it. Overlay layer names cannot reuse a public layer name.

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
  The current install is detected from `~/.local/bin/dotfiles` (or `~/.dotfiles/base`; `--from DIR` overrides it). Its selection is translated: the base packages that are linked set the profile, `wm/<x>` becomes the WM layer `<x>` (its receipt keeps its profile), the old private install becomes the overlay (`--overlay DIR`, else the recorded overlay, else a sibling `DIR-private` or `dotfiles-private` next to the new checkout; the plan says which) with `development` mapped to the `dev` layer and each work component `<w>` to the overlay feature `work-<w>`, the old walls links become the `walls` component (a wallpaper a WM saved from the old walls checkout, `~/.local/state/<wm>/wallpaper`, is pointed at the same file of the component), the theme selected for the WM the shared theme points to becomes `~/.local/state/dotfiles/theme/selected`, and a `mimeapps.list` linked into the old checkout is kept as a real file with every association apps wrote through it. A monorepo checkout keeps its recorded selection. Whatever has no equivalent is listed as `No migrado:` (agent-harness and system keep their own installers) and its links stay.

  Before anything changes, the new checkout's own dry-run checks collisions: a real file or a link that points anywhere but the replaced checkouts aborts the switch with nothing changed and every path listed. Then a manifest of every link being replaced (path and old destination) and a snapshot of the state directory are saved under `~/.local/state/dotfiles/transactions/`; only links into the replaced checkouts are removed and the selection is applied through the new checkout's `bootstrap` (`--stow-only` unless `--with-packages`). If any step fails, the target is restored as it was. `switch --rollback --apply` restores the last switch later: old links, files and receipts come back, and files that appeared since are moved aside to `transactions/displaced-*`, never deleted, including inside directories the switch created. A change interrupted before its manifest was written changed nothing and is discarded with a warning. Neither checkout is ever modified.
- **Optional System Layer (`system`):** Applies [`layers/system`](layers/system/README.md) (Ly display manager, Limine theme, DNS-over-TLS) to `/etc` and `/boot` under an explicit `sudo`. It is opt-in: `bootstrap`, `sync` and `update` never run it, and `update` only warns when a pulled change touched it. The applied selection is saved in `~/.local/state/dotfiles/system.receipt`:
  ```bash
  ./bin/dotfiles system setup --ly --dns --provider quad9 --install
  ./bin/dotfiles system doctor
  ```

---

## 🌐 Related Repositories

| Repository | Role |
| :--- | :--- |
| **[walls](https://github.com/anthonyportugal/walls)** | Curated WebP wallpaper collection, added with `dotfiles add walls` (see `components.conf`) |

`dotfiles-mangowm`, `dotfiles-bspwm` and `dotfiles-system` are archived: they became `layers/wm/mangowm`, `layers/wm/bspwm` and `layers/system`.

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

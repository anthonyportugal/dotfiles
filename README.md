# Dotfiles

*Read this in other languages:* [Español](README.es.md)

Public base configuration for an Arch Linux / CachyOS environment. This repository
is migrating from an Archcraft-dependent setup toward a portable, modular base that
is completely independent of the chosen Window Manager or compositor.

> **Status:** migration in progress. The base repository features its own bootstrap
> and doctor commands, and the bspwm repository has already been validated as a
> standalone project. Optional integration between both and the contract with an
> independent private layer are finalized. P11 delivered a standalone MangoWM
> candidate and optional composition; P10 is active after an initial functional
> installation in a VM and a round of regressions identified there.

## Repository Scope & Responsibilities

The base repository is responsible for:

- Portable shell and CLI tooling;
- Common application configurations that do not belong to a specific WM;
- Self-contained profiles and dependencies;
- Installation and validation of its own scope;
- Optional orchestration of other repositories via public CLI contracts.

It is NOT responsible for:

- Bundling all Window Managers / compositors internally;
- Requiring private configuration to function;
- Managing secrets, GPU drivers, or display managers;
- Implicitly reproducing files that Archcraft copied from `/etc/skel`.

## Related Repositories

- [`bspwm`](https://github.com/anthonyportugal/bspwm): Independent public X11
  project, with validated standalone installation.
- [`mangowm`](https://github.com/anthonyportugal/dotfiles-mangowm): Independent
  public Wayland project. Session lifecycle, bootstrap, theme, and features are
  validated in isolation, and its initial graphical installation opened P10.
- Private dotfiles: Optional, independent layer for non-secret personal or work
  configurations. Its absence never breaks public repositories.
- Wallpapers: Independent, optional asset source; currently private and
  potentially public in the future.

The base repository does not depend architecturally on any of these. It can invoke
the public entrypoint of an external checkout, but does not clone, update, or read
their internals.

## Approved Architectural Direction

- GNU Stow with explicit packages and conflict detection.
- Independent repositories without submodules as a final mechanism.
- Configuration precedence: public defaults → optional private → local machine overrides.
- Bootstrap compatible with Shelly on CachyOS, as well as `paru`, `yay`, and
  `pacman` according to their capabilities.
- Zsh without Oh My Zsh, directly integrating `zsh-autosuggestions`,
  `zsh-completions`, `zsh-history-substring-search`, and
  `zsh-syntax-highlighting`.

Agreed application defaults:

- Global dark theme preference via `prefer-dark` (GTK);
- Alacritty with a Catppuccin appearance shared across sessions;
- Brave as web browser;
- Zathura with MuPDF for PDF viewing;
- Micro as terminal text editor;
- imv as image viewer for Wayland and X11;
- Yazi and Thunar as terminal and graphical file managers;
- mpv with `mpv-mpris` and Playerctl for media playback/control;
- Foot as default terminal for the MangoWM session;
- Fuzzel as Wayland application launcher;
- Waybar for MangoWM / Wayland.

bspwm preserves Polybar and Alacritty for X11. Foot, Fuzzel, and Waybar belong
to the MangoWM repository and do not cover X11.

## Layout During Migration

`home/` is the dedicated stow directory. Each immediate subdirectory represents a
small package reflecting paths relative to `$HOME`:

```text
home/
├── alacritty/
├── bat/
├── git/
├── starship/
├── xdg-defaults/
└── zsh/
```

These packages are migrated and validated. Any dotfiles still located outside
`home/` represent transitional state; the repository root must never be treated
as a Stow package.

Package manifests and provenance are documented in
[`packages/README.md`](packages/README.md). They are consumed by the bootstrap
CLI and are not meant to be run directly.

## Recommended Local Organization

Repositories do not require a fixed location, but examples in this documentation
use the following directory structure:

```text
~/.dotfiles/
├── base/          # public base dotfiles repository
└── wm/
    ├── bspwm/     # public bspwm standalone repository
    └── mangowm/   # public MangoWM standalone repository
```

Each directory is an independent Git checkout with its own `origin` and history.
Sharing `~/.dotfiles/` as a parent folder does not create a monorepo, does not
introduce submodules, and does not allow the base to inspect WM internals. It also
keeps WM checkouts outside `base/`, as required by `--wm-path`.

## Base Repository Bootstrap

Prepare the parent container directory:

```bash
mkdir -p "$HOME/.dotfiles"
```

For a new checkout via SSH:

```bash
git clone --branch refactor/modular-dotfiles \
  git@github.com:anthonyportugal/dotfiles.git "$HOME/.dotfiles/base"
cd "$HOME/.dotfiles/base"
```

For read-only public access via HTTPS:

```bash
git clone --branch refactor/modular-dotfiles \
  https://github.com/anthonyportugal/dotfiles.git "$HOME/.dotfiles/base"
cd "$HOME/.dotfiles/base"
```

The explicit branch is temporary while this migration refactor is merged into
`main`.

The public entrypoint is [`bin/dotfiles`](bin/dotfiles). It works without bspwm,
MangoWM, or private configuration. It requires an Arch-based distribution with
Bash and pacman; Git is only required to clone the repository. From
`~/.dotfiles/base`, run dry-run first:

```bash
./bin/dotfiles bootstrap --profile desktop
```

The command displays platform, backend, installed/missing packages, planned
installation command, Stow packages, and collisions. It also executes native Stow
simulation when available. If the plan looks correct:

```bash
./bin/dotfiles bootstrap --profile desktop --apply
./bin/dotfiles doctor --profile desktop
```

The `desktop` profile installs `glib2` and `gsettings-desktop-schemas`, and
idempotently applies `org.gnome.desktop.interface color-scheme=prefer-dark` when
targeting the current user's `$HOME`. An isolated test target does not modify host
`dconf`. If the settings backend is not yet available during bootstrap, the MangoWM
session retries the same entrypoint, and `doctor` reports pending preferences.

### Activating Zsh as Login Shell

Installing Zsh and plugins does not automatically switch the user's login shell.
Check which shell is active in the terminal and which is registered:

```bash
ps -p $$ -o comm=
getent passwd "$USER" | cut -d: -f7
```

If Bash is still active, test the public configuration immediately:

```bash
exec zsh
```

To permanently switch login shell, use `chsh`. Select the first valid Zsh path
listed in `chsh --list-shells`, and log out of the session (e.g. Ly) completely:

```bash
zsh_login_shell=$(chsh --list-shells | awk '/\/zsh$/ { print; exit }')
printf 'Selected shell: %s\n' "$zsh_login_shell"
chsh -s "$zsh_login_shell"
```

On a standard Arch / CachyOS install, this resolves to `/bin/zsh` or `/usr/bin/zsh`.
Do not use a path that is not registered in `chsh --list-shells`.

Bootstrap and `doctor` display an actionable warning when operating on the
current home if a non-Zsh login shell is detected. They do not run `chsh`
automatically or attempt to source `.zshrc` from Bash.

Do not run the entire bootstrap with `sudo`: the backend elevates package
installation privileges internally, and Stow always runs as the unprivileged user.
Application re-simulates immediately before linking, uses `--no-folding`, never
uses `--adopt`, and stops on any collision.

### Profiles, Features, and Backend Selection

Cumulative profiles are `core`, `cli`, and `desktop`; `desktop` is the default.
Yazi extras are opt-in:

```bash
./bin/dotfiles bootstrap --profile desktop --feature yazi-extras
./bin/dotfiles bootstrap --profile desktop --feature yazi-extras --apply
```

Automatic backend detection prefers Shelly on CachyOS, then `paru`, `yay`, and
finally `pacman`. An explicit backend override is available:

```bash
./bin/dotfiles bootstrap --profile desktop --backend paru
```

Shelly, paru, and yay resolve AUR packages. pacman is limited to binary
repositories and preflight fails before modifying the system if AUR packages
remain missing. On generic Arch, Brave uses the AUR fallback only after checking
`core`, `extra`, and `multilib`; on CachyOS, native repository manifests are used.

### Partial Operations, Doctor, and Unlink

`--packages-only` and `--stow-only` allow isolating package management and dotfile
symlinking:

```bash
./bin/dotfiles bootstrap --profile core --packages-only
./bin/dotfiles bootstrap --profile desktop --stow-only
./bin/dotfiles doctor --profile desktop --stow-only
```

`doctor` is strictly read-only. It validates packages, backend capability, Zsh
syntax, Alacritty TOML, and verifies that every target is a symlink pointing to the
expected source.

`unlink` simulates by default without deleting packages or unmanaged files;
`--apply` removes managed symlinks:

```bash
./bin/dotfiles unlink --profile desktop
./bin/dotfiles unlink --profile desktop --apply
```

The full CLI manual is available via `./bin/dotfiles help`.

## Optional Private and Local Configuration

The base repository functions completely without private dotfiles. It exposes
stable inclusion drop-in paths:

| Area | Optional Private | Local Machine Override |
| --- | --- | --- |
| Zsh | `~/.config/zsh/private.zsh` | `~/.config/zsh/local.zsh` |
| Git | `~/.config/git/private.gitconfig` | `~/.config/git/local.gitconfig` |

Precedence order:

```text
public defaults → optional private → local machine overrides
```

Git cleanly ignores missing includes. Public configuration defines editor, initial
branch, and `user.useConfigOnly = true`; it contains no names, emails, keys, or
organization settings. Strict mode ensures commits without classified identity
fail instead of inheriting incorrect credentials. A private layer can use
`includeIf` to isolate identities per directory:

```gitconfig
[includeIf "gitdir:~/dev/work/example/"]
    path = ~/.config/git/identities/example.gitconfig
```

Legacy `~/.gitconfig` must not coexist. Git reads XDG config first and
`~/.gitconfig` second, which could override the precedence contract. `bootstrap`
and `doctor` detect and halt on legacy `~/.gitconfig` files.

OpenSSH has no public include because hosts and identities belong to private or
local layers. Private keys, credentials, `known_hosts`, and agent state must remain
outside Git.

### Integrating a Private Layer

After installing base, you can:

1. Manually create required optional drop-in files; or
2. Manage them in an independent private repository via GNU Stow.

A minimal private Stow layout:

```text
private-dotfiles/
└── home/
    ├── git-private/
    │   └── .config/git/private.gitconfig
    ├── ssh-private/
    │   └── .ssh/config
    └── zsh-private/
        └── .config/zsh/private.zsh
```

Applied from that repository:

```bash
stow --dir=home --target="$HOME" --no-folding \
  git-private ssh-private zsh-private
```

Quick post-integration verification:

```bash
git config --global --show-origin --get init.defaultBranch
git config --show-origin --get user.email   # inside a classified repo
zsh -lic 'alias >/dev/null'
ssh -G host-alias >/dev/null
```

## Optional Integration with bspwm

bspwm maintains its own repository, profiles, dependencies, and lifecycle.
Recommended location is `~/.dotfiles/wm/bspwm`:

```bash
mkdir -p "$HOME/.dotfiles/wm"
git clone --branch refactor/standalone-bspwm \
  https://github.com/anthonyportugal/bspwm.git "$HOME/.dotfiles/wm/bspwm"
```

Install standalone via `bin/bspwm`, or compose plans from the base CLI:

```bash
cd "$HOME/.dotfiles/base"

./bin/dotfiles bootstrap --profile desktop \
  --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" --wm-profile desktop

./bin/dotfiles bootstrap --profile desktop \
  --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" --wm-profile desktop --apply

./bin/dotfiles doctor --profile desktop \
  --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" --wm-profile desktop
```

The WM profile is decoupled from the base profile. `--packages-only`,
`--stow-only`, backend, platform, and target propagate cleanly. The base runs
the WM preflight first; it never executes `git pull`, `commit`, or `push` on
external checkouts.

## Optional Integration with MangoWM

MangoWM follows the same independent contract:

```bash
mkdir -p "$HOME/.dotfiles/wm"
git clone https://github.com/anthonyportugal/dotfiles-mangowm.git \
  "$HOME/.dotfiles/wm/mangowm"
```

Compose plans from the base CLI:

```bash
cd "$HOME/.dotfiles/base"

./bin/dotfiles bootstrap --profile desktop \
  --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
  --wm-profile desktop --wm-feature laptop

./bin/dotfiles bootstrap --profile desktop \
  --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
  --wm-profile desktop --wm-feature laptop --apply

./bin/dotfiles doctor --profile desktop \
  --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
  --wm-profile desktop --wm-feature laptop
```

The resulting session entrypoint is `~/.local/bin/mangowm-session`.

### Boundaries and Manual Steps

- Upgrading the system before rebuilding remains an explicit user choice; bootstrap
  does not run system upgrades.
- AUR helpers retain interactive prompts for reviewing PKGBUILDs; `--noconfirm`
  is not forced.
- Colliding files must be reviewed, backed up, or removed manually before applying.
- Display managers, hybrid GPU drivers, services, secrets, and Git lifecycle remain
  outside the scope of this bootstrap.

## Roadmap & Collaboration

Architecture, decisions, phases, and live progress are tracked in the
[migration plan](docs/migration-plan.md). Rules for future agent sessions and
contributors are in [AGENTS.md](AGENTS.md).

Phases require explicit approval before implementation. Commits are not created
without explicit request.

## License

Original code and configuration in this repository are published under the
[MIT License](LICENSE). Third-party vendored assets retain their notices in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

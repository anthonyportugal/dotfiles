# Dependency Manifests

*Read this in other languages:* [Español](README.es.md)

Each layer declares its installation requirements under
`layers/<layer>/packages/`, and `package-backends.txt` in this directory holds the
backend order every layer shares. They are declarative inputs for `bin/dotfiles`;
they are not executable scripts and must not be run directly.

## Format

- UTF-8 encoded, one package name per line;
- Empty lines and lines starting with `#` are ignored;
- Trailing comments on package entries are not permitted;
- Package and GNU Stow entries are sorted alphabetically;
- No version pinning against rolling-release distribution packages.

`package-backends.txt` is the sole exception to alphabetical ordering: its order
is semantic and dictates detection precedence.

## Sources and Provenance

`repo/` contains binary packages resolvable via `pacman`, sourced from official
Arch Linux repositories (`core`, `extra`, `multilib`) and optimized CachyOS mirrors.

Distinct package sources are maintained separately:

- `cachyos/`: Packages native to the CachyOS repository (e.g., `brave-bin`);
- `aur/`: Explicit fallback source, never mixed with binary repository packages;
- `external/`: Sources outside pacman/AUR; none are currently declared in base.

For the Brave browser, CachyOS utilizes `layers/desktop/packages/cachyos/desktop.txt` (native optimized
binary). On generic Arch Linux, the resolver checks `core`, `extra`, and
`multilib` first, falling back to `layers/desktop/packages/aur/desktop-fallback.txt` only when absent.
Both entries represent alternative sources for the same package, not duplicate
installations.

## Profiles

Profiles are cumulative:

| Profile / Feature | Inherits | System Packages | Stow Packages |
| --- | --- | --- | --- |
| `core` | — | `layers/core/packages/repo/core.txt` | `layers/core/packages/stow/core.txt` |
| `cli` | `core` | `layers/cli/packages/repo/cli.txt` | `layers/cli/packages/stow/cli.txt` |
| `desktop` | `cli` | `layers/desktop/packages/repo/desktop.txt` plus selected Brave source | `layers/desktop/packages/stow/desktop.txt` |
| `yazi-extras` | Opt-in feature over `cli` or `desktop` | `layers/cli/packages/repo/yazi-extras.txt` | None |

### Profile Details

- **`core`**: Establishes the minimal shell and version control foundation.
  Installs Zsh, Git, GNU Stow, and the four official Zsh extensions
  (`zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting`, and
  `zsh-history-substring-search`). Its Stow packages are `git` and `zsh`.
- **`cli`**: Enriches the interactive terminal experience. Adds the Starship prompt,
  Fzf, Micro, Bat, Btop, Fastfetch, Lazygit, Yazi, Git-Delta, Glow, Sad, and
  Nerd Fonts symbol glyphs. Its Stow packages deploy Catppuccin Mocha configurations
  for these utilities.
- **`desktop`**: Delivers session-independent graphical utilities. Includes
  Alacritty and Foot terminal emulators, lightweight document/image viewers (IMV,
  Zathura with MuPDF backend), multimedia player (MPV with MPRIS integration), media
  controller (Playerctl), Thunar file manager with Tumbler thumbnailing, Catppuccin
  themes (Adw-gtk3-dark and Papirus-Dark), and the fonts: JetBrains Mono Nerd, the
  Nerd Font symbols, and Noto for text, CJK, and color emoji. Its Stow packages
  link Alacritty, Foot, and `xdg-defaults`, whose fontconfig fallbacks draw icons
  and emoji after the role font.
- **`yazi-extras`**: Enables rich file previews, high-performance search, and
  archive support in the Yazi file manager (including `7zip`, `chafa`, `fd`,
  `ffmpeg`, `imagemagick`, `jq`, `poppler`, `resvg`, and `ripgrep`).

## Design & Security Contracts

- **Public Git Contract (`core`):** The `git` Stow package only configures
  generic, portable defaults alongside optional includes for
  `~/.config/git/private.gitconfig` and `~/.config/git/local.gitconfig`. It contains
  no personal identities, emails, signing keys, or work paths. It strictly enforces
  `user.useConfigOnly = true`, and preflight validation rejects any legacy
  `~/.gitconfig` file in `$HOME`.
- **Zsh Plugins:** Plugins are sourced directly from standard system paths
  (`/usr/share/zsh/plugins/`). Login shells are not switched automatically: activation
  remains an explicit user choice via `chsh`.
- **JavaScript Ecosystem Exclusion:** No Node.js, npm, pnpm, or Bun runtimes are
  declared in this public repository. Runtimes, package managers, and AI agent
  skills belong strictly to the private overlay.

## Bootstrap Backends

`package-backends.txt` registers the approved detection order: Shelly (CachyOS
only) → `paru` → `yay` → `pacman`. A specific backend can be enforced via
`--backend`.

Adapters respect each tool's native capabilities:
- **Shelly:** Dispatches separate `install standard` and `install aur` operations;
- **paru / yay:** Executes batched `-S --needed` commands separating repo and AUR packages;
- **pacman:** Resolves official binary repositories only, failing during preflight
  if an unmet AUR package is detected.

## Contract with Window Manager Layers

Window manager layers (`layers/wm/<name>`) declare `requires=desktop` in their
`layer.conf`: choosing one always applies the base `core`, `cli` and `desktop`
layers first. A WM layer therefore declares only what its own session needs and
does not repeat packages the base layers already install.

# MangoWM dotfiles

*Read this in other languages:* [Español](README.es.md)

Foundation of a public, autonomous Wayland session tailored for CachyOS / Arch Linux.
MangoWM serves as the primary compositor with a minimal, portable, and secure stack.

> [!WARNING]
> **Work in progress:** this repository is not yet a stable release;
> its installation and graphical desktop experience continue to be validated in P10.
>
> **Current status:** P11 standalone candidate completed and initial P10
> installation started in a VM. MangoWM boots and the base stack works; regressions
> identified during VM testing are now covered with automated regression tests before
> repeating the full graphical checklist.

## Objectives

- Function without Archcraft, base dotfiles, bspwm, or private configurations;
- Provide self-contained dry-run, bootstrap, doctor, and unlink operations;
- Avoid hardcoded hardware paths and detect capabilities dynamically;
- Keep configuration, generated state, and secrets under strict separate ownership;
- Prioritize performance and battery life while delivering a complete desktop experience;
- Achieve a standalone candidate before end-to-end VM validation.

## Approved Stack

| Capability | Selection |
| --- | --- |
| Compositor | Stable MangoWM (`mangowm`) |
| Terminal | Foot |
| Launcher | Fuzzel |
| Status Bar | Waybar |
| Wallpaper | Swaybg |
| Notifications | Mako |
| Lock / Idle | Swaylock, Swayidle, and Wlopm |
| Session Menu | wlogout |
| Night Light | Gammastep (manual toggle) |
| Clipboard | wl-clipboard (no persistent history by default) |
| Screenshots | Grim, Slurp, and Satty |
| Portals | xdg-desktop-portal, wlr, and gtk |
| Polkit | polkit-gnome |
| Audio | PipeWire and WirePlumber |
| X11 Compatibility | Xorg XWayland and xwayland-satellite |

`wf-recorder` belongs to the `recording` feature; `brightnessctl` to `laptop`.
Desktop shells, Pywal, clipboard history daemons, MPD/MPC, or Hyprland components
are not installed by default.

## Directory Layout

```text
.
├── bin/mango
├── docs/architecture.md
├── home/
│   ├── mango/             # core session
│   ├── mango-desktop/     # desktop UX
│   ├── mango-laptop/      # backlight control feature
│   └── mango-recording/   # screen recording feature
├── packages/
├── tests/
│   ├── bootstrap-smoke.sh
│   ├── scaffold-smoke.sh
│   └── session-smoke.sh
└── themes/catppuccin-mocha-pink/palette.conf
```

`home/` is the dedicated stow directory. `mango` installs the compositor, lock/idle,
portals, and entrypoint; other packages are composed only when their profile or
feature is selected. `config.local.conf` loads at the end and is never versioned.
Package manifests are consumed by `bin/mango` and separated by source.

## Themes

The default theme is Catppuccin Mocha with Pink accent. The canonical palette uses
semantic roles and is located in `themes/catppuccin-mocha-pink/palette.conf`.

`mango-theme` parses the palette as data and atomically renders adapters for
MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, wlogout, and Satty under
`$XDG_STATE_HOME/mangowm/theme/`. Each revision is immutable and `current` switches
atomically. Theme changes never rewrite versioned source files. GTK and shared apps
belong to the base dotfiles repository.

## Profiles and Features

- `core`: minimal secure and complete session;
- `desktop`: bar, screenshots, night light, wallpaper selector, and extra desktop tools;
- feature `laptop`: hardware backlight control via Brightnessctl;
- feature `recording`: on-demand screen recording via wf-recorder.

Detailed composition is documented in `packages/README.md`.

## Bootstrap

All commands support dry-run simulation by default unless `--apply` is provided;
`doctor` is strictly read-only:

```bash
./bin/mango bootstrap --profile desktop
./bin/mango bootstrap --profile desktop --feature laptop --apply
./bin/mango doctor --profile desktop --feature laptop
./bin/mango unlink --profile desktop
./bin/mango unlink --profile desktop --apply
```

`--packages-only` and `--stow-only` allow isolating package installation from symlinking.
Supported backends: `auto`, `shelly`, `paru`, `yay`, and `pacman`. Never execute the
entire entrypoint with `sudo`.

Run smoke tests in an isolated temporary target:

```bash
./tests/scaffold-smoke.sh
./tests/bootstrap-smoke.sh
./tests/session-smoke.sh
```

## Launching the Session

After applying the profile, the session entrypoint is:

```bash
~/.local/bin/mangowm-session
```

The entrypoint configures the XDG / Wayland environment, materializes the theme,
and starts Mango. `exec-once` imports the environment into D-Bus / systemd and launches
Mako, Swayidle, Swaybg, Waybar, and Polkit as idempotent user units. Portals are
activated on-demand by D-Bus.

Swaylock confirms via `ready-fd` that the lock surface is visible before Swayidle
proceeds with suspension events. Defaults lock after 5 minutes and turn off outputs
after 10 minutes.

### Primary Keybindings

| Shortcut | Action |
| --- | --- |
| `Super+Return` / `Super+D` | Foot terminal / Fuzzel launcher |
| `Super+L` | Idempotent screen lock |
| `Print` / `Shift+Print` | Region / fullscreen screenshot with Satty |
| `Ctrl+Print` | Region screenshot directly to clipboard |
| `Super+Print` | Region screenshot with Satty for annotation |
| `Super+X` | wlogout session menu |
| `Super+N` | Manual night light toggle (4000 K) |
| `Super+Ctrl+W` | Wallpaper selector via Fuzzel |
| `Alt+Space` | Toggle keyboard layout between US and Latin America |
| `Super+Ctrl+R` | Toggle screen recording (if feature is installed) |

Screenshot and recording paths resolve via XDG user directories with portable fallbacks.

## Active P10 Validation

The first VM installation confirmed MangoWM booting and identified three initial
refinements: wlogout JSON-stream layout, Satty explicit shortcut, and GTK dark
preference propagation. These are now covered with regression tests for the next
VM validation checkpoint.

## License

Original code and configuration are licensed under MIT. Catppuccin palette retains
its attribution in `THIRD_PARTY_NOTICES.md`.

# MangoWM Manifests

*Read this in other languages:* [Español](README.es.md)

These files serve as declarative inputs for `bin/mango`. The entrypoint validates
each line, rejects duplicate entries, and preserves package provenance before
constructing any package manager commands.

Each non-empty, non-comment line contains one package name. Rolling-release
versions are never pinned. Provenance is separated into `repo/`, `aur/`, and
`external/`; GNU Stow packages are declared separately in `stow/`.

## Profiles

| Selection | Content | Stow Package |
| --- | --- | --- |
| `core` | Wayland compositor, Foot terminal, Fuzzel launcher, Mako notifications, lockscreen via Swaylock-effects, Swayidle, clipboard (`wl-clipboard`), XDG portals, Polkit, PipeWire/WirePlumber audio, and base XWayland. | `mango` |
| `desktop` | `core` plus Waybar, `wlogout` session menu, wallpapers (`swaybg`), screenshots (Grim/Slurp/Satty), Gammastep night light, screen recording (`wf-recorder`), brightness control (`brightnessctl`), media controls (`playerctl`), Blueman Bluetooth applet, JetBrains Mono fonts, and XWayland-Satellite. | `mango` |

Both profiles select the single Stow package `mango`. The default profile is `desktop`.

## Provenance

Resolution priority is CachyOS binary → Arch binary (`repo/`) → AUR (`aur/`).

- **`repo/`**: Most of the Wayland stack is available as official binary packages.
- **`aur/`**:
  - `mangowm`: Stable upstream release packaged in AUR;
  - `swaylock-effects-git`: Replaces standard `swaylock` to provide desktop blur effects, Catppuccin Mocha ring indicators, and aesthetic customization;
  - `wlogout`: Wayland logout menu provided via AUR for distributions without the Archcraft repository.
- **`external/`**: No direct external downloads are currently used; intentionally empty.

The package manager will deduplicate packages also declared by base dotfiles.
This repository never inspects manifests from other checkouts.

## Exclusion Decisions

- **No Hyprlock / Hypridle:** Uses `swaylock-effects-git` and `swayidle` for broader wlroots portability and stability.
- **No Rofi / Wofi:** Fuzzel is utilized for its pure Wayland speed and minimal footprint.
- **No Pulsemixer:** WirePlumber and `wpctl` manage PipeWire natively without extra abstraction layers.
- **No Wlsunset:** Gammastep reliably handles manual and scheduled color temperature shifts.
- **No clipboard history / persistence daemons by default:** Prevents accidental leakage of secrets and passwords.
- **No GNOME portal, Pywal, or Pastel:** Maintains a lean environment free of heavy desktop-environment services.
- **No Catppuccin GTK:** GTK theme and icon ownership is handled centrally by the base repository.

## Backends

The bootstrap detects Shelly only on CachyOS and continues through `paru`,
`yay`, and `pacman`. Pacman is strictly limited to binary packages and aborts
before modifying the system if an AUR package (`mangowm`, `swaylock-effects-git`,
or `wlogout`) is missing. Shelly, paru, and yay preserve interactive review
prompts without forcing automated confirmations.

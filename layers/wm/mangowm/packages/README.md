# Manifiestos de MangoWM

Estos archivos documentan datos de entrada para el futuro `bin/mango`; todavía
no existe un consumidor y por eso no deben ejecutarse ni tratarse como una
instalación funcional.

Cada línea no vacía ni comentada contiene un paquete. No se fijan versiones de
repositorios rolling. La procedencia se separa en `repo/`, `aur/` y
`external/`; los paquetes Stow se registran aparte en `stow/`.

## Perfiles

| Selección | Contenido |
| --- | --- |
| `core` | Compositor, terminal, launcher, notificaciones, lock/idle, clipboard, portales, Polkit, audio y XWayland base. |
| `desktop` | `core` más Waybar, screenshots anotables, night light, fuentes y Satellite. |
| feature `laptop` | Brightnessctl para backlights reales. |
| feature `recording` | wf-recorder bajo demanda. |

El perfil default futuro será `desktop`. Las features son opt-in y no se
activan silenciosamente por detección de hardware.

## Procedencia

La prioridad es CachyOS binario → Arch binario → AUR. En este scaffold:

- el stack general está disponible como paquetes binarios bajo `repo/`;
- `mangowm` estable está registrado en AUR hasta verificar un binario apropiado
  en una VM CachyOS limpia;
- `wlogout` está en AUR para un Arch/CachyOS sin repositorio Archcraft;
- `mangowm-git` no se selecciona: será una opción edge sólo si aparece una
  necesidad reproducible;
- no hay descargas externas directas.

El package manager deduplicará paquetes que también declare la base. Este
repositorio nunca leerá manifests de otro checkout.

## Decisiones de exclusión

- no Hyprlock/Hypridle: se usan Swaylock/Swayidle;
- no Rofi/Wofi: se usa Fuzzel;
- no Pulsemixer: se usa WirePlumber/`wpctl`;
- no Wlsunset: Gammastep cubre el toggle manual;
- no clipboard history/persistence por defecto;
- no portal GNOME, desktop shell, MPD/MPC, Pywal ni Pastel;
- no Catppuccin GTK: es shared ownership del repositorio base.

`xorg-xwayland` se declara aunque el paquete del compositor pueda depender de
él: la compatibilidad X11 forma parte explícita del alcance. `playerctl` se
declara en `desktop` porque Waybar y bindings consumirán MPRIS.

## Backends

El futuro bootstrap detectará Shelly sólo en CachyOS y continuará con `paru`,
`yay` y `pacman`. Pacman se limitará a paquetes binarios y deberá fallar antes
de mutar si falta un paquete AUR. Shelly/paru/yay conservarán prompts de
revisión; no se forzará confirmación automática.

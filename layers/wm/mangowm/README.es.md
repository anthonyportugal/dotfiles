# MangoWM dotfiles

*Read this in other languages:* [English](README.md)

Fundación de una sesión Wayland pública, autónoma y orientada a CachyOS/Arch.
MangoWM será el compositor principal, con un stack pequeño, portable y seguro.

> [!WARNING]
> **Trabajo en progreso:** este repositorio todavía no es una versión estable;
> su instalación y experiencia gráfica continúan validándose en P10.
>
> **Estado actual:** candidata standalone de P11 completa y primera instalación
> P10 iniciada en una VM. MangoWM arranca y el stack base funciona; las
> incidencias descubiertas durante esa prueba se cubren ahora con regresiones
> automatizadas antes de repetir el checklist gráfico.

## Objetivos

- funcionar sin Archcraft, dotfiles base, bspwm ni configuración privada;
- ofrecer dry-run, bootstrap, doctor y unlink propios;
- evitar hardcodes de hardware y detectar capacidades;
- mantener configuración, estado generado y secretos con owners distintos;
- priorizar rendimiento/batería sin sacrificar una experiencia de escritorio
  completa;
- llegar a una candidata standalone antes de la prueba integral en VM.

## Stack aprobado

| Capacidad | Selección |
| --- | --- |
| Compositor | MangoWM estable (`mangowm`) |
| Terminal | Foot |
| Launcher | Fuzzel |
| Barra | Waybar |
| Wallpaper | Swaybg |
| Notificaciones | Mako |
| Lock/idle | Swaylock, Swayidle y Wlopm |
| Menú de sesión | wlogout |
| Luz nocturna | Gammastep manual |
| Clipboard | wl-clipboard, sin historial predeterminado |
| Capturas | Grim, Slurp y Satty |
| Portales | xdg-desktop-portal, wlr y gtk |
| Polkit | polkit-gnome |
| Audio | PipeWire y WirePlumber |
| X11 | Xorg XWayland y xwayland-satellite |

`wf-recorder` pertenece a la feature `recording`; `brightnessctl` a `laptop`.
No se instalarán desktop shells, Pywal, clipboard history, MPD/MPC ni
componentes de Hyprland por defecto.

## Layout

```text
.
├── bin/mango
├── docs/architecture.md
├── home/
│   ├── mango/             # sesión core
│   ├── mango-desktop/     # UX desktop
│   ├── mango-laptop/      # feature de backlight
│   └── mango-recording/   # feature de grabación
├── packages/
├── tests/
│   ├── bootstrap-smoke.sh
│   ├── scaffold-smoke.sh
│   └── session-smoke.sh
└── themes/catppuccin-mocha-pink/palette.conf
```

`home/` es el único stow directory. `mango` instala el compositor, lock/idle,
portales y entrypoint; los otros paquetes se componen únicamente al seleccionar
su perfil o feature. `config.local.conf` se carga al final y nunca se versiona.
Los manifests son consumidos por `bin/mango` y permanecen separados por
procedencia.

## Temas

El default es Catppuccin Mocha con Pink como acento. La paleta canónica usa
roles semánticos y está en `themes/catppuccin-mocha-pink/palette.conf`.

`mango-theme` valida la paleta como datos —nunca la ejecuta— y renderiza
adaptadores de MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock, wlogout y Satty
bajo `$XDG_STATE_HOME/mangowm/theme/`. Cada revisión es inmutable y `current`
cambia atómicamente. Cambiar de tema no modifica archivos versionados. GTK y
aplicaciones compartidas pertenecen al repositorio base.

## Perfiles y features

- `core`: sesión mínima segura y completa;
- `desktop`: barra, capturas, luz nocturna y compatibilidad adicional;
- feature `laptop`: control real de backlight mediante Brightnessctl;
- feature `recording`: grabación bajo demanda con wf-recorder.

La procedencia y composición exactas viven en `packages/README.md`. Las
features se pueden repetir y se deduplican sin activarse por detección de
hardware.

## Bootstrap

Todas las operaciones son inspeccionables. `bootstrap` y `unlink` hacen dry-run
salvo que se proporcione `--apply`; `doctor` nunca modifica el sistema.

```bash
./bin/mango bootstrap --profile desktop
./bin/mango bootstrap --profile desktop --feature laptop --apply
./bin/mango doctor --profile desktop --feature laptop
./bin/mango unlink --profile desktop
./bin/mango unlink --profile desktop --apply
```

`--packages-only` y `--stow-only` permiten aislar responsabilidades. Los
backends soportados son `auto`, `shelly`, `paru`, `yay` y `pacman`; Pacman falla
antes de mutar cuando falta un paquete AUR. Nunca ejecute el entrypoint completo
con `sudo`.

El smoke test enlaza únicamente dentro de un home temporal:

```bash
./tests/scaffold-smoke.sh
./tests/bootstrap-smoke.sh
./tests/session-smoke.sh
```

## Iniciar la sesión

Después de aplicar el perfil, el entrypoint público de sesión es:

```bash
~/.local/bin/mangowm-session
```

El entrypoint fija el entorno XDG/Wayland, materializa el tema y ejecuta Mango.
`exec-once` importa el entorno en D-Bus/systemd y levanta Mako, Swayidle,
Swaybg, Waybar y Polkit como unidades de usuario idempotentes. Al terminar el
compositor, se detienen únicamente esas unidades. Los portales se activan por
D-Bus; no se lanzan backends manualmente.

Swaylock confirma mediante `ready-fd` que el bloqueo es visible antes de que
Swayidle continúe con un evento de suspensión. Los defaults bloquean a los
cinco minutos, apagan todos los outputs a los diez y no suspenden la máquina.

Atajos principales:

| Atajo | Acción |
| --- | --- |
| `Super+Return` / `Super+D` | Foot / Fuzzel |
| `Super+L` | Bloqueo idempotente |
| `Print` / `Shift+Print` | Región / pantalla completa con Satty |
| `Ctrl+Print` | Región directa al clipboard |
| `Super+Print` | Región con Satty para anotar |
| `Super+X` | wlogout |
| `Super+N` | Luz nocturna manual a 4000 K |
| `Super+Ctrl+W` | Selector de wallpaper con Fuzzel |
| `Alt+Space` | Alternar teclado US/Latinoamérica |
| `Super+Ctrl+R` | Toggle de grabación si la feature está instalada |

Los paths de capturas y grabaciones se resuelven mediante XDG user dirs con
fallbacks portables. No se codifican monitores, baterías, interfaces, GPUs ni
backlights concretos.

## Validación P10 activa

La primera instalación en una VM CachyOS confirmó el inicio de MangoWM y expuso
tres ajustes: el layout JSON-stream de wlogout, un atajo explícito para Satty y
la preferencia GTK oscura compartida. Después de aplicar estas correcciones P10
debe repetir menú, capturas, aplicaciones GTK, portales, grabación y composición
con la base. La configuración del display manager continúa fuera del alcance.

## Licencia

El código y la configuración originales usan MIT. La paleta Catppuccin conserva
su atribución en `THIRD_PARTY_NOTICES.md`.

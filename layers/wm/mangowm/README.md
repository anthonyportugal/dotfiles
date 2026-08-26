# MangoWM dotfiles

Fundación de una sesión Wayland pública, autónoma y orientada a CachyOS/Arch.
MangoWM será el compositor principal, con un stack pequeño, portable y seguro.

> **Estado:** bootstrap standalone disponible para P11. El ciclo dry-run/apply,
> `doctor`, `unlink`, perfiles, features y el primer paquete Stow están
> validados de forma aislada. La gestión completa de paquetes requiere todavía
> la VM y la sesión gráfica completa todavía no está implementada.

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

## Layout actual

```text
.
├── bin/mango
├── docs/architecture.md
├── home/
│   ├── .stow
│   └── mango/.config/mango/config.conf
├── packages/
├── tests/
│   ├── bootstrap-smoke.sh
│   └── scaffold-smoke.sh
└── themes/catppuccin-mocha-pink/palette.conf
```

`home/` es el único stow directory. El paquete `mango` administra exclusivamente
`~/.config/mango`; su baseline desactiva blur y carga opcionalmente
`config.local.conf` sin versionarlo. Los manifests son consumidos por
`bin/mango` y permanecen separados por procedencia.

## Temas

El default es Catppuccin Mocha con Pink como acento. La paleta canónica usa
roles semánticos y está en `themes/catppuccin-mocha-pink/palette.conf`.

Los futuros adaptadores de Foot, Fuzzel, Waybar, Mako, Swaylock, wlogout y
Satty renderizarán bajo `$XDG_STATE_HOME/mangowm/theme/`. Cambiar de tema no
modificará archivos versionados. GTK y aplicaciones compartidas pertenecen al
repositorio base; la integración se hará después mediante entrypoints públicos.

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
```

## Próximo vertical

Implementar la primera sesión funcional: MangoWM, Foot, Fuzzel, Waybar, Mako,
lock/idle, portales y wrappers seguros. El bootstrap actual prepara ese trabajo,
pero aún no constituye una sesión gráfica candidata para uso diario.

## Licencia

El código y la configuración originales usan MIT. La paleta Catppuccin conserva
su atribución en `THIRD_PARTY_NOTICES.md`.

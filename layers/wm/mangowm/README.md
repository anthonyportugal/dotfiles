# MangoWM dotfiles

Fundación de una sesión Wayland pública, autónoma y orientada a CachyOS/Arch.
MangoWM será el compositor principal, con un stack pequeño, portable y seguro.

> **Estado:** scaffold inicial de P11. Las decisiones, manifiestos, esquema de
> temas y validaciones estructurales existen; `bin/mango`, los paquetes Stow y
> la sesión funcional todavía no están implementados. Este checkout no debe
> usarse aún para instalar una sesión real.

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
├── docs/architecture.md
├── home/.stow
├── packages/
├── tests/scaffold-smoke.sh
└── themes/catppuccin-mocha-pink/palette.conf
```

`home/` está reservado como stow directory, pero no selecciona ningún paquete
hasta que la primera configuración funcional tenga bootstrap, doctor y pruebas
de enlace. Los manifests documentan el plan aprobado; todavía no son
consumidos por un entrypoint.

## Temas

El default es Catppuccin Mocha con Pink como acento. La paleta canónica usa
roles semánticos y está en `themes/catppuccin-mocha-pink/palette.conf`.

Los futuros adaptadores de Foot, Fuzzel, Waybar, Mako, Swaylock, wlogout y
Satty renderizarán bajo `$XDG_STATE_HOME/mangowm/theme/`. Cambiar de tema no
modificará archivos versionados. GTK y aplicaciones compartidas pertenecen al
repositorio base; la integración se hará después mediante entrypoints públicos.

## Perfiles previstos

- `core`: sesión mínima segura y completa;
- `desktop`: barra, capturas, luz nocturna y compatibilidad adicional;
- feature `laptop`: control real de backlight mediante Brightnessctl;
- feature `recording`: grabación bajo demanda con wf-recorder.

La procedencia y composición exactas viven en `packages/README.md`.

## Próximo vertical

Implementar `bin/mango` con `bootstrap`, `doctor` y `unlink` dry-run por
defecto, junto con el primer paquete Stow mínimo. Hasta entonces no se publican
comandos de instalación ni se crea un remoto.

## Licencia

El código y la configuración originales usan MIT. La paleta Catppuccin conserva
su atribución en `THIRD_PARTY_NOTICES.md`.

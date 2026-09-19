# Manifiestos de MangoWM

*Leer esto en otros idiomas:* [English](README.md)

Estos archivos son datos de entrada para `bin/mango`. El entrypoint valida cada
línea, rechaza duplicados y conserva la procedencia antes de construir cualquier
comando de instalación.

Cada línea no vacía ni comentada contiene un paquete. No se fijan versiones de
repositorios rolling. La procedencia se separa en `repo/`, `aur/` y
`external/`; los paquetes Stow se registran aparte en `stow/`.

## Perfiles

| Selección | Contenido | Paquete Stow |
| --- | --- | --- |
| `core` | Compositor, terminal Foot, launcher Fuzzel, notificaciones Mako, lockscreen con Swaylock-effects, Swayidle, clipboard (`wl-clipboard`), portales XDG, Polkit, audio PipeWire/WirePlumber y XWayland base. | `mango` |
| `desktop` | `core` más barra Waybar, menú de salida `wlogout`, wallpapers (`swaybg`), capturas con Grim/Slurp/Satty, filtro nocturno Gammastep, grabación con `wf-recorder`, control de brillo con `brightnessctl`, control de medios `playerctl`, applet Bluetooth Blueman, fuentes JetBrains Mono y XWayland-Satellite. | `mango` |

Ambos perfiles seleccionan el único paquete Stow `mango`. El perfil predeterminado es `desktop`.

## Procedencia

La prioridad de resolución es CachyOS binario → Arch binario (`repo/`) → AUR (`aur/`).

- **`repo/`**: La mayor parte del stack Wayland está disponible como paquetes binarios oficiales.
- **`aur/`**:
  - `mangowm`: Versión estable empaquetada en AUR;
  - `swaylock-effects-git`: Reemplaza al `swaylock` estándar para habilitar difuminado de pantalla (blur), anillo de indicadores Catppuccin Mocha y personalización estética;
  - `wlogout`: Menú de sesión en Wayland provisto vía AUR para distribuciones sin repositorio Archcraft.
- **`external/`**: No se emplean descargas externas directas; actualmente vacío.

El package manager deduplicará paquetes que también declare la base. Este
repositorio nunca leerá manifiestos de otro checkout.

## Decisiones de exclusión

- **No Hyprlock / Hypridle:** Se utiliza `swaylock-effects-git` y `swayidle` para máxima portabilidad y estabilidad sobre wlroots.
- **No Rofi / Wofi:** Se emplea Fuzzel por su velocidad nativa en Wayland y diseño minimalista.
- **No Pulsemixer:** WirePlumber y `wpctl` gestionan el audio nativo de PipeWire sin capas intermedias.
- **No Wlsunset:** Gammastep cubre el control manual y programado de temperatura de color.
- **No clipboard history / persistence por defecto:** Para evitar fugas involuntarias de contraseñas o tokens sensibles.
- **No portal GNOME, Pywal ni Pastel:** Se preserva un entorno ligero y libre de dependencias pesadas.
- **No Catppuccin GTK:** La configuración temática GTK y de iconos pertenece al repositorio base.

## Backends

El bootstrap detecta Shelly sólo en CachyOS y continúa con `paru`, `yay` y
`pacman`. Pacman se limita a paquetes binarios y falla antes de mutar el sistema
si falta un paquete AUR (`mangowm`, `swaylock-effects-git` o `wlogout`).
Shelly, paru y yay conservan los prompts de revisión; no se fuerza confirmación
automática.

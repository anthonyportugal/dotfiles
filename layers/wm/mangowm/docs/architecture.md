# Arquitectura de MangoWM

Este documento describe el alcance aprobado de P11 y el contrato que deberá
preservar la implementación. El plan histórico global permanece en el
repositorio base; este archivo sólo contiene decisiones duraderas de MangoWM.

## Principios

- repositorio standalone, composición opcional;
- un owner por ruta;
- dry-run antes de cualquier mutación;
- defaults portables y overrides locales al final;
- hardware por capacidades, nunca por nombres predefinidos;
- procesos event-driven y features bajo demanda;
- código fuente inmutable frente a runtime y cambios de tema.

## Ownership

MangoWM será dueño de:

- `~/.config/mango` y la sesión Wayland;
- configuración de Foot, Fuzzel, Waybar, Mako, Swaylock, Swayidle, wlogout y
  Satty cuando se instalen mediante este repositorio;
- wrappers de lock, screenshots, recording, night light y power menu;
- routing de portales específico de la sesión;
- adaptadores de tema exclusivos de esos componentes;
- dependencias, bootstrap, doctor, unlink y pruebas de su alcance.

No será dueño de:

- configuración compartida de Alacritty, Brave, Thunar, mpv, Micro o Yazi;
- tema GTK global y asociaciones MIME compartidas;
- display manager, drivers, política GPU o suspensión automática del sistema;
- wallpapers obligatorios, secrets, private keys o clipboard history;
- configuración privada o local de una organización/máquina.

## Perfiles y features

Los perfiles serán acumulativos:

```text
core
└── desktop
    ├── feature laptop
    └── feature recording
```

`core` será una sesión mínima segura; `desktop` será el default usable. Las
features no se activarán implícitamente por detectar hardware: la detección
sirve para degradar con claridad, no para cambiar la selección declarada.

## Seguridad de sesión

Un único wrapper idempotente iniciará Swaylock. Lo consumirán el binding
`Super+L`, wlogout, Swayidle y el evento previo a suspend. La configuración no
aceptará transparencia ni password vacío.

Defaults previstos:

- lock a los cinco minutos;
- apagar todos los outputs a los diez minutos mediante Wlopm;
- restaurar outputs al volver;
- no suspender automáticamente desde los dotfiles.

Los tiempos y la política de energía podrán reemplazarse en un archivo local no
versionado. Ningún output se identificará por un nombre fijo.

## Portales

La sesión importará `WAYLAND_DISPLAY` y `XDG_CURRENT_DESKTOP=mango` en el
entorno D-Bus/systemd del usuario. El routing previsto es:

```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
```

El backend GNOME queda fuera para evitar selección ambigua. Los portales se
activarán por D-Bus; no se lanzarán copias manuales paralelas.

## Capturas y grabación

Grim obtiene la imagen, Slurp selecciona y Satty anota. La UX inicial será:

- `Print`: región y Satty;
- `Shift+Print`: pantalla completa y Satty;
- `Ctrl+Print`: región directa al clipboard;
- `Enter` en Satty: guardar y copiar;
- `Escape`: cancelar.

Las capturas vivirán en el directorio XDG `Pictures/Screenshots`. La feature
`recording` añadirá wf-recorder y escribirá bajo `Videos/Recordings`; no habrá
un daemon de grabación en background.

## Contrato de temas

La fuente es una paleta de texto plano con `schema=1`, identificador, metadatos,
colores Catppuccin y roles semánticos resueltos. El parser futuro deberá:

1. rechazar claves desconocidas, faltantes o duplicadas;
2. aceptar sólo IDs seguros y colores hex RGB en minúsculas;
3. renderizar primero a un directorio temporal dentro de XDG state;
4. validar todos los outputs;
5. promoverlos atómicamente;
6. recargar sólo procesos pertenecientes a esta sesión.

El default es `catppuccin-mocha-pink`. Los artefactos irán a
`$XDG_STATE_HOME/mangowm/theme/<id>/` y la selección activa será estado local,
no un cambio Git. Foot/Fuzzel podrán usar includes nativos cuando corresponda;
Waybar/wlogout usarán CSS y el resto recibirá un archivo generado o un path
explícito. No habrá un daemon de temas.

El tema GTK es compartido y pertenece al repositorio base. Este repositorio no
vendoriza ni instala silenciosamente el port GTK archivado de Catppuccin.

## Degradación y rendimiento

- Waybar usará módulos event-driven; se evitará polling rápido y Cava.
- Swaybg usará wallpapers estáticos.
- Blur estará desactivado o acotado y `blur_optimized=1` será el default.
- Clipboard history y persistence serán opt-in por su impacto de privacidad.
- XWayland y Satellite estarán disponibles para compatibilidad, sin forzar
  escalado fraccional a todos los equipos.
- Brightnessctl sólo pertenecerá a la feature `laptop`; Gammastep no se tratará
  como control de backlight.

## Contrato público

`bin/mango` expone:

```text
bootstrap  dry-run por defecto; paquetes + Stow sólo con --apply
doctor     validación read-only
unlink     dry-run por defecto; sólo retira symlinks propios
```

Usa perfiles `core|desktop`, features `laptop|recording`, backends
`auto|shelly|paru|yay|pacman`, plataforma `auto|cachyos|arch`, target explícito
y modos `--packages-only`/`--stow-only`. La base podrá delegar en este contrato
sin leer manifests ni metadata Git de MangoWM.

El primer paquete Stow materializa sólo `~/.config/mango/config.conf`. Mantiene
un baseline pequeño, carga `config.local.conf` de forma opcional y bloquea rutas
fuera de `.config/mango`. La sesión y los adaptadores de tema se añadirán en
verticales posteriores sin ampliar silenciosamente este ownership.

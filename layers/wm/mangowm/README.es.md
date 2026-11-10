# MangoWM Dotfiles

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://wayland.freedesktop.org"><img src="https://img.shields.io/badge/Display-Wayland-00599C?style=flat-square&logo=wayland&logoColor=white" alt="Wayland"></a>
  <a href="https://github.com/mangowm/mango"><img src="https://img.shields.io/badge/WM-MangoWM-orange?style=flat-square" alt="MangoWM"></a>
  <a href="https://mangowm.github.io/showcase/"><img src="https://img.shields.io/badge/Showcase-MangoWM-orange?style=flat-square&logo=github" alt="Showcase de MangoWM"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Tema-Catppuccin_Mocha-cba6f7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Tema"></a>
  <a href="../../../LICENSE"><img src="https://img.shields.io/badge/Licencia-MIT-blue.svg?style=flat-square" alt="Licencia"></a>
</p>

*Leer esto en otros idiomas:* [English](README.md)

Sesión de Wayland autónoma, modular y minimalista optimizada para **Arch Linux** utilizando [MangoWM](https://github.com/mangowm/mango) como compositor dinámico principal, destacada oficialmente en el [Showcase de MangoWM](https://mangowm.github.io/showcase/), y estilizada con la paleta **Catppuccin Mocha** (compatible con sus 14 acentos intercambiables). Es una capa del monorepo de dotfiles.

> [!TIP]
> 🧩 **Capa del monorepo de dotfiles:**
> [Base y CLI](../../../README.es.md) • [BSPWM (X11)](../bspwm/README.es.md) • **MangoWM (Wayland) [Actual]**
>
> Esta es una capa del monorepo de dotfiles. Se instala con `bin/dotfiles --wm mangowm` del repositorio.

---

## ✨ Características Principales

- 🚀 **Mosaico Wayland Dinámico:** Compositor moderno de última generación con cambio de disposiciones en caliente (*Dwindle, Tile, Grid, Monocle, Scroller*).
- 🎨 **Tematización Dinámica Atómica:** MangoWM aporta plantillas al motor compartido `dotfiles-theme` (capa desktop), que genera la configuración de MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock y Wlogout con 14 acentos Mocha intercambiables.
- 📊 **Waybar y Notificaciones a Medida:** Barra de estado con controles interactivos, reproducción multimedia en vivo, estado de red, batería y notificaciones con Mako.
- 💻 **Laptop y Grabación Integradas:** Control de brillo por hardware (`brightnessctl`) y grabación fluida de pantalla (`wf-recorder`) listos para usar sin configuración adicional.
- 🌙 **Confort Visual y Luz Nocturna:** Integración con Gammastep para ajuste de temperatura de color con estado en vivo y conmutable desde Waybar.
- 🔒 **GNU Stow y Cero Basura:** Arquitectura limpia de 2 niveles (`core`, `desktop`) con simulación segura (dry-run) y diagnósticos de salud del sistema (`doctor`).

---

## 🧱 Arquitectura Modular

La configuración de MangoWM está organizada en perfiles acumulativos administrados mediante [GNU Stow](https://www.gnu.org/software/stow/):

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      MANGO DESKTOP ECOSYSTEM (WAYLAND)                 │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                   PERFIL DESKTOP (UX y Shell)                    │  │
│  │  • Barra de Estado: Waybar (Catppuccin Mocha, 14 Acentos)        │  │
│  │  • Menú de Apps y Apagado: Fuzzel, Wlogout                       │  │
│  │  • Notificaciones y Bloqueo: Mako, Swaylock-effects, Swayidle    │  │
│  │  • Fondos y Multimedia: Swaybg, Playerctl, MPV-MPRIS             │  │
│  │  • Luz Nocturna y Grabación: Gammastep, WF-Recorder              │  │
│  │  • Brillo por Hardware y Audio: Brightnessctl, WirePlumber       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                     PERFIL CORE (Wayland Mínimo)                 │  │
│  │  • Gestor de Ventanas: MangoWM (Compositor de Mosaico Dinámico)  │  │
│  │  • Terminal: Foot (Nativo de Wayland, Tema Catppuccin)           │  │
│  │  • Lanzador y Portales: Fuzzel, Portales XDG Desktop             │  │
│  │  • Tema: plantillas para el motor compartido dotfiles-theme      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Desglose de Perfiles

| Perfil | Paquete Stow | Contenido | Destino recomendado |
| :--- | :--- | :--- | :--- |
| **`core`** | `mango` | Compositor MangoWM, terminal Foot, lanzador Fuzzel, Swaylock, Swayidle, Mako, portales y menú `mango-theme` (plantillas de tema para `dotfiles-theme`). | Sistemas mínimos, servidores con Wayland o entornos headless. |
| **`desktop`** | Reutiliza `mango` | `core` más barra Waybar, menú de energía Wlogout, fondos Swaybg, Gammastep, capturas Satty, grabación WF-Recorder y controles de brillo. | Estaciones de trabajo completas, portátiles y VMs. |

---

## 🛠️ Stack Tecnológico Aprobado

| Capacidad | Componente | Propósito |
| :--- | :--- | :--- |
| **Compositor** | [`mangowm`](https://github.com/mangowm/mango) | Compositor Wayland de ventanas en mosaico dinámico |
| **Barra de Estado** | `waybar` | Barra de estado personalizable mediante CSS |
| **Lanzador de Apps** | `fuzzel` | Lanzador de aplicaciones rápido y nativo de Wayland |
| **Terminal** | `foot` | Emulador de terminal ultrarrápido y ligero |
| **Notificaciones** | `mako` | Daemon minimalista de notificaciones para Wayland |
| **Bloqueador de Pantalla** | `swaylock` | Bloqueador de pantalla con gestión de reposo vía `swayidle` |
| **Menú de Energía** | `wlogout` | Menú interactivo de cierre de sesión, suspensión y reinicio |
| **Fondo de Pantalla** | `swaybg` | Motor ligero para fondos de pantalla en Wayland |
| **Luz Nocturna** | `gammastep` | Ajuste de temperatura de color para descanso visual |
| **Audio / Multimedia** | PipeWire & Playerctl | Servidor de audio con integración MPRIS |
| **Capturas** | `satty` & `grim` | Selección por región con anotaciones interactivas |
| **Grabación de Pantalla** | `wf-recorder` | Grabación fluida acelerada por hardware |

---

## 🚀 Instalación

Este gestor de ventanas es una capa del monorepo de dotfiles (`layers/wm/mangowm`).
No tiene CLI propia: el `bin/dotfiles` del repositorio la instala con el motor
compartido, junto con la base sobre la que se apoya.

```bash
./bin/dotfiles setup                                   # asistente guiado
./bin/dotfiles bootstrap --wm mangowm --apply             # base + MangoWM
./bin/dotfiles bootstrap --wm mangowm --wm-profile core --apply
./bin/dotfiles doctor --wm mangowm
./bin/dotfiles unlink --wm mangowm --apply
```

`sync` y `update` re-aplican la selección guardada en cada máquina, así que la
capa sigue instalada sin volver a pasar `--wm`.

### Contrato de la capa

- `layer.conf`: perfiles (`core desktop`), nombre del recibo y directorios en
  los que se podan enlaces huérfanos.
- `packages/`: manifiestos `repo`, `aur`, `aur/*-fallback` y `cachyos` por perfil.
- `home/`: paquetes de GNU Stow.
- `hooks/validate`: comprobaciones de ownership, sintaxis y portabilidad antes
  de enlazar (el unlink sólo comprueba ownership).
- `hooks/post-link`: renderiza el tema inicial en el XDG state del destino.

---

## 🎨 Paleta y Temas
 
El entorno utiliza el tema **Catppuccin Mocha**, compatible con sus **14 paletas de acento oficiales** (*Rosewater, Flamingo, Pink, Mauve, Red, Maroon, Peach, Yellow, Green, Teal, Sky, Sapphire, Blue, Lavender*), con **Pink (`#f5c2e7`)** configurado como valor inicial predeterminado.

- **Selector Interactivo de Temas:** Presiona `Super + Alt + T` para elegir un tema en tiempo real mediante Fuzzel, en tres niveles: familia (Catppuccin, Sanctuary) → flavour (Compline, Matins, Vespers; se omite en una familia con un solo flavour, como Catppuccin Mocha) → acento. Cada entrada muestra una muestra de color, el tema activo se marca `(actual)` y `Esc` vuelve un nivel (desde el primero cierra el menú). Los niveles vienen de `dotfiles-theme menu`, compartido con el selector Rofi de bspwm.
- **CLI de Tematización (`mango-theme`, interfaz de `dotfiles-theme`):**
  ```bash
  # Abrir el menú interactivo de temas
  mango-theme menu

  # Establecer un tema específico directamente (ej. mauve, blue, teal, peach)
  mango-theme set catppuccin-mocha-mauve

  # Listar todos los ids de tema (Catppuccin Mocha y Sanctuary)
  mango-theme list

  # Elegir un tema en la terminal (fzf) con vista previa de la paleta
  mango-theme pick

  # Mostrar el tema activo actual
  mango-theme current
  ```
- **Renderizado Atómico Dinámico:** La capa solo aporta plantillas (`~/.local/share/dotfiles/theme/templates/mangowm/`) y un hook de recarga en vivo (`reload.d/mangowm`). El motor compartido `dotfiles-theme` las renderiza desde `themes/palettes/` bajo `$XDG_STATE_HOME/dotfiles/theme/current/mangowm/` mediante enlaces simbólicos atómicos y sin daemons en segundo plano; ver `themes/README.md` en la raíz del repositorio.

---

## ⌨️ Atajos de Teclado Principales

### Aplicaciones y Lanzadores

| Atajo | Acción |
| :--- | :--- |
| `Super + Return` | Abrir terminal Foot (Mosaico) |
| `Super + Shift + Return` | Abrir terminal Foot flotante |
| `Super + D` | Abrir lanzador de aplicaciones Fuzzel |
| `Super + B` | Abrir navegador web predeterminado (Brave) |
| `Super + E` | Abrir explorador de archivos gráfico (Thunar) |
| `Super + F1` / `Super + Shift + ?` | Abrir hoja de trucos interactiva de atajos |

### Gestión de Ventanas y Modos

| Atajo | Acción |
| :--- | :--- |
| `Super + C` / `Super + Shift + C` | Cerrar / Forzar cierre de ventana enfocada |
| `Super + T` | Alternar disposiciones (*Dwindle, Tile, Grid, Monocle, Scroller*) |
| `Super + Escape` | Recargar configuración de MangoWM |
| `Super + Shift + Escape` | Salir de la sesión MangoWM |

### Sistema y Utilidades

| Atajo | Acción |
| :--- | :--- |
| `Super + Alt + T` | Abrir el selector interactivo de temas (Fuzzel: familia → flavour → acento) |
| `Super + L` | Bloquear pantalla de inmediato (Swaylock) |
| `Super + X` | Abrir menú de apagado/energía (Wlogout) |
| `Super + Shift + P` | Abrir selector interactivo de perfiles de energía (Fuzzel) |
| `Super + Shift + W` | Abrir selector interactivo de redes Wi-Fi (Fuzzel) |
| `Super + V` | Abrir menú interactivo de control de volumen (Fuzzel) |
| `Super + N` | Alternar filtro de luz nocturna (Gammastep con indicador en Waybar) |
| `Super + W` / `Super + Ctrl + W` | Seleccionar fondo desde la galería vía Fuzzel (Swaybg) |
| `Print` / `Super + Print` / `Super + Shift + S` | Captura interactiva por región con editor de anotaciones Satty |
| `Shift + Print` | Captura de pantalla completa con editor Satty |
| `Ctrl + Print` | Copiar captura por región directamente al portapapeles |
| `Super + R` / `Super + Shift + R` | Grabación de pantalla completa o por región (wf-recorder) |
| `Super + Alt + R` | Menú interactivo de opciones de audio para grabación (Fuzzel) |

---

## 🧪 Pruebas y Verificación

Ejecuta la suite del repositorio desde la raíz del monorepo. Recorre esta capa
a través de `bin/dotfiles` y ejecuta sus pruebas de sesión:

```bash
./tests/smoke.sh
```

---

## 👤 Autor

Diseñado y mantenido por [Anthony Portugal](https://anthonyportugal.github.io/es/).

---

## 📄 Licencia

El código original y la configuración se distribuyen bajo la [Licencia MIT](../../../LICENSE).
Las paletas de colores de Catppuccin y avisos de terceros se detallan en el [`THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md) del repositorio.

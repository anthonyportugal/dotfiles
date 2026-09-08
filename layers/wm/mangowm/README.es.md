# MangoWM Dotfiles

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles-mangowm/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles-mangowm/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://wayland.freedesktop.org"><img src="https://img.shields.io/badge/Display-Wayland-00599C?style=flat-square&logo=wayland&logoColor=white" alt="Wayland"></a>
  <a href="https://github.com/mangowm/mango"><img src="https://img.shields.io/badge/WM-MangoWM-orange?style=flat-square" alt="MangoWM"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha_Pink-f5c2e7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Leer esto en otros idiomas:* [English](README.md)

Sesión de Wayland autónoma, modular y minimalista optimizada para **Arch Linux** y **CachyOS** utilizando [MangoWM](https://github.com/mangowm/mango) como compositor dinámico principal, estilizado con la paleta Catppuccin Mocha con acentos Rosa. Funciona de manera totalmente independiente o compuesta dentro del ecosistema modular de dotfiles.

<p align="center">
  <img src="assets/screenshot.webp" alt="Vista previa del escritorio MangoWM" width="100%">
</p>

> [!TIP]
> 🧩 **Ecosistema Modular de Dotfiles:**  
> [Base y CLI](https://github.com/anthonyportugal/dotfiles) • **MangoWM (Wayland) [Actual]** • [BSPWM (X11)](https://github.com/anthonyportugal/dotfiles-bspwm) • [Fondos de Pantalla](https://github.com/anthonyportugal/walls) • [Capa del Sistema (Ly y Limine)](https://github.com/anthonyportugal/dotfiles-system)
> 
> Este repositorio proporciona un entorno de escritorio Wayland autónomo y listo para producción, integrándose limpiamente con el ecosistema de dotfiles base.

---

## ✨ Características Principales

- 🚀 **Mosaico Wayland Dinámico:** Compositor moderno de última generación con cambio de disposiciones en caliente (*Dwindle, Tile, Grid, Monocle, Scroller*).
- 🎨 **Tematización Dinámica Atómica:** Motor integrado `mango-theme` que compila la paleta de colores para MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock y Wlogout.
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
│  │  • Barra de Estado: Waybar (Catppuccin Pink, Detección Dinámica) │  │
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
│  │  • Motor de Tema: mango-theme (Compilación Atómica Dinámica)     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Desglose de Perfiles

| Perfil | Paquete Stow | Contenido | Destino recomendado |
| :--- | :--- | :--- | :--- |
| **`core`** | `mango` | Compositor MangoWM, terminal Foot, lanzador Fuzzel, Swaylock, Swayidle, Mako, portales y motor `mango-theme`. | Sistemas mínimos, servidores con Wayland o entornos headless. |
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

## 🚀 Instalación y Perfiles

La CLI incluida `./bin/mango` gestiona la instalación de paquetes y los enlaces simbólicos de GNU Stow con seguridad dry-run integrada.

### 1. Experiencia de Escritorio Completa (Recomendado)

Instala todos los paquetes de escritorio y enlaza la configuración unificada de `mango`:

```bash
./bin/mango bootstrap --profile desktop --apply
```

### 2. Sesión Core Minimalista (Solo Gestor de Ventanas)

Instala solo el compositor, la terminal, el lanzador y el bloqueador sin barras de estado ni daemons de escritorio:

```bash
./bin/mango bootstrap --profile core --apply
```

### Flags Útiles del Asistente

- **Simulación Dry-run (Modo seguro):** Omite `--apply` para previsualizar acciones sin modificar el sistema de archivos:
  ```bash
  ./bin/mango bootstrap --profile desktop
  ```
- **Diagnósticos:** Verifica el estado de dependencias y la integridad de enlaces:
  ```bash
  ./bin/mango doctor --profile desktop
  ```
- **Desvincular / Limpiar:** Retira los enlaces simbólicos administrados de forma limpia:
  ```bash
  ./bin/mango unlink --profile desktop --apply
  ```
- **Backend AUR:** Detección automática (`shelly`, `paru`, `yay`), o configurable mediante `--backend <nombre>`.

---

## 🔗 Integración con Dotfiles Base

Aunque este repositorio funciona de manera **100% independiente**, se integra limpiamente con el ecosistema de dotfiles:

- 🌐 **Repositorio Base:** [anthonyportugal/dotfiles](https://github.com/anthonyportugal/dotfiles)
- **Ecosistema Compartido:** Al instalarse junto con el repositorio base, MangoWM sincroniza las preferencias de modo oscuro global, alias de shell compartidos, configuraciones de Neovim y variables de tema GTK a través de `$HOME/.local/lib/dotfiles/session-preferences`.

---

## 🎨 Paleta y Temas

El entorno utiliza el tema **Catppuccin Mocha** con acentos semánticos en **Pink (`#f5c2e7`)**.

- **Configuración de Paleta:** `themes/catppuccin-mocha-pink/palette.conf`
- **Renderizado Atómico Dinámico:** El script `mango-theme` procesa las variables de color y genera los archivos de configuración en tiempo de ejecución para MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock y Wlogout bajo `$XDG_STATE_HOME/mangowm/theme/current/`.

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
| `Super + L` | Bloquear pantalla de inmediato (Swaylock) |
| `Super + X` | Abrir menú de apagado/energía (Wlogout) |
| `Super + Shift + P` | Abrir selector interactivo de perfiles de energía (Fuzzel) |
| `Super + N` | Alternar filtro de luz nocturna (Gammastep con indicador en Waybar) |
| `Super + W` / `Super + Ctrl + W` | Seleccionar fondo desde la galería vía Fuzzel (Swaybg) |
| `Print` / `Super + Print` / `Super + Shift + S` | Captura interactiva por región con editor de anotaciones Satty |
| `Shift + Print` | Captura de pantalla completa con editor Satty |
| `Ctrl + Print` | Copiar captura por región directamente al portapapeles |
| `Super + R` / `Super + Shift + R` | Grabación de pantalla completa o por región (wf-recorder) |
| `Super + Alt + R` | Menú interactivo de opciones de audio para grabación (Fuzzel) |

---

## 🧪 Pruebas y Verificación

Ejecuta la suite de smoke tests local para verificar enlaces, manifiestos y la sesión:

```bash
./tests/scaffold-smoke.sh
./tests/bootstrap-smoke.sh
./tests/session-smoke.sh
```

---

## 📄 Licencia

El código original y la configuración se distribuyen bajo la [Licencia MIT](LICENSE).
Las paletas de colores de Catppuccin y avisos de terceros se detallan en `THIRD_PARTY_NOTICES.md`.

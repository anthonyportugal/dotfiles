# MangoWM Dotfiles

<p align="center">
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://wayland.freedesktop.org"><img src="https://img.shields.io/badge/Display-Wayland-00599C?style=flat-square&logo=wayland&logoColor=white" alt="Wayland"></a>
  <a href="https://github.com/mangowm/mango"><img src="https://img.shields.io/badge/WM-MangoWM-orange?style=flat-square" alt="MangoWM"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha_Pink-f5c2e7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Tema"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="Licencia"></a>
</p>

*Read this in other languages:* [English](README.md)

Sesión Wayland autónoma, modular y minimalista optimizada para **Arch Linux** y **CachyOS** utilizando [MangoWM](https://github.com/mangowm/mango) como compositor principal de ventanas en mosaico dinámico con la paleta Catppuccin Mocha y acentos en Pink. Funciona de manera 100% independiente o compuesta con el ecosistema principal de dotfiles modulares.

<p align="center">
  <img src="assets/screenshot.webp" alt="Vista previa de MangoWM Desktop" width="100%">
</p>

> [!TIP]
> Este repositorio proporciona un entorno de escritorio Wayland autónomo y listo para producción, integrándose limpiamente con el ecosistema de dotfiles base.

---

## ✨ Características Principales

- 🚀 **Mosaico Wayland Dinámico:** Compositor moderno de última generación con cambio de disposiciones en caliente (*Dwindle, Tile, Grid, Monocle, Scroller*).
- 🎨 **Tematización Dinámica Atómica:** Motor integrado `mango-theme` que compila la paleta de colores para MangoWM, Foot, Fuzzel, Waybar, Mako, Swaylock y Wlogout.
- 📊 **Waybar y Notificaciones a Medida:** Barra de estado con controles interactivos, reproducción multimedia en vivo, estado de red, batería y notificaciones con Mako.
- 💻 **Perfiles para Portátiles y Creadores:** Módulos opcionales bajo demanda para brillo por hardware (`brightnessctl`) y grabación de pantalla (`wf-recorder`).
- 🌙 **Confort Visual y Luz Nocturna:** Integración con Gammastep para ajuste de temperatura de color con estado en vivo y conmutable desde Waybar.
- 🔒 **GNU Stow y Cero Basura:** Arquitectura por capas (`core`, `desktop`, `features`) con simulación segura (dry-run) y diagnósticos de salud del sistema (`doctor`).

---

## 🧱 Arquitectura Modular

Este repositorio utiliza una **arquitectura modular por capas** administrada mediante [GNU Stow](https://www.gnu.org/software/stow/). Cada componente está aislado en paquetes, permitiendo instalaciones personalizadas para PCs de escritorio, portátiles o sistemas mínimos sin bloatware.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     CAPA 3: FEATURES (Bajo Demanda)                    │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐  │
│  │         mango-laptop         │    │       mango-recording        │  │
│  │  • Control de brillo por     │    │  • Grabación ligera de       │  │
│  │    hardware (brightnessctl)  │    │    pantalla (wf-recorder)    │  │
│  │  • Atajos de brillo Fn       │    │  • Atajo Super+Ctrl+R        │  │
│  │  • Hooks de batería          │    │  • Indicador de grabación    │  │
│  └──────────────────────────────┘    └──────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────┤
│                   CAPA 2: PERFIL DESKTOP (UX y Shell)                  │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                          mango-desktop                           │  │
│  │  • Barra de estado (Waybar)        • Menú de energía (wlogout)   │  │
│  │  • Fondos de pantalla (Swaybg)     • Luz nocturna (Gammastep)    │  │
│  │  • Editor de capturas (Satty)      • Control de audio multimedia │  │
│  └──────────────────────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────┤
│                     CAPA 1: CORE (Base Minimalista)                    │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                              mango                               │  │
│  │  • Compositor MangoWM              • Terminal (Foot)             │  │
│  │  • Lanzador de apps (Fuzzel)       • Bloqueador (Swaylock)       │  │
│  │  • Notificaciones (Mako)           • Renderizador de tema        │  │
│  │  • Portales de escritorio Wayland  • Gestión central de ventanas │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Desglose de Capas

| Paquete | Propósito | Cuándo Instalar |
| :--- | :--- | :--- |
| **`mango`** *(Core)* | Base indispensable: configuración del compositor, terminal, lanzador, bloqueador, notificaciones y tema. | **Siempre requerido.** |
| **`mango-desktop`** | Experiencia completa: barra de estado (`Waybar`), menú de energía (`wlogout`), fondos (`Swaybg`), luz nocturna y editor de capturas (`Satty`). | **Escritorios estándar y VMs.** |
| **`mango-laptop`** | Control de brillo por hardware (`brightnessctl`), teclas Fn y hooks de batería. | **Solo en portátiles.** |
| **`mango-recording`** | Script y atajos dedicados para grabación fluida de pantalla mediante `wf-recorder`. | **Creadores de contenido / Bajo demanda.** |

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

### 1. Escritorio Estándar / Máquina Virtual (Recomendado)

Instala la base `mango` y el perfil `mango-desktop`:

```bash
./bin/mango bootstrap --profile desktop --apply
```

### 2. Configuración para Portátiles

Instala `mango` + `mango-desktop` + `mango-laptop` (agrega teclas de brillo e integración de batería):

```bash
./bin/mango bootstrap --profile desktop --feature laptop --apply
```

### 3. Estación de Trabajo Completa (con Grabación de Pantalla)

```bash
./bin/mango bootstrap --profile desktop --feature laptop --feature recording --apply
```

### 4. Sesión Core Minimalista (Solo Gestor de Ventanas)

Instala solo el compositor, la terminal y el lanzador sin barras de estado ni daemons de escritorio:

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

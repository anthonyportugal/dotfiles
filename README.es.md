# Dotfiles (Repositorio Base)

<p align="center">
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://www.gnu.org/software/stow/"><img src="https://img.shields.io/badge/Manager-GNU_Stow-informational?style=flat-square" alt="GNU Stow"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-f5c2e7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Tema"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="Licencia"></a>
</p>

*Read this in other languages:* [English](README.md)

Configuración base pública, modular y portable optimizada para entornos **Arch Linux** y **CachyOS**. Establece una experiencia de terminal unificada, herramientas CLI esenciales, aplicaciones compartidas y preferencias de sistema con total independencia del gestor de ventanas o compositor seleccionado.

> [!TIP]
> Este repositorio proporciona la base fundamental para el entorno de usuario y se integra limpiamente con gestores de ventanas independientes, compositores y una capa de configuración privada opcional.

---

## ✨ Características Principales

- ⚡ **Terminal y Shell de Alto Rendimiento:** Entorno Zsh veloz con prompt Starship, resaltado de sintaxis, autosugerencias, Fzf y Zoxide.
- 🛡️ **Privacidad Fail-Closed:** Precedencia estricta de 3 niveles (`base` ──► `private` ──► `local`) garantizando que identidades laborales, claves de firma y secretos nunca se filtren a repositorios públicos.
- 🎛️ **Orquestación Multi-WM:** Coordina de forma fluida gestores de ventanas independientes ([dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm) para Wayland y [dotfiles-bspwm](https://github.com/anthonyportugal/dotfiles-bspwm) para X11).
- 🔄 **CLI de Ciclo de Vida Seguro:** Comandos integrados `sync`, `update` (con protección para evitar sobreescribir árboles de trabajo con cambios locales) y diagnósticos `doctor`.
- 🚀 **Despliegue en un Solo Comando:** Asistente interactivo ejecutable directamente con `curl` en instalaciones limpias.
- 🎨 **Estética Visual Unificada:** Tema Catppuccin Mocha consistente en Starship, Bat, Micro, Yazi, Foot y Alacritty.

---

## 🧱 Arquitectura Modular

Este repositorio constituye la **base central** de un ecosistema modular multi-repositorio. Los gestores de ventanas (como BSPWM) y los compositores de Wayland (como MangoWM) residen en sus propios repositorios independientes y pueden instalarse por separado o componerse junto con esta base.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                       ECOSISTEMA DE DOTFILES MODULAR                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                  DOTFILES BASE (Este Repositorio)                │  │
│  │  • Shell: Zsh (Autosuggestions, Syntax Highlighting, Starship)   │  │
│  │  • Herramientas CLI: Bat, Git, Micro, Yazi, Ripgrep, Fzf         │  │
│  │  • Apps Comunes: Alacritty, Brave, MPV, Zathura, Thunar          │  │
│  │  • Preferencias: GTK Prefer-Dark, Fuentes, Hooks de Sesión       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                  │                                     │
│             ┌────────────────────┴────────────────────┐                │
│             ▼                                         ▼                │
│  ┌──────────────────────┐                  ┌──────────────────────┐    │
│  │    dotfiles-bspwm    │                  │   dotfiles-mangowm   │    │
│  │  • Sesión X11        │                  │  • Sesión Wayland    │    │
│  │  • Polybar, Rofi,    │                  │  • Waybar, Fuzzel,   │    │
│  │    Picom, Dunst      │                  │    Swaylock, wlogout │    │
│  └──────────────────────┘                  └──────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Paquetes y Perfiles

Las configuraciones están divididas en pequeños paquetes gestionados con [GNU Stow](https://www.gnu.org/software/stow/):

| Paquete | Contenido | Incluido en |
| :--- | :--- | :--- |
| **`git`** | Plantilla de configuración Git fail-closed (requiere configuración explícita de identidad) | `core`, `desktop` |
| **`zsh`** | Configuración limpia de Zsh con autosugerencias, resaltado de sintaxis y alias | `core`, `desktop` |
| **`bat`** | Temas Catppuccin para `bat` (`cat` con resaltado de sintaxis) | `cli`, `desktop` |
| **`micro`** | Editor de texto en terminal con tema Catppuccin Mocha | `cli`, `desktop` |
| **`starship`** | Tema moderno y ligero para el prompt de la shell | `cli`, `desktop` |
| **`yazi`** | Explorador de archivos ultrarrápido en terminal con tema Catppuccin Mocha | `cli`, `desktop` |
| **`foot`** | Emulador de terminal Wayland ligero con tema Catppuccin Mocha | `desktop` |
| **`alacritty`** | Emulador de terminal multiplataforma con tema Catppuccin Mocha | `desktop` |
| **`xdg-defaults`** | Ajustes GTK 3/4 `prefer-dark`, asociaciones mimeapps y hooks de sesión | `desktop` |

---

## 🔒 Integración con Dotfiles Privados Opcionales

El repositorio base implementa una estricta **precedencia de 3 niveles**:

```text
Configuración Base Pública  ──►  Capa Privada Opcional  ──►  Sobreescrituras Locales
     (~/.config/...)               (dotfiles-private)              (*.local.*)
```

1. **Identidad Git Múltiple:** `home/git/.config/git/config` carga `~/.config/git/private.gitconfig` (si existe) para emails y claves de firma personales o laborales, seguido de `~/.config/git/local.gitconfig` específico de la máquina.
2. **Entorno de Shell:** `home/zsh/.zshrc` carga automáticamente `~/.config/zsh/private.zsh` (si existe) para alias privados, variables de entorno y rutas laborales, seguido de `~/.config/zsh/local.zsh`.
3. **Fail-Closed e Independiente:** La ausencia de la capa privada nunca rompe la configuración pública. Ningún secreto, credencial o clave privada es rastreado en repositorios públicos.

---

## 🚀 Instalación y Despliegue Rápido

### 1. Instalación en un Solo Comando (Recomendado en Equipos Nuevos)

Despliega el ecosistema completo con un comando interactivo. Clona el repositorio base en `~/.dotfiles/base` e inicia el asistente de configuración:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

El asistente detectará automáticamente los repositorios existentes en `$HOME/.dotfiles/`, clonará los faltantes si lo deseas, configurará los gestores de ventanas seleccionados (MangoWM, BSPWM o ambos), los wallpapers y la capa privada (o su fallback de identidad Git local).

### 2. Si ya Clonaste el Repositorio

Si ya dispones de `~/.dotfiles/base` localmente, ejecuta el asistente:

```bash
# Opción A: A través del script bootstrap
./install.sh

# Opción B: Directamente mediante la CLI (abre el asistente interactivo si se ejecuta sin argumentos en una TTY)
./bin/dotfiles
```

### 3. Orquestación Manual por Línea de Comandos

También puedes orquestar los componentes directamente mediante flags explícitos:

- **Perfil Desktop Completo:**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop --apply
  ```
- **Perfil Core Minimalista (Solo Shell y Git):**
  ```bash
  ./bin/dotfiles bootstrap --profile core --apply
  ```
- **Composición con WMs, Wallpapers y Capa Privada:**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" --wm-feature recording \
    --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" \
    --wallpapers --wallpapers-path "$HOME/.dotfiles/walls" \
    --private --private-path "$HOME/.dotfiles/private" \
    --apply
  ```

### 4. Gestión del Ciclo de Vida: Sincronización y Actualizaciones

- **Sincronización Local (`sync`):** Re-aplica los enlaces simbólicos de GNU Stow, valida paquetes y genera configuraciones locales sin tocar Git ni alterar el historial:
  ```bash
  ./bin/dotfiles sync
  ```
- **Actualización Remota (`update`):** Comprueba el estado de Git en todos los repositorios bajo `$HOME/.dotfiles/` (`base`, `wm/*`, `walls`, `private`). Aquellos con cambios sin confirmar se omiten de forma segura para proteger el trabajo local; los limpios realizan `git pull --ff-only` seguido de un `sync` automático:
  ```bash
  ./bin/dotfiles update
  ```
- **Diagnóstico del Sistema (`doctor`):** Inspecciona la integridad de enlaces, shells y dependencias:
  ```bash
  ./bin/dotfiles doctor --profile desktop
  ```
- **Desvincular / Limpiar (`unlink`):** Retira de forma segura los enlaces simbólicos administrados:
  ```bash
  ./bin/dotfiles unlink --profile desktop --apply
  ```

---

## 🌐 Repositorios Conectados

| Repositorio | Capacidad | Protocolo Gráfico |
| :--- | :--- | :--- |
| **[dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm)** | Sesión Wayland con mosaico dinámico (Waybar + Fuzzel + Swaylock + Satty) | Wayland |
| **[dotfiles-bspwm](https://github.com/anthonyportugal/dotfiles-bspwm)** | Sesión X11 en mosaico (Polybar + Rofi + Picom + Dunst) | X11 |
| **[walls](https://github.com/anthonyportugal/walls)** | Colección curada de fondos en WebP y CLI de gestión | Multi-monitor |
| **`dotfiles-private`** | Capa privada opcional para identidades, firmas y perfiles de trabajo | Local / Seguro |

---

## 🧪 Pruebas

Ejecuta la suite de smoke tests localmente:

```bash
./tests/bootstrap-smoke.sh
```

---

## 📄 Licencia

Distribuido bajo la [Licencia MIT](LICENSE).
Las paletas de colores Catppuccin y avisos de terceros se documentan en `THIRD_PARTY_NOTICES.md`.

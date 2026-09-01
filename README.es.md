# Dotfiles (Repositorio Base)

*Read this in other languages:* [English](README.md)

Configuración base pública, modular y portable para entornos **CachyOS** y **Arch Linux**. Establece una experiencia consistente de terminal, utilidades de línea de comandos esenciales, aplicaciones compartidas y preferencias del sistema, de manera totalmente independiente del gestor de ventanas o compositor seleccionado.

> [!NOTE]
> **Trabajo en progreso:** Este repositorio se encuentra bajo refactorización activa en la rama `refactor/modular-dotfiles` ([github.com/anthonyportugal/dotfiles](https://github.com/anthonyportugal/dotfiles)).
> Proporciona la base autónoma para el entorno de usuario y se integra limpiamente con gestores de ventanas, compositores y una capa de configuración privada opcional.

---

## 🧱 Arquitectura Modular

Este repositorio constituye la **base central** de un ecosistema modular multi-repositorio. Los gestores de ventanas (como BSPWM) y los compositores de Wayland (como MangoWM) residen en sus propios repositorios independientes y pueden instalarse por separado o componerse junto con esta base.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                       ECOSISTEMA DE DOTFILES MODULAR                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                  DOTFILES BASE (Este Repositorio)                │  │
│  │  • Shell: Zsh (Autosugerencias, Resaltado de Sintaxis, Starship) │  │
│  │  • Herramientas CLI: Bat, Git, Micro, Yazi, Ripgrep, Fzf         │  │
│  │  • Aplicaciones: Alacritty, Brave, MPV, Zathura, Thunar          │  │
│  │  • Preferencias: GTK Prefer-Dark, Tipografías, Hooks de Sesión   │  │
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

Las configuraciones están organizadas en paquetes modulares administrados mediante [GNU Stow](https://www.gnu.org/software/stow/):

| Paquete | Contenido | Incluido en |
| :--- | :--- | :--- |
| **`git`** | Plantilla de configuración segura de Git (requiere configuración explícita de identidad) | `core`, `desktop` |
| **`zsh`** | Configuración limpia de Zsh con autosugerencias, resaltado de sintaxis y alias | `core`, `desktop` |
| **`bat`** | Temas Catppuccin para `bat` (visualizador con resaltado de código) | `cli`, `desktop` |
| **`micro`** | Editor de texto en terminal con tema Catppuccin Mocha | `cli`, `desktop` |
| **`starship`** | Tema y prompt moderno multiplataforma | `cli`, `desktop` |
| **`yazi`** | Explorador de archivos en terminal ultrarrápido con tema Catppuccin Mocha | `cli`, `desktop` |
| **`foot`** | Emulador de terminal ligero para Wayland con tema Catppuccin Mocha | `desktop` |
| **`alacritty`** | Emulador de terminal multiplataforma con tema Catppuccin Mocha | `desktop` |
| **`xdg-defaults`** | Ajustes GTK 3/4 `prefer-dark`, aplicaciones por defecto (`mimeapps`) y hooks | `desktop` |

---

## 🔒 Integración con Dotfiles Privados Opcionales

El repositorio base implementa una estricta **jerarquía de precedencia de 3 niveles**:

```text
Valores Base Públicos  ──►  Capa Privada Opcional  ──►  Sobrescrituras Locales
   (~/.config/...)            (dotfiles-private)            (*.local.*)
```

1. **Multi-Identidad en Git:** `home/git/.config/git/config` carga `~/.config/git/private.gitconfig` (si existe) para gestionar correos personales/laborales y claves de firma, seguido de `~/.config/git/local.gitconfig`.
2. **Entorno de Shell:** `home/zsh/.zshrc` importa automáticamente `~/.config/zsh/private.zsh` (si existe) para alias privados, variables de entorno y rutas de trabajo, seguido de `~/.config/zsh/local.zsh`.
3. **Fail-Closed e Independiente:** La ausencia de la capa privada nunca rompe la configuración pública. Ningún secreto, credencial o clave privada se versiona en los repositorios públicos.

---

## 🚀 Instalación y Uso Rápido

### 1. Clonar el Repositorio Base

```bash
mkdir -p "$HOME/.dotfiles"
git clone --branch refactor/modular-dotfiles \
  https://github.com/anthonyportugal/dotfiles.git "$HOME/.dotfiles/base"
cd "$HOME/.dotfiles/base"
```

### 2. Desplegar el Sistema Base

- **Perfil Desktop (Recomendado):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop --apply
  ```
- **Perfil Core Mínimo (Solo Shell + Git):**
  ```bash
  ./bin/dotfiles bootstrap --profile core --apply
  ```

### 3. Opcional: Componer con un Gestor de Ventanas
El CLI base puede coordinar la instalación de repositorios de WM independientes mediante `--wm-path`:

- **Componer con MangoWM (Wayland):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm-path "$HOME/.dotfiles/wm/mangowm" \
    --wm-profile desktop --apply
  ```
- **Componer con BSPWM (X11):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm-path "$HOME/.dotfiles/wm/bspwm" \
    --wm-profile desktop --apply
  ```

### Opciones Útiles del Asistente
- **Simulación Dry-run (Comprobación segura):** Omite `--apply` para inspeccionar las operaciones planificadas sin modificar archivos:
  ```bash
  ./bin/dotfiles bootstrap --profile desktop
  ```
- **Diagnóstico del sistema:** Verifica el estado de los enlaces y la configuración:
  ```bash
  ./bin/dotfiles doctor --profile desktop
  ```
- **Desvincular / Limpiar:** Retira los enlaces simbólicos de forma limpia:
  ```bash
  ./bin/dotfiles unlink --profile desktop --apply
  ```

---

## 🌐 Repositorios Relacionados

- 🪟 **[dotfiles-mangowm](https://github.com/anthonyportugal/dotfiles-mangowm):** Sesión Wayland con mosaico dinámico (MangoWM + Waybar + Swaylock + Catppuccin Mocha).
- 🪟 **[bspwm](https://github.com/anthonyportugal/bspwm):** Sesión X11 independiente (BSPWM + Polybar + Rofi + Picom + Dunst).
- 🔒 **Dotfiles Privados (`dotfiles-private`):** Capa opcional para configuraciones personales y laborales no secretas.

---

## 🧪 Pruebas Automatizadas

Ejecuta la suite de pruebas de bootstrap en local:

```bash
./tests/bootstrap-smoke.sh
```

---

## 📄 Licencia

Distribuido bajo la [Licencia MIT](LICENSE).
Las paletas de Catppuccin y avisos de terceros se detallan en `THIRD_PARTY_NOTICES.md`.

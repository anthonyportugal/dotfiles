# Configuraciones del Sistema (Ly y Limine)

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles-system/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles-system/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://codeberg.org/fairyglade/ly"><img src="https://img.shields.io/badge/DM-Ly_1.4+-ff69b4?style=flat-square" alt="Ly"></a>
  <a href="https://limine-bootloader.org/"><img src="https://img.shields.io/badge/Bootloader-Limine-blue?style=flat-square" alt="Limine"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-f5c2e7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Theme"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

*Leer esto en otros idiomas:* [English](README.md)

Configuraciones modulares, reproducibles y no destructivas a nivel de sistema para **Arch Linux** y **CachyOS**. Administra la personalización del display manager ([Ly](https://codeberg.org/fairyglade/ly)) y del gestor de arranque ([Limine](https://limine-bootloader.org/)) bajo la paleta unificada **Catppuccin Mocha**, con respaldos automáticos por marca de tiempo y scripts de despliegue idempotentes.

> [!TIP]
> 🧩 **Ecosistema Modular de Dotfiles:**  
> [Base y CLI](https://github.com/anthonyportugal/dotfiles) • [MangoWM (Wayland)](https://github.com/anthonyportugal/dotfiles-mangowm) • [BSPWM (X11)](https://github.com/anthonyportugal/dotfiles-bspwm) • [Wallpapers](https://github.com/anthonyportugal/walls) • **Capa del Sistema [Actual]**
> 
> Mientras que los dotfiles de usuario residen en `$HOME` y se gestionan sin privilegios con GNU Stow, los componentes que requieren permisos de superusuario (`/etc`, `/boot`) se mantienen aislados en este repositorio para máxima seguridad y estabilidad.

---

## ✨ Características Principales

- 🛡️ **Personalización no destructiva del Bootloader:** Inyección pura de paleta en `limine.conf`. Parámetros del kernel, rutas initramfs, tiempos de espera y UUIDs de partición se mantienen 100% intactos.
- 📦 **Respaldos Automáticos con Fecha y Hora:** Genera copias de seguridad inmutables (`.bak_YYYYMMDD_HHMMSS`) antes de modificar `/etc/ly/config.ini` o `/boot/limine.conf`.
- 🔁 **Idempotencia Estricta:** Ejecutar los scripts múltiples veces nunca duplica líneas ni contamina archivos de configuración.
- ⚡ **Instalación Asistida de Paquetes:** Detección automática del gestor de paquetes según la jerarquía del ecosistema (`shelly` → `paru` → `yay` → `pacman`), ofreciendo instalar paquetes ausentes.
- 🧪 **Pruebas Automatizadas y CI:** Verificación completa mediante GitHub Actions y suite de pruebas no privilegiada con 16 aserciones de sintaxis, ShellCheck e idempotencia.
- 🔍 **Simulación y Auditoría:** Modo de prueba (`--dry-run`) y diagnóstico del sistema (`--check`) para verificar rutas y compatibilidad sin realizar cambios.
- 🕒 **Ly Display Manager Minimalista:** Pantalla de inicio TUI limpia con reloj digital central (`bigclock = en`), reloj superior en tiempo real (`%a %d %b %H:%M`), colores Catppuccin Mocha, soporte de color real de 24 bits y sin animaciones pesadas.
- 🎨 **Paletas Oficiales de Limine:** Obtenidas directamente de [catppuccin/limine](https://github.com/catppuccin/limine), con variantes de acento Mauve (predeterminado), Pink y Blue.
- 🔒 **DNS Cifrado sobre TLS (DoT):** Resolución DNS cifrada nativa para todo el sistema mediante systemd-resolved y Quad9 (9.9.9.9) con respaldo en Cloudflare y sin daemons pesados.

---

## 🧱 Estructura del Repositorio

```text
dotfiles-system/
├── .github/workflows/ci.yml     # Flujo automatizado de CI con ShellCheck y pruebas
├── install.sh                  # Instalador maestro unificado (flags CLI + menú interactivo)
├── LICENSE                     # Licencia MIT
├── README.md                   # Documentación en Inglés
├── README.es.md                # Documentación en Español
├── dns/
│   ├── providers/              # Perfiles preconfigurados de proveedores DoT
│   │   ├── adguard.conf        # AdGuard DNS (bloqueo de publicidad y rastreadores)
│   │   ├── cloudflare.conf     # Cloudflare 1.1.1.1 (ultrarrápido, propósito general)
│   │   ├── cloudflare-security.conf # Cloudflare 1.1.1.2 (bloqueo de malware y phishing)
│   │   ├── mullvad.conf        # Mullvad DNS (sin registros, privacidad)
│   │   └── quad9.conf          # Quad9 9.9.9.9 (predeterminado, bloqueo de malware y amenazas)
│   └── setup.sh                # Instalador modular para /etc/systemd/resolved.conf.d/
├── ly/
│   ├── config.ini              # Configuración Catppuccin Mocha (INI para Ly <= 1.4)
│   ├── config.lua              # Configuración Catppuccin Mocha (Lua para Ly >= 1.5+)
│   ├── startup.sh              # Script inyector de paleta Catppuccin Mocha para TTY
│   └── setup.sh                # Instalador modular para /etc/ly/
├── limine/
│   ├── catppuccin-mocha.conf   # Tema activo por defecto (Mauve)
│   ├── setup.sh                # Inyector seguro de paleta para limine.conf
│   └── themes/
│       ├── catppuccin-mocha-blue.conf
│       ├── catppuccin-mocha-mauve.conf
│       └── catppuccin-mocha-pink.conf
└── tests/
    └── test_suite.sh           # Suite automatizada de pruebas aisladas (sin root)
```

---

## 🚀 Instalación y Uso

### 1. Clonar Repositorio

```bash
git clone https://github.com/anthonyportugal/dotfiles-system.git
cd dotfiles-system
```

### 2. Auditoría del Estado del Sistema (Modo Seguro)

Antes de aplicar cualquier cambio, puedes verificar qué componentes están instalados y dónde se encuentran las configuraciones activas:

```bash
./install.sh --check
```

### 3. Modo Simulación (Dry-Run)

Simula la instalación para previsualizar exactamente qué acciones y rutas se utilizarían sin alterar el disco:

```bash
sudo ./install.sh --dry-run
```

### 4. Despliegue de Configuraciones

#### Opción A: Instalador Maestro Unificado (Recomendado)

```bash
# Menú interactivo de selección
sudo ./install.sh

# O instalación desatendida de todos los componentes
sudo ./install.sh --all

# Instalación asistida de paquetes ausentes (shelly/paru/yay/pacman)
sudo ./install.sh --all --install

# Seleccionar un acento personalizado de Limine (mauve, pink, blue)
sudo ./install.sh --all --theme pink

# Flags componibles: instalar solo Ly y DNS (sin tocar Limine)
sudo ./install.sh --ly --dns --provider quad9
```

#### Opción B: Instalación Modular

Puedes instalar o actualizar componentes de manera individual:

* **Solo DNS-over-TLS (DoT):**
  ```bash
  # Desplegar proveedor predeterminado (Quad9 9.9.9.9)
  sudo ./dns/setup.sh

  # O seleccionar un perfil preconfigurado: quad9, cloudflare, cloudflare-security, adguard, mullvad
  sudo ./dns/setup.sh --provider adguard

  # O especificar endpoints DoT personalizados (ej. NextDNS)
  sudo ./dns/setup.sh --custom "45.90.28.0#mi-id.dns.nextdns.io"
  ```

* **Solo Ly Display Manager:**
  ```bash
  # Desplegar temas
  sudo ./ly/setup.sh

  # O desplegar e instalar automáticamente el paquete si falta
  sudo ./ly/setup.sh --install
  ```
  *Para habilitar Ly como display manager predeterminado en el arranque:*
  ```bash
  sudo systemctl enable ly@tty1.service
  ```

* **Solo Limine Bootloader:**
  ```bash
  # Instala el tema predeterminado (Mauve)
  sudo ./limine/setup.sh

  # O especifica un acento particular
  sudo ./limine/setup.sh --theme pink

  # Si tu archivo limine.conf está en una ruta personalizada
  sudo ./limine/setup.sh --config /ruta/a/limine.conf
  ```

> [!NOTE]
> **Secure Boot en CachyOS:**  
> Si tienes Secure Boot activado en Limine 11.2+, añade la bandera `--enroll` para actualizar el checksum BLAKE2B automáticamente:
> ```bash
> sudo ./limine/setup.sh --enroll
> ```

---

## 🧪 Pruebas Automatizadas

El repositorio incluye una suite completa de pruebas no destructivas que se ejecuta en un entorno aislado y sin privilegios de root:

```bash
./tests/test_suite.sh
```

Las pruebas validan:
1. **Sintaxis de Scripts de Shell:** Validación estática (`bash -n`) para todos los scripts.
2. **Sintaxis de Bytecode Lua:** Compilación y verificación sintáctica de `ly/config.lua`.
3. **Tokens y Paleta de Ly:** Confirma `start_cmd`, `bigclock = en` y declaraciones de escape de color TTY.
4. **Integridad de Temas:** Valida los archivos de tema `mauve`, `pink` y `blue`.
5. **Idempotencia y Seguridad del Bootloader:** Simulación de 3 pasadas asegurando que entradas del kernel, initramfs y UUIDs nunca se dupliquen o corrompan.
6. **Diagnósticos CLI y Dry-Run:** Verifica que las banderas `--check`, `--dry-run` y `--help` operen limpiamente.

---

## 🔄 Restauración y Recuperación

Dado que cada ejecución crea un respaldo con fecha y hora antes de tocar cualquier archivo, restaurar un estado previo es muy sencillo:

### Restaurar Configuración de Ly
```bash
# Listar respaldos disponibles
ls -la /etc/ly/config.ini.bak_*

# Restaurar el respaldo deseado
sudo cp /etc/ly/config.ini.bak_<TIMESTAMP> /etc/ly/config.ini
```

### Restaurar Configuración de Limine
```bash
# Listar respaldos disponibles
ls -la /boot/limine*.bak_* /boot/limine/*.bak_* 2>/dev/null

# Restaurar el respaldo deseado
sudo cp /boot/limine.conf.bak_<TIMESTAMP> /boot/limine.conf
```

---

## 📄 Licencia y Reconocimientos

- **Licencia:** Distribuido bajo la [Licencia MIT](LICENSE).
- **Temas:** Paletas de color inspiradas y obtenidas del [Proyecto Catppuccin](https://github.com/catppuccin/catppuccin) y [catppuccin/limine](https://github.com/catppuccin/limine).
- **Proyectos Upstream:**
  - [Ly Display Manager](https://codeberg.org/fairyglade/ly)
  - [Limine Bootloader](https://limine-bootloader.org/)

# 🐧 Guía de Instalación Limpia de CachyOS para Dotfiles

*Leer esto en otros idiomas:* [English](cachyos-install-guide.md)

Esta guía documenta la selección de paquetes recomendada para instalar **CachyOS** en modo limpio (**CLI / No Desktop**), aplicable tanto para estaciones de trabajo de escritorio (**Desktop**) como para computadoras portátiles (**Laptop**).

El objetivo es obtener una base ultraligera, optimizada y sin paquetes redundantes o conflictivos, dejando el sistema listo para desplegar el ecosistema de dotfiles modulares (`dotfiles`, `dotfiles-mangowm`, `dotfiles-bspwm`, `dotfiles-system`).

---

## ⚙️ 1. Opciones Iniciales del Sistema

Al iniciar el instalador de CachyOS (Calamares GUI o `cachyos-cli-installer`):

| Opción | Selección Recomendada | Motivo |
| :--- | :--- | :--- |
| **Bootloader** | **Limine** (o `systemd-boot`) | Minimalista, ultrarrápido y sin capas complejas. |
| **Filesystem** | **Btrfs** (o Ext4) | Subvolúmenes optimizados y compresión transparente ZSTD. |
| **Kernel** | **`linux-cachyos`** (Default) | Rendimiento óptimo con optimizaciones de CPU y planificador BORE. |
| **Desktop Environment** | **`No Desktop` / `None` / `CLI`** | Base pura sin entornos gráficos pesados ni gestores preinstalados que colisionen con los dotfiles. |

---

## 📦 2. Lista de Paquetes Adicionales (Checklist de Instalación)

En la pantalla de selección de **"Additional Packages"** tras elegir *No Desktop*, configura las casillas de acuerdo con las siguientes listas.

### 🚫 Paquetes y Configuraciones de CachyOS (Crítico Desmarcar)
> [!WARNING]
> Desmarcar estos paquetes es indispensable. Introducen configuraciones globales en `/etc` o plantillas en `$HOME` que colisionan con la gestión modular de GNU Stow.

- [ ] `cachyos-settings` *(Crítico desactivar: inyecta configuraciones predeterminadas en `/etc`)*
- [ ] `cachyos-zsh-config` *(Crítico desactivar: colisiona con la suite Zsh de los dotfiles)*
- [ ] `cachyos-fish-config`
- [ ] `cachyos-micro-settings` *(Crítico desactivar: sobreescribe la configuración de `micro`)*
- [ ] `cachyos-hello`
- [ ] `cachyos-packageinstaller`
- [ ] `cachyos-wallpapers`

---

### 🌐 Red y Conectividad (Network)
- [x] `networkmanager` *(Esencial: gestión de red unificada para Ethernet y Wi-Fi)*
- [x] `dnsutils` *(Herramientas de diagnóstico de red como `dig` y `nslookup`)*
- [x] `ethtool` *(Diagnóstico de interfaces de red cableadas)*
- [x] `wpa_supplicant` *(Backend de Wi-Fi. **Mantener** si el equipo tiene Wi-Fi o es Laptop; opcional si es Desktop únicamente cableado)*
- [x] `wireless-regdb` *(Regulaciones de frecuencias Wi-Fi por región. **Mantener** si tienes tarjeta Wi-Fi)*
- [ ] `modemmanager` *(**Desmarcar** salvo que tu equipo cuente con ranura SIM integrada o módem USB 4G/5G)*
- [ ] `usb_modeswitch` *(**Desmarcar** salvo módems USB de banda ancha móvil)*
- [ ] `iwd` *(**Desmarcar**: puede generar conflictos con el backend predeterminado de NetworkManager)*
- [ ] `dnsmasq` *(**Desmarcar**: innecesario salvo servidores DNS locales dedicados)*
- [ ] `nss-mdns` *(Resolución de dominios locales `.local`, innecesario en la mayoría de entornos)*
- [ ] `networkmanager-openvpn` *(Opcional si utilizas conexiones OpenVPN directamente en NetworkManager)*
- [ ] `zl2tpd` *(Protocolo legacy L2TP)*

---

### 📶 Bluetooth
> [!NOTE]
> Si tu equipo es una PC de escritorio sin tarjeta ni adaptador Bluetooth, puedes desmarcar todos los paquetes de este grupo.

- [x] `bluez` *(Stack Bluetooth para auriculares, teclados, mandos y periféricos)*
- [x] `bluez-utils` *(Utilidades de terminal como `bluetoothctl`)*
- [x] `bluez-libs`
- [x] `bluez-hid2hci` *(Soporte de cambio de modo para adaptadores y dongles USB)*
- [ ] `bluez-obex` *(Servicio de transferencia de archivos por Bluetooth, habitualmente innecesario)*

---

### 🔋 Gestión de Energía (Power Management)
- [x] `power-profiles-daemon` *(Recomendado: gestor nativo de perfiles Performance / Balanced / Power-saver, integrado con Waybar y Polybar)*
- [x] `upower` *(Esencial en **Laptops**: reporta estado de carga y nivel de batería a la barra de estado. Opcional en Desktop)*
- [ ] `cpupower` *(**Desmarcar**: puede causar conflictos con `power-profiles-daemon`)*

---

### 🔊 Audio y Multimedia
- [x] `pipewire-pulse` *(Capa de emulación PulseAudio sobre PipeWire)*
- [x] `wireplumber` *(Gestor de sesiones nativo de PipeWire)*
- [x] `pipewire-alsa` *(Enrutamiento de ALSA a PipeWire)*
- [x] `alsa-utils` *(Herramientas de diagnóstico y control básico de sonido como `alsamixer`)*
- [x] `alsa-firmware` *(Firmware para placas y controladores de sonido tradicionales)*
- [x] `sof-firmware` *(Sound Open Firmware: **crítico** en laptops modernas Intel/AMD y placas base recientes para que el audio y micrófono funcionen)*
- [x] `pavucontrol` *(Mezclador de volumen gráfico rápido y liviano)*
- [x] `realtime-privileges` *(Prioridad en tiempo real para baja latencia de audio)*

---

### 🛡️ Seguridad y Cortafuegos
- [x] `ufw` *(Cortafuegos sencillo de configurar para proteger la máquina)*
- [ ] `ufw-extras`

---

### 📦 Gestión de Paquetes y Mantenimiento
- [x] `shelly` *(CLI package manager rápido oficial de CachyOS compatible con repositorios y AUR)*
- [x] `pacman-contrib` *(Incluye herramientas como `paccache` para purgar caché de paquetes)*
- [x] `pkgfile` *(Localiza a qué paquete pertenece un ejecutable no instalado)*
- [x] `rebuild-detector` *(Detecta dependencias que requieren recompilación tras actualizaciones)*
- [x] `reflector` *(Herramienta para filtrar y ordenar los mirrors más rápidos)*

---

### 🔤 Tipografías del Sistema (Fonts)
- [x] `ttf-meslo-nerd` *(Nerd Font principal empleada en las configuraciones de terminal, Starship e iconos)*
- [x] `noto-fonts` *(Tipografía universal para compatibilidad de caracteres)*
- [x] `noto-fonts-emoji` *(Compatibilidad oficial para glifos y emojis)*
- [x] `noto-fonts-cjk` *(Compatibilidad con caracteres asiáticos en navegadores y documentos)*
- [x] `ttf-dejavu` *(Fuente mono y sans estándar de reserva)*
- [x] `ttf-liberation` *(Compatibilidad métrica con fuentes comunes de documentos)*
- [ ] `awesome-terminal-fonts` *(Redundante con Nerd Fonts)*
- [ ] `cantarell-fonts` *(Específica de entornos GNOME)*
- [ ] `ttf-bitstream-vera`, `ttf-opensans`

---

### 🔌 Firmware y Diagnóstico de Hardware
- [x] `linux-firmware` *(Firmware oficial para procesadores, tarjetas gráficas y chips de red)*
- [x] `hwdetect` *(Detección de hardware nativa de CachyOS)*
- [x] `dmidecode` *(Herramienta para consultar especificaciones de hardware y BIOS/SMBIOS)*
- [x] `mesa-utils` *(Diagnóstico de controladores gráficos OpenGL y Vulkan como `glxinfo`)*
- [x] `mtools` *(Herramientas de compatibilidad FAT32 para memorias USB y particiones EFI)*
- [x] `smartmontools` *(Monitoreo del estado de salud de unidades de almacenamiento SSD y NVMe)*
- [ ] `hdparm` *(Innecesario en almacenamiento moderno SSD/NVMe; solo útil si dispones de discos mecánicos HDD)*
- [ ] `dmraid` *(Controladoras RAID antiguas)*
- [ ] `lsscsi`, `sg3_utils`

---

### 🖼️ Integración Gráfica y Miniaturas
- [x] `bash-completion` *(Autocompletado básico en Bash)*
- [x] `xdg-user-dirs` *(Generación estándar de directorios `~/Downloads`, `~/Documents`, etc.)*
- [x] `xdg-utils` *(Herramientas universales de integración como `xdg-open`)*
- [x] `ffmpegthumbnailer` *(Generación de miniaturas de vídeo para Yazi y administradores de archivos)*
- [x] `poppler-glib` *(Procesamiento y vistas previas de archivos PDF)*
- [x] `libgsf`, `libopenraw` *(Miniaturas para documentos y fotografías RAW)*
- [x] `gst-libav`, `gst-plugin-pipewire`, `gst-plugins-bad`, `gst-plugins-ugly` *(Códecs multimedia)*
- [x] `plocate` *(Indexación y búsqueda indexada ultrarrápida de archivos por terminal)*
- [x] `unzip`, `unrar` *(Soporte de descompresión de archivos)*
- [ ] `accountservice` *(Innecesario sin administradores de pantalla basados en GNOME/GDM)*
- [ ] `libdvdcss`, `vlc-plugins-all`

---

### 💻 Utilidades de Terminal y Herramientas Base
- [x] `git` *(Control de versiones indispensable para clonar y actualizar los dotfiles)*
- [x] `openssh` *(Herramientas SSH y generación de claves de acceso)*
- [x] `micro` *(Editor de texto ligero para consola predeterminado)*
- [x] `ripgrep` *(Búsqueda de texto de alto rendimiento)*
- [x] `btop` *(Monitor estético de recursos de CPU, memoria, discos y red)*
- [x] `fastfetch` *(Resumen estético de hardware y sistema en terminal)*
- [x] `wget`, `rsync` *(Herramientas de descarga y sincronización por CLI)*
- [x] `pv` *(Pipe Viewer: medidor de progreso de datos en terminal)*
- [ ] `alacritty` *(**Desmarcar**: el instalador de los dotfiles despliega y configura el emulador de terminal adecuado según el entorno elegido: `foot` para MangoWM o `alacritty` para BSPWM)*
- [ ] `nano`, `vim` *(Opcionales: el editor por defecto en los dotfiles es `micro` o `nvim`)*
- [ ] `duf`, `glances`, `hwinfo`, `meld`

---

## 🚀 3. Siguiente Paso: Despliegue de los Dotfiles

Una vez completada la instalación de CachyOS, reinicia el equipo, retira el medio de instalación e inicia sesión en la consola (TTY) con tu usuario:

```bash
# 1. Asegurar conectividad y paquetes esenciales
sudo pacman -S --needed git bash

# 2. Iniciar el asistente guiado e interactivo de dotfiles
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

El instalador interactivo te guiará paso a paso para:
1. Detectar si el equipo es Desktop o Laptop (activando automáticamente módulos de batería y brillo).
2. Seleccionar tu compositor o gestor de ventanas preferido (**MangoWM** en Wayland o **BSPWM** en X11).
3. Configurar fondos de pantalla, temas visuales y componentes del sistema.

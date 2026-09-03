# 🐧 Guía de Instalación Limpia de CachyOS (Laptop Edition)

Esta guía documenta la selección mínima y optimizada para instalar **CachyOS** en una **laptop**, maximizando la **duración de la batería**, eliminando bloatware y asegurando **cero conflictos** con el ecosistema de dotfiles modulares.

---

## ⚙️ 1. Opciones Iniciales del Sistema

Al iniciar el instalador (Calamares GUI o `cachyos-cli-installer`):

| Opción | Selección Recomendada | Motivo |
| :--- | :--- | :--- |
| **Bootloader** | **Limine** (o `systemd-boot`) | Soporte oficial, ultra ligero, rápido y sin capas pesadas. |
| **Filesystem** | **Btrfs** | Subvolúmenes optimizados y compresión transparente ZSTD. |
| **Kernel** | **`linux-cachyos`** (Default) | Rendimiento óptimo, planificador BORE y optimizaciones de CPU. |
| **Desktop Environment** | **`No Desktop` / `None` / `CLI`** | Base limpia sin entornos pesados (KDE/GNOME/SDDM) que colisionen. |

---

## 📦 2. Lista de Paquetes Adicionales (Checklist)

En la pantalla de **"Additional Packages"** tras elegir *No Desktop*, configura las casillas exactamente como se detalla a continuación:

### 🚫 CachyOS Packages
> **Evitar:** Estos paquetes configuran ajustes por defecto o scripts que reemplazan o ensucian la configuración de los dotfiles.
- [ ] `cachyos-hello`
- [ ] `cachyos-packageinstaller`
- [ ] `cachyos-settings` *(Crítico desactivar: mete configuraciones globales en `/etc`)*
- [ ] `cachyos-micro-settings` *(Crítico desactivar: colisiona con `base/home/micro`)*
- [ ] `cachyos-wallpapers`

### 🚫 CachyOS Shell Configuration
> **Evitar:** Nuestros dotfiles (`base/home/zsh`) gestionan Zsh modularmente con GNU Stow.
- [ ] `cachyos-fish-config`
- [ ] `cachyos-zsh-config` *(Crítico desactivar: colisiona con `.zshrc` y plugins)*

---

### 🌐 Base-devel / Network
- [ ] `dnsmasq` *(Innecesario salvo que crees un servidor DNS local)*
- [x] `dnsutils` *(Herramientas útiles como `dig` y `nslookup`)*
- [x] `ethtool` *(Diagnóstico de red cableada)*
- [ ] `iwd` *(Desactivar: puede causar conflictos con el backend de NetworkManager)*
- [ ] `modemmanager` *(Innecesario salvo módems 4G/5G USB)*
- [x] `networkmanager` *(Esencial para gestión de Wi-Fi y Ethernet)*
- [ ] `networkmanager-openvpn` *(Opcional si usas OpenVPN; si no, desmarcar)*
- [ ] `nss-mdns` *(Resolución mDNS de nombres `.local`, innecesario en laptops estándar)*
- [ ] `usb_modeswitch` *(Módems USB 3G/4G)*
- [x] `wpa_supplicant` *(Backend estándar de Wi-Fi para NetworkManager)*
- [x] `wireless-regdb` *(Regulaciones de frecuencias Wi-Fi de tu región)*
- [ ] `zl2tpd` *(Protocolo VPN L2TP legacy)*

### 🛡️ Firewall
- [x] `ufw` *(Firewall sencillo y recomendado para protegerte en redes Wi-Fi públicas)*
- [ ] `ufw-extras`

### 📶 Bluetooth
- [x] `bluez` *(Stack Bluetooth esencial para auriculares, ratón, etc.)*
- [x] `bluez-hid2hci` *(Soporte para cambiar dongles de modo HID a HCI)*
- [x] `bluez-libs`
- [x] `bluez-utils` *(Utilidades CLI como `bluetoothctl`)*
- [ ] `bluez-obex` *(Transferencia de archivos por Bluetooth, innecesario y consume servicio)*

### 📦 Package Management
- [x] `pacman-contrib` *(Incluye herramientas como `paccache` para limpiar caché)*
- [x] `pkgfile` *(Busca a qué paquete pertenece un comando no instalado)*
- [x] `rebuild-detector` *(Avisa si paquetes de AUR necesitan reconstrucción)*
- [x] `reflector` *(Optimiza y ordena mirrors rápidos)*
- [x] `shelly` *(CLI package manager rápido oficial de CachyOS)*

### 🖼️ Desktop Integration & Codecs
- [ ] `accountservice` *(Innecesario sin GNOME/GDM)*
- [x] `bash-completion` *(Autocompletado en Bash fallback)*
- [x] `ffmpegthumbnailer` *(Genera miniaturas de video para Yazi y Thunar)*
- [x] `gst-libav` *(Códecs GStreamer)*
- [x] `gst-plugin-pipewire` *(Integración multimedia con PipeWire)*
- [x] `gst-plugins-bad` *(Códecs adicionales)*
- [x] `gst-plugins-ugly` *(Códecs adicionales)*
- [ ] `libdvdcss` *(Desencriptado de DVDs físicos, innecesario)*
- [x] `libgsf` *(Miniaturas de documentos para el gestor de archivos)*
- [x] `libopenraw` *(Miniaturas de fotos RAW para Yazi/Thunar)*
- [x] `plocate` *(Búsqueda ultrarrápida de archivos por terminal)*
- [x] `poppler-glib` *(Miniaturas y procesamiento de PDFs para Yazi/Thunar)*
- [ ] `vlc-plugins-all` *(Innecesario: usamos `mpv`)*
- [x] `xdg-user-dirs` *(Genera carpetas estándar `~/Downloads`, `~/Documents`, etc.)*
- [x] `xdg-utils` *(Comandos estándar como `xdg-open`)*

### 💾 Filesystem
- [x] `efitools` *(Herramientas para diagnósticos de particiones EFI)*
- [ ] `nfs-utils` *(Carpetas compartidas de red NFS)*
- [ ] `nilfs-utils` *(Sistemas de archivos continuos NILFS)*
- [x] `smartmontools` *(Monitoreo del estado de salud del disco SSD/NVMe)*
- [x] `unrar` *(Extractor de archivos RAR)*
- [x] `unzip` *(Extractor de archivos ZIP)*

### 🔤 Fonts
- [ ] `awesome-terminal-fonts` *(Redundante con Nerd Fonts)*
- [x] `noto-fonts-emoji` *(Soporte oficial de emojis)*
- [ ] `cantarell-fonts` *(Fuente específica de GNOME)*
- [x] `noto-fonts` *(Fuentes universales para cualquier idioma)*
- [ ] `ttf-bitstream-vera`
- [x] `ttf-dejavu` *(Fuente mono y sans-serif de respaldo universal)*
- [x] `ttf-liberation` *(Compatibilidad métrica con fuentes de Microsoft)*
- [ ] `ttf-opensans`
- [x] `ttf-meslo-nerd` *(Nerd font esencial para terminal, iconos y Starship)*
- [x] `noto-fonts-cjk` *(Soporte para caracteres asiáticos en navegadores)*

### 🔊 Audio
- [x] `alsa-firmware` *(Firmware para tarjetas de sonido)*
- [x] `alsa-utils` *(Control de volumen por consola `alsamixer`)*
- [x] `pavucontrol` *(Controlador de volumen gráfico para PipeWire)*
- [x] `pipewire-pulse` *(Emulación PulseAudio para aplicaciones modernas)*
- [x] `wireplumber` *(Gestor de sesiones nativo de PipeWire)*
- [x] `pipewire-alsa` *(Enrutador de ALSA hacia PipeWire)*
- [x] `realtime-privileges` *(Prioridad en tiempo real para baja latencia de audio)*

### 🔌 Hardware & Firmware
- [x] `dmidecode` *(Información de hardware DMI/SMBIOS)*
- [ ] `dmraid` *(Controladoras RAID por hardware antiguas)*
- [ ] `hdparm` *(Control de discos duros mecánicos HDD)*
- [x] `hwdetect` *(Detección de hardware de CachyOS)*
- [x] `linux-firmware` *(Firmware universal para CPU, Wi-Fi y GPU)*
- [ ] `lsscsi` *(Innecesario en laptops modernas)*
- [x] `mesa-utils` *(Utilidades de gráficos OpenGL/Vulkan como `glxinfo`)*
- [x] `mtools` *(Herramientas de compatibilidad FAT32 para particiones EFI/USB)*
- [ ] `sg3_utils`
- [x] `sof-firmware` *(Sound Open Firmware: crítico para el audio de laptops modernas Intel/AMD)*

### 🔋 Power Management (Batería y Rendimiento)
- [ ] `cpupower` *(Desactivar: puede entrar en conflicto con `power-profiles-daemon`)*
- [x] `power-profiles-daemon` *(Recomendado: gestor estándar de perfiles de energía compatible con Wayland y kernels CachyOS)*
- [x] `upower` *(Esencial: provee información del nivel de batería a Waybar y scripts de sistema)*

### 💻 Applications Selection
- [ ] `alacritty` *(Desmarcar: en MangoWM/Wayland usamos la terminal nativa `foot`)*
- [x] `btop` *(Monitor de recursos del sistema moderno y estético)*
- [ ] `duf` *(Innecesario: `df -h` o btop cubren esto)*
- [ ] `fsarchiver`
- [x] `git` *(Control de versiones esencial)*
- [ ] `glances`
- [ ] `hwinfo`
- [ ] `meld` *(Visualizador gráfico de diffs, opcional)*
- [ ] `nano-syntax-highlighting`
- [x] `fastfetch` *(Información del sistema estética para terminal)*
- [x] `pv` *(Pipe Viewer: barra de progreso para pipes en terminal ej. `cat file | pv > dest`, opcional pero ligero)*
- [ ] `python-defusedxml`
- [ ] `python-packaging`
- [x] `rsync` *(Herramienta de sincronización de archivos)*
- [x] `wget` *(Descarga de archivos por CLI)*
- [x] `ripgrep` *(Búsqueda ultrarrápida de texto en archivos)*
- [x] `micro` *(Editor de texto de terminal predeterminado)*
- [ ] `nano`
- [ ] `vim`
- [x] `openssh` *(Herramientas SSH y `ssh-keygen` para claves)*

---

## 🎮 3. Gráficos Híbridos (Intel Iris Xe + NVIDIA RTX 2050)

En laptops con gráficos híbridos (Intel + NVIDIA):
1. **Escritorio en Intel (Máxima Batería):** MangoWM y todo el entorno de escritorio corren automáticamente sobre la GPU Intel integrada, consumiendo el mínimo de energía. La RTX 2050 entra en modo de reposo profundo (*D3cold*, 0W de consumo).
2. **Ejecución bajo demanda en NVIDIA (PRIME Offloading):**
   * Cuando quieras ejecutar una app pesada o juego en la RTX 2050:
     ```bash
     prime-run <comando>   # Ej: prime-run blender, prime-run steam
     ```
3. **Controladores:** CachyOS detecta la RTX 2050 e instala los módulos NVIDIA propietarios optimizados para tu kernel automáticamente mediante `chwd`.

---

## 🚀 4. Guía Post-Instalación (Recomendaciones Oficiales de la Wiki)

Una vez que reinicies el equipo, retires el USB y desbloquees el disco con tu contraseña LUKS, inicia sesión en la terminal TTY y ejecuta:

### A. Actualización del Sistema
```bash
sudo pacman -Syu
```

### B. Habilitar TRIM en Disco Cifrado (LUKS)
> ℹ️ *CachyOS ya tiene `fstrim.timer` activo por defecto, pero la capa de cifrado LUKS bloquea las órdenes TRIM salvo que habilites el paso directo (discard passthrough):*

```bash
# 1. Identificar el nombre del mapper LUKS (busca la línea de tipo 'crypt'):
lsblk

# 2. Habilitar discard passthrough persistente (sustituye <mapper_name> por el nombre encontrado ej. luks-xxxx):
sudo cryptsetup --allow-discards --persistent refresh <mapper_name>

# 3. Reiniciar el sistema para aplicar:
sudo reboot
```
*Tras reiniciar, puedes verificar con `lsblk -D` y `sudo fstrim -v /`.*

### C. Activar Firewall (UFW)
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable --now ufw
```

### D. Activar Servicios de Energía y Bluetooth
```bash
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now bluetooth
```

---

## 🥭 5. Desplegar los Dotfiles y MangoWM

```bash
# 1. Instalar paquete esencial de compilación
sudo pacman -S --needed base-devel git

# 2. Clonar y aplicar los dotfiles
mkdir -p ~/.dotfiles/{base,wm}
git clone -b refactor/modular-dotfiles https://github.com/anthonyportugal/dotfiles.git ~/.dotfiles/base
git clone https://github.com/anthonyportugal/dotfiles-mangowm.git ~/.dotfiles/wm/mangowm

# 3. Bootstrap completo para laptop
cd ~/.dotfiles/base
./bin/dotfiles bootstrap --profile=desktop --wm=mangowm --wm-feature=laptop --apply

# 4. Iniciar sesión en MangoWM
mangowm-session
```

# Manifiestos de dependencias

*Leer esto en otros idiomas:* [English](README.md)

Estos archivos declaran la intención de instalación del repositorio base. Son
datos de entrada para `bin/dotfiles`; no son scripts y no deben ejecutarse
directamente.

## Formato

- UTF-8, un nombre de paquete por línea;
- líneas vacías y líneas que empiezan con `#` se ignoran;
- no se permiten comentarios al final de una entrada;
- las entradas de paquetes y Stow se ordenan alfabéticamente;
- no se fijan versiones de paquetes de la distribución rolling release.

`package-backends.txt` es la única excepción al orden alfabético: su orden es
semántico y representa la prioridad de detección.

## Fuentes y procedencia

`repo/` contiene paquetes binarios resolubles mediante `pacman`, procedentes de
los repositorios oficiales de Arch (`core`, `extra`, `multilib`) y los mirrors
optimizados de CachyOS.

Las fuentes que no son equivalentes se mantienen separadas:

- `cachyos/`: paquetes propios del repositorio CachyOS (e.g. `brave-bin`);
- `aur/`: fallback explícito, nunca mezclado con paquetes de repositorio;
- `external/`: fuentes externas a pacman/AUR; actualmente no hay ninguna en base.

Para el navegador Brave, CachyOS usa `cachyos/desktop.txt` (paquete binario
nativo). En Arch Linux genérico, el resolver comprueba primero `core`, `extra`
y `multilib`, y sólo entonces recurre a `aur/desktop-fallback.txt`. Las dos
entradas representan alternativas del mismo paquete, no dos instalaciones
concurrentes.

## Perfiles

Los perfiles son acumulativos:

| Perfil / feature | Hereda | Paquetes del sistema | Paquetes Stow |
| --- | --- | --- | --- |
| `core` | — | `repo/core.txt` | `stow/core.txt` |
| `cli` | `core` | `repo/cli.txt` | `stow/cli.txt` |
| `desktop` | `cli` | `repo/desktop.txt` más la fuente elegida para Brave | `stow/desktop.txt` |
| `yazi-extras` | feature opt-in sobre `cli` o `desktop` | `repo/yazi-extras.txt` | ninguno |

### Detalle de perfiles

- **`core`**: Establece la base mínima e indispensable de shell y control de
  versiones. Instala Zsh, Git, GNU Stow y los cuatro complementos oficiales de
  Zsh (`zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting` y
  `zsh-history-substring-search`). Sus paquetes Stow son `git` y `zsh`.
- **`cli`**: Enriquece el entorno interactivo de terminal. Añade Starship prompt,
  Fzf, Micro, Bat, Btop, Fastfetch, Lazygit, Yazi, Git-Delta, Glow, Sad y fuentes
  de símbolos Nerd Fonts. Sus paquetes Stow despliegan las configuraciones
  Catppuccin Mocha para estas utilidades.
- **`desktop`**: Aporta utilidades gráficas independientes de la sesión o Window
  Manager. Incluye los emuladores de terminal Alacritty y Foot, visores ligeros
  (IMV, Zathura con motor MuPDF), reproductor multimedia (MPV con integración MPRIS),
  controlador de medios (Playerctl), gestor de archivos Thunar con miniaturas Tumbler,
  temas Catppuccin (Adw-gtk3-dark y Papirus-Dark) y la tipografía JetBrains Mono. Sus
  paquetes Stow enlazan las configuraciones de Alacritty, Foot y `xdg-defaults`.
- **`yazi-extras`**: Habilita previsualizaciones enriquecidas, búsqueda veloz y
  soporte de formatos en el gestor de archivos Yazi (incluyendo `7zip`, `chafa`,
  `fd`, `ffmpeg`, `imagemagick`, `jq`, `poppler`, `resvg` y `ripgrep`).

## Contratos de diseño y seguridad

- **Contrato Git público (`core`):** El paquete Stow `git` sólo configura
  parámetros portables genéricos y los includes opcionales
  `~/.config/git/private.gitconfig` y `~/.config/git/local.gitconfig`. No
  almacena nombres, emails, signing keys ni rutas laborales. Activa
  estrictamente `user.useConfigOnly = true`, y el preflight rechaza cualquier
  archivo `~/.gitconfig` legacy preexistente en `$HOME`.
- **Plugins de Zsh:** Se consumen desde las rutas estándar del sistema
  (`/usr/share/zsh/plugins/`). No se manipula el shell de login automáticamente:
  su activación permanece como una decisión explícita vía `chsh`.
- **Exclusión de desarrollo JavaScript:** No existe un perfil de Node.js, npm,
  pnpm o Bun en este repositorio base. El runtime, gestores de paquetes y reglas
  de agentes residen de forma estricta en la capa privada (`dotfiles-private`).

## Backends del bootstrap

`package-backends.txt` registra el orden de detección aprobado: Shelly (sólo en
CachyOS) → `paru` → `yay` → `pacman`. Se puede forzar uno manualmente con la opción
`--backend`.

Los adaptadores respetan las capacidades reales de cada herramienta:
- **Shelly:** Separa operaciones `install standard` e `install aur`;
- **paru / yay:** Ejecutan lotes `-S --needed` diferenciando paquetes de repo y AUR;
- **pacman:** Sólo resuelve repositorios oficiales/binarios, abortando en preflight
  si se requiere un paquete AUR sin instalar.

## Contrato con repositorios de Window Managers

Cada repositorio de WM o compositor (`dotfiles-mangowm`, `dotfiles-bspwm`) declara
autónomamente sus propias dependencias y paquetes Stow, incluso si repite un paquete
solicitado por la base. La idempotencia del gestor de paquetes de Arch resuelve
la concurrencia sin que ningún repositorio inspeccione manifiestos ajenos.

# Manifiestos de dependencias

Estos archivos declaran la intención de instalación del repositorio base. Son
datos de entrada para `bin/dotfiles`; no son scripts y no deben ejecutarse
directamente.

## Formato

- UTF-8, un nombre por línea;
- líneas vacías y líneas que empiezan con `#` se ignoran;
- no se permiten comentarios al final de una entrada;
- las entradas de paquetes y Stow se ordenan alfabéticamente;
- no se fijan versiones de paquetes de la distribución rolling release.

`package-backends.txt` es la única excepción al orden alfabético: su orden es
semántico y representa la prioridad de detección.

`repo/` contiene paquetes binarios resolubles con `pacman`. Todos fueron
comprobados primero en el portal de paquetes de CachyOS el 2026-08-20; también
pertenecen a los repositorios oficiales de Arch, por lo que conservan el mismo
nombre cuando CachyOS usa sus repos sincronizados o variantes optimizadas.

Las fuentes que no son equivalentes se mantienen separadas:

- `cachyos/`: paquetes propios del repositorio CachyOS;
- `aur/`: fallback explícito, nunca mezclado con paquetes de repositorio;
- `external/`: fuentes externas a pacman/AUR; actualmente no hay ninguna.

Para Brave, CachyOS usa `cachyos/desktop.txt`. En Arch genérico, el resolver
comprueba primero `core`, `extra` y `multilib`, y sólo entonces usa
`aur/desktop-fallback.txt`. Las dos entradas representan alternativas del mismo
paquete, no dos instalaciones.

## Perfiles

Los perfiles son acumulativos:

| Perfil/feature | Hereda | Paquetes del sistema | Paquetes Stow |
| --- | --- | --- | --- |
| `core` | — | `repo/core.txt` | `stow/core.txt` |
| `cli` | `core` | `repo/cli.txt` | `stow/cli.txt` |
| `desktop` | `cli` | `repo/desktop.txt` más la fuente elegida para Brave | `stow/desktop.txt` |
| `yazi-extras` | feature opt-in sobre `cli` o `desktop` | `repo/yazi-extras.txt` | ninguno |

`yazi-extras` habilita previews, búsqueda y navegación enriquecidas. `poppler`
aparece sólo por el preview de PDF de Yazi; el lector de escritorio continúa
siendo Zathura con MuPDF. Los proveedores de clipboard dependientes de sesión
(`wl-clipboard`, `xclip` o `xsel`) pertenecen al repositorio del WM/compositor,
no a este feature común.

No existe un perfil de desarrollo JavaScript público: Node.js, npm, pnpm, Bun
y sus integraciones pertenecen a los dotfiles privados.

## Backends del bootstrap

`package-backends.txt` registra el orden de detección aprobado. Son comandos
que el bootstrap puede utilizar, no paquetes que estos perfiles deban instalar.
La selección automática intenta Shelly sólo en CachyOS, después `paru`, `yay` y
`pacman`. Un override `--backend` permite escoger uno explícitamente.

Los adaptadores respetan sus capacidades reales:

- Shelly usa operaciones separadas `install standard` e `install aur`;
- paru y yay usan lotes `-S --needed` con `--repo` o `--aur` según procedencia;
- pacman sólo resuelve `repo/` y `cachyos/`, y rechaza un AUR faltante antes de
  modificar el sistema.

El resolver filtra primero los paquetes ya instalados con la base local de
pacman. No añade confirmación automática: la revisión y los prompts del helper
AUR permanecen visibles.

## Contrato con repositorios de WM/compositores

Cada repositorio independiente declarará sus propias dependencias y paquetes
Stow, incluso cuando repita un paquete del sistema ya solicitado por la base.
La idempotencia del package manager resuelve esa repetición sin importar
manifiestos internos de otro repositorio.

La base posee aplicaciones independientes de sesión como mpv, Playerctl,
Brave, Zathura, Micro, Yazi y Thunar. bspwm poseerá sus componentes X11; Mango
poseerá MangoWC, Waybar, launcher y utilidades específicas de Wayland. La
orquestación futura invocará el entrypoint público de cada repositorio y no
leerá ni modificará sus manifiestos internos.

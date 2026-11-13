# Dotfiles

<p align="center">
  <a href="https://github.com/anthonyportugal/dotfiles/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anthonyportugal/dotfiles/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI" alt="CI"></a>
  <a href="https://kernel.org"><img src="https://img.shields.io/badge/OS-Linux-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux"></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://cachyos.org"><img src="https://img.shields.io/badge/CachyOS-Supported-00A86B?style=flat-square" alt="CachyOS"></a>
  <a href="https://www.gnu.org/software/stow/"><img src="https://img.shields.io/badge/Manager-GNU_Stow-informational?style=flat-square" alt="GNU Stow"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Theme-Catppuccin_Mocha-cba6f7?style=flat-square&logo=catppuccin&logoColor=1e1e2e" alt="Tema"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="Licencia"></a>
</p>

*Read this in other languages:* [English](README.md)

Configuración pública, modular y portable para **Arch Linux**, en un solo repositorio. La shell, las herramientas CLI, el escritorio, los gestores de ventanas y los ajustes de sistema son capas que eliges, todas manejadas por un único comando `dotfiles`.

> [!TIP]
> 🧩 **Dentro de este repositorio:**  
> [MangoWM (Wayland)](layers/wm/mangowm/README.es.md) • [BSPWM (X11)](layers/wm/bspwm/README.es.md) • [Sistema](layers/system/README.es.md) • [Temas](themes/README.md) • externo: [Fondos de pantalla](https://github.com/anthonyportugal/walls)
>
> La instalación anterior de varios repositorios vive en la rama [`legacy`](https://github.com/anthonyportugal/dotfiles/tree/legacy); `dotfiles setup` ofrece migrarla.

---

## ✨ Características Principales

- ⚡ **Terminal y Shell de Alto Rendimiento:** Entorno Zsh veloz con prompt Starship, resaltado de sintaxis, autosugerencias y Fzf.
- 🛡️ **Privacidad Fail-Closed:** Precedencia estricta de 3 niveles (`base` ──► `private` ──► `local`) garantizando que identidades laborales, claves de firma y secretos nunca se filtren a repositorios públicos.
- 🎛️ **Orquestación Multi-WM:** MangoWM (Wayland) y BSPWM (X11) son capas que comparten un motor de temas; instala una o ambas.
- 🔄 **CLI de Ciclo de Vida Seguro:** Comandos integrados `sync`, `update` (con protección para evitar sobreescribir árboles de trabajo con cambios locales) y diagnósticos `doctor`.
- 🚀 **Despliegue en un Solo Comando:** Asistente interactivo ejecutable directamente con `curl` en instalaciones limpias.
- 🎨 **Estética Visual Unificada:** Un motor de temas (`dotfiles-theme`, ver `themes/README.md`) renderiza la paleta activa (Catppuccin Mocha por defecto, además de los temas Sanctuary compline, vespers y matins) para GTK, las terminales, Yazi y las herramientas CLI.

---

## 🧱 Arquitectura Modular

Todo vive en este repositorio salvo lo privado o pesado. Una capa se aplica junto con las capas que requiere, así que elegir un gestor de ventanas trae también el escritorio, las herramientas CLI y el núcleo.

```text
dotfiles (este repositorio)
├── bin/dotfiles, lib/    un único CLI y su motor
├── layers/
│   ├── core              Zsh y Git fail-closed
│   ├── cli               requiere core: Bat, Micro, Starship, Yazi, Lazygit, Btop, Fastfetch, Eza, Zoxide
│   ├── desktop           requiere cli: Alacritty, Foot, motor de temas, preferencias GTK
│   ├── wm/mangowm        requiere desktop: sesión Wayland (Waybar, Fuzzel, Swaylock, wlogout)
│   ├── wm/bspwm          requiere desktop: sesión X11 (Polybar, Rofi, Picom, Dunst)
│   ├── dev               opcional: herramientas de desarrollo, con features de Docker y pnpm
│   └── system            opcional, necesita sudo: Ly, Limine, DNS-over-TLS
├── themes/               paletas compartidas por todos los gestores de ventanas
└── components.conf       repositorios externos fijados a un commit (walls)

overlay privado           repositorio propio opcional, con el mismo formato de capas
```

---

## 📦 Paquetes y Perfiles

Las configuraciones están divididas en pequeños paquetes gestionados con [GNU Stow](https://www.gnu.org/software/stow/):

| Paquete | Contenido | Incluido en |
| :--- | :--- | :--- |
| **`git`** | Plantilla de configuración Git fail-closed (requiere configuración explícita de identidad) | `core`, `desktop` |
| **`zsh`** | Configuración limpia de Zsh con autosugerencias, resaltado de sintaxis y alias | `core`, `desktop` |
| **`bat`** | `bat` (`cat` con resaltado de sintaxis) con los colores del motor de temas | `cli`, `desktop` |
| **`micro`** | Editor de texto en terminal con los colores del motor de temas | `cli`, `desktop` |
| **`starship`** | Tema moderno y ligero para el prompt de la shell | `cli`, `desktop` |
| **`yazi`** | Explorador de archivos ultrarrápido en terminal con los colores del motor de temas | `cli`, `desktop` |
| **`foot`** | Emulador de terminal Wayland ligero con los colores del motor de temas | `desktop` |
| **`alacritty`** | Emulador de terminal multiplataforma con los colores del motor de temas | `desktop` |
| **`xdg-defaults`** | Ajustes GTK 3/4 `prefer-dark` y hooks de sesión | `desktop` |
| **`theme`** | `dotfiles-theme`, el único motor de temas que comparten todos los gestores de ventanas (ver [`themes/README.md`](themes/README.md)) | `desktop` |

### Capas opcionales

Algunas capas nunca forman parte de un perfil y solo se aplican si se piden con `--layer` (arrastran las capas que requieren). Sus features añaden stacks más pesados encima, y elegir una feature aplica también su capa:

| Capa / feature | Contenido |
| :--- | :--- |
| **`dev`** | Herramientas de desarrollo: Neovim con LazyVim (`nvim`, ver más abajo), `actionlint`, `direnv` (con su hook en zsh), `github-cli`, `hyperfine`, `jq`, `oha`, `shellcheck`, `shfmt`, `xh`; comprobaciones de Docker en doctor. Requiere `cli`. |
| **`dev-containers`** | Feature de `dev`: `docker`, `docker-compose`, `lazydocker` |
| **`dev-js`** | Feature de `dev`: `pnpm`, con sus binarios globales en el `PATH` |
| **`dev-go`** | Feature de `dev`: `go`, `golangci-lint`, `delve` |
| **`dev-tauri`** | Feature de `dev`: `rustup` y las bibliotecas de sistema de Tauri v2 (`webkit2gtk-4.1`, `libayatana-appindicator`, ...). `rustup` entra en conflicto con el paquete `rust`: desinstale `rust` antes (`sudo pacman -Rns rust`). Tras instalarla, ejecute una vez `rustup default stable`. |
| **`dev-herdr`** | Feature de `dev`: `herdr-bin` desde AUR (requiere un helper de AUR como Shelly, paru o yay), la TUI de herdr para supervisar varios agentes de código en una terminal. |

#### Neovim (LazyVim)

La capa `dev` enlaza `~/.config/nvim` desde [`layers/dev/home/nvim`](layers/dev/home/nvim/.config/nvim). Se construye en tres niveles:

- **[lazy.nvim](https://github.com/folke/lazy.nvim)** es el gestor de plugins. En el primer `nvim` se clona a sí mismo e instala cada plugin, y registra los commits exactos en `~/.config/nvim/lazy-lock.json` (un archivo local, fuera de este repositorio). `:Lazy` los muestra y actualiza.
- **[LazyVim](https://www.lazyvim.org)** es un conjunto de plugins sobre él: valores por defecto del editor, LSP, autocompletado, treesitter, un buscador e integración con git.
- **Los extras** añaden un lenguaje o herramienta cada uno: su servidor de lenguaje, los parsers de treesitter y el formateador/linter. [`lua/config/lazy.lua`](layers/dev/home/nvim/.config/nvim/lua/config/lazy.lua) importa TypeScript/React, Vue, Angular, Astro, Tailwind, Go, Rust, JSON, YAML, TOML, Docker, Markdown, Prettier, ESLint, el depurador y el ejecutor de tests. Un stack nuevo es un import más (por ejemplo `lang.dart` para Flutter); `:LazyExtras` los lista todos.

Los colores siguen la paleta activa: el colorscheme `dotfiles` lee la paleta que renderiza `dotfiles-theme` (capa desktop), y `dotfiles-theme set` la vuelve a aplicar en las instancias de Neovim abiertas. Sin paleta renderizada Neovim usa tokyonight.

Mason (`:Mason`) instala los servidores de lenguaje en `~/.local/share/nvim`. Los servidores de la familia TypeScript necesitan Node.js con `npm` (feature `dev-js`), y las herramientas de Go necesitan `go` (feature `dev-go`).

`~/.config/mimeapps.list` se genera, no se enlaza: las aplicaciones escriben en él, así que un enlace les dejaría modificar el checkout. La capa `desktop` mezcla
[`layers/desktop/mimeapps/defaults.list`](layers/desktop/mimeapps/defaults.list) en él en cada apply. Las claves del repo siempre ganan, y se conserva cualquier otra entrada que haya registrado una aplicación. `doctor` avisa cuando una clave del repo se desvió.

---

## 🔒 Integración con Dotfiles Privados Opcionales

El repositorio base implementa una estricta **precedencia de 3 niveles**:

```text
Configuración Base Pública  ──►  Capa Privada Opcional  ──►  Sobreescrituras Locales
     (~/.config/...)               (overlay privado)               (*.local.*)
```

1. **Identidad Git Múltiple:** `layers/core/home/git/.config/git/config` carga `~/.config/git/private.gitconfig` (si existe) para emails y claves de firma personales o laborales, seguido de `~/.config/git/local.gitconfig` específico de la máquina.
2. **Entorno de Shell:** `layers/core/home/zsh/.zshrc` carga automáticamente `~/.config/zsh/private.zsh` (si existe) para alias privados, variables de entorno y rutas laborales, seguido de `~/.config/zsh/local.zsh`.
3. **Fail-Closed e Independiente:** La ausencia de la capa privada nunca rompe la configuración pública. Ningún secreto, credencial o clave privada es rastreado en repositorios públicos.
4. **Overlay:** un repositorio privado propio puede añadir capas, con el mismo formato (`layers/<nombre>/layer.conf`, `packages/`, `home/`) y se aplica con `--overlay ~/.dotfiles-private`. Cada una de sus capas se aplica sola cuando todas las capas que `requires` están elegidas (por ejemplo `requires=core`, o `requires=dev` para aplicarse solo junto a la capa opcional `dev`); sus features funcionan como las públicas. La ruta del overlay se guarda en el recibo de selección, así que `sync` y `update` lo vuelven a aplicar y a actualizar; `--no-overlay` deja de aplicarlo. Las capas del overlay no pueden repetir el nombre de una capa pública.

---

## 🚀 Instalación y Despliegue Rápido

### 1. Instalación en un Solo Comando (Recomendado en Equipos Nuevos)

Despliega el ecosistema completo con un comando interactivo. Clona el repositorio en `~/.dotfiles` e inicia el asistente de configuración; no necesita clave SSH, clona por HTTPS:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"

# En otra ruta, p. ej. junto a tus otros repositorios:
DOTFILES_BASE_DIR=~/dev/personal/dotfiles bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonyportugal/dotfiles/main/install.sh)"
```

| Variable | Por defecto | Efecto |
| :--- | :--- | :--- |
| `DOTFILES_BASE_DIR` | `~/.dotfiles` | Dónde se clona el repositorio. Los enlaces apuntan a este checkout, así que no lo muevas. |
| `DOTFILES_REPO` / `DOTFILES_BRANCH` | este repositorio / `main` | Clona otro remoto o rama. |
| `DOTFILES_OVERLAY_DIR` | la ruta del checkout más `-private` | Dónde `setup` busca el overlay y lo clona (`~/.dotfiles-private`, o `~/dev/personal/dotfiles-private` en el ejemplo anterior). |

El asistente es un único flujo guiado corto (ver abajo): perfil, gestores de ventanas, overlay y extras, y luego el plan.

### 2. Si ya Clonaste el Repositorio

Si ya clonaste el repositorio (en cualquier ruta), ejecuta el asistente guiado desde él:

```bash
# Opción A: Abrir el asistente guiado (el idioma sigue a $LANG: es_* es español, lo demás inglés)
./bin/dotfiles setup

# Opción B: Ejecutar directamente en español
./bin/dotfiles setup --lang es

# Opción C: A través del script bootstrap
./install.sh
```

Si el target todavía tiene enlaces de otra instalación (el ecosistema anterior en `~/.dotfiles` u otro checkout del monorepo, detectada como lo hace `switch`), `setup` muestra primero lo que encontró (la instalación, su perfil, WMs, extras, overlay, los enlaces a reemplazar y lo `No migrado:`) y pregunta `migrate`, `continue` o `cancel` (el valor por defecto, también al terminar la entrada). `migrate` usa la lógica de `switch` para este checkout: muestra el plan del cambio y pregunta `apply`, `dry-run` o `cancel`; aplicar comprueba las colisiones, guarda el manifiesto y revierte si algo falla (setup termina entonces con error), y si sale bien setup termina con la selección aplicada e indica que `dotfiles switch --rollback --apply` lo deshace; el siguiente `setup` parte de ese recibo. `continue` sigue con las preguntas y no toca los enlaces anteriores. Si hay una instalación pero el switch no puede prepararse (por ejemplo sin recibo de selección, o un `--overlay` sin `layers/`), setup muestra el error del switch y qué hacer, y pregunta `continue` o `cancel` (el valor por defecto); si quedó un cambio sin cerrar ofrece además `rollback`, que muestra el plan de la reversión y pregunta `apply` o `cancel`, así que nunca hace falta `dotfiles switch --rollback --apply`. En un home nuevo o que ya usa este checkout no se muestra nada.

`setup` hace cuatro preguntas y luego muestra el plan:

1. **Perfil:** `server` (shell, Git y herramientas CLI, la capa `cli`) o `desktop` (añade la sesión gráfica).
2. **Gestores de ventanas** (solo desktop): ninguno, uno o varios de las capas de `layers/wm/`.
3. **Overlay:** un overlay con `layers/` junto al checkout (`<checkout>-private`, p. ej. `~/.dotfiles-private`; `DOTFILES_OVERLAY_DIR` lo cambia) o guardado en el recibo se ofrece con Sí por defecto; si no, pega una URL Git, que se clona ahí solo al aplicar, o pulsa Enter para omitirlo. Sin overlay, la configuración Git pública queda fail-closed hasta que configures una identidad.
4. **Extras:** ninguno viene marcado. La lista se genera al ejecutar a partir de las capas opcionales, las features declaradas en `layer.conf` y los componentes de `components.conf`, cada uno con su `description`, más las features del overlay elegido en la pregunta anterior (un overlay dado por URL se clona al aplicar, así que sus features se ofrecen en la siguiente ejecución), y solo muestra lo compatible con el perfil y los gestores elegidos. Una capa, feature o componente nuevo aparece sin tocar el asistente.

En una máquina configurada antes, cada pregunta parte de la selección guardada en el recibo: el perfil guardado es el valor por defecto, los WMs y extras guardados aparecen marcados `[x]` y el overlay guardado se ofrece con Sí. Enter conserva los marcados, `-` los vacía y cualquier otra respuesta los reemplaza, así que pulsar Enter en todas las preguntas no cambia nada. Lo que desmarques (un extra, un WM, el overlay, o `server` en lugar de `desktop`) se retira: el plan lo lista en una línea `Se retiran:` y aplicar retira sus enlaces.

Después elige `apply`, `dry-run` o `cancel` (el valor por defecto). Aplicar sigue el mismo camino que `bootstrap --apply` y luego añade los componentes elegidos. Responde con números o nombres; una respuesta vacía o el fin de la entrada toman el valor por defecto, así que el asistente también se puede guiar con entrada por tubería. Los flags como `--stow-only`, `--target` y `--lang` siguen aplicando. El mantenimiento sigue en sus propios comandos (`sync`, `update`, `doctor`, `unlink`) y la capa de sistema se aplica aparte con `dotfiles system`.

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
- **Capa opcional de desarrollo (con Docker):**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop --layer dev --feature dev-containers --apply
  ```
- **Composición con WMs y Overlay Privado:**
  ```bash
  ./bin/dotfiles bootstrap --profile desktop \
    --wm mangowm --wm bspwm \
    --overlay "$HOME/.dotfiles-private" \
    --apply
  ```
- **Componentes Externos (`add`):** Los repositorios que no son capas, como la colección de fondos [walls](https://github.com/anthonyportugal/walls), se declaran en [`components.conf`](components.conf), uno por línea: `nombre url ref [src=dst ...] [-- descripción]`, donde `ref` es el SHA completo del commit fijado, `src` una ruta dentro del componente y `dst` una ruta dentro de tu home. `add` clona el componente en `~/.local/share/dotfiles/<nombre>`, fija el commit y enlaza cada `dst` a su `src`. Un enlace simbólico existente en `dst` (como el antiguo `~/.local/share/wallpapers`) se reemplaza; un archivo o directorio real se rechaza antes de cambiar nada. El componente queda registrado en `~/.local/state/dotfiles/components.receipt`, así `sync` lo re-aplica y `update` lo mueve al commit que fije el `components.conf` descargado. `--wallpapers` y `--wallpapers-path` se retiraron en favor de este comando:
  ```bash
  ./bin/dotfiles add walls --dry-run  # solo muestra el plan
  ./bin/dotfiles add walls
  ```

### 4. Gestión del Ciclo de Vida: Comandos

- **Asistente Guiado (`setup`):** El flujo guiado corto descrito arriba, en inglés o español:
  ```bash
  ./bin/dotfiles setup            # idioma según $LANG
  ./bin/dotfiles setup --lang es  # Interfaz en español
  ```
- **Instalación por flags (`bootstrap`):** La misma instalación sin preguntas; sin `--apply` solo muestra el plan. Ver los ejemplos de la sección 3.
- **Retiro de la selección descartada:** cuando un `bootstrap`, `sync` o `setup` aplicado elige menos de lo que guardó el recibo (una capa opcional, una feature, una capa de WM, un perfil menor como `desktop` a `cli`, o el overlay cambiado o quitado con `--no-overlay`), los enlaces de lo descartado se retiran antes de enlazar la selección nueva. El plan lo nombra primero en una línea `Se retiran:`; un dry-run imprime la línea y no cambia nada. Solo se retiran enlaces hacia este checkout o hacia el overlay guardado (`stow --delete`), los archivos y enlaces ajenos no se tocan y los paquetes instalados se conservan. `--packages-only` nunca retira enlaces. Retirar y enlazar son una sola transacción: si falla cualquier paso posterior al retiro, los enlaces retirados vuelven y lo que enlazó la ejecución se quita, así que el home queda como estaba. El preflight ya cuenta los enlaces que se retiran como reemplazables, así que una capa nueva puede ocupar una ruta que enlazaba una capa retirada.
- **Autocompletado (`completion`):** `./bin/dotfiles completion zsh` (o `bash`) imprime el script de autocompletado.
- **Sincronización Local (`sync`):** Re-aplica la selección guardada en esta máquina (perfil, features, capas opcionales y capas de WM, registrada en `~/.local/state/dotfiles/dotfiles.receipt` por cada bootstrap aplicado, más los componentes añadidos con `add`), y valida paquetes sin tocar Git. La única excepción es un componente: sync lo descarga (fetch) cuando el commit fijado en `components.conf` aún no está en su checkout local (por ejemplo, tras un pull que cambió `components.conf`). Los flags explícitos como `--profile` tienen prioridad sobre lo guardado, y lo que eso descarta se retira como se describe arriba (una capa opcional que requiere `cli` mantiene `cli` elegido):
  ```bash
  ./bin/dotfiles sync
  ```
- **Actualización Remota (`update`):** Comprueba el estado de Git del repositorio público y del overlay de la selección guardada (las capas de WM y de sistema viven dentro de él en `layers/`; los componentes nunca se descargan con pull, siguen el commit fijado en `components.conf`). Aquellos con cambios sin confirmar se omiten para proteger el trabajo local; los limpios realizan `git pull --ff-only`. Si hay novedades, solicita confirmación interactiva antes de sincronizar (o usa `-y` / `--yes` para modo desatendido):
  ```bash
  ./bin/dotfiles update
  ./bin/dotfiles update -y
  ```
- **Diagnóstico del Sistema (`doctor`):** Inspecciona la integridad de enlaces, shells y dependencias de la base, auto-detecta las capas de WM activas y revisa cada componente añadido (checkout presente, en su commit fijado y con sus enlaces; ante un fallo sugiere `dotfiles add <nombre>`) para emitir un reporte compuesto:
  ```bash
  ./bin/dotfiles doctor             # Diagnóstico compuesto de componentes activos
  ./bin/dotfiles doctor --base-only # Diagnóstico aislado del repositorio base
  ./bin/dotfiles doctor --all       # Audita todos los repositorios disponibles en disco
  ```
- **Desvincular / Limpiar (`unlink`):** Retira de forma segura los enlaces simbólicos de GNU Stow y los enlaces de los componentes añadidos que apuntan a su checkout; los checkouts de los componentes se conservan en `~/.local/share/dotfiles/`:
  ```bash
  ./bin/dotfiles unlink --apply
  ```
- **Cambio del checkout activo (`switch`):** Lleva un home a otro checkout, por ejemplo desde la instalación anterior de varios repositorios en `~/.dotfiles` (base, `wm/<x>`, private, walls) a este monorepo, o entre dos checkouts del monorepo como `~/dev/personal/dotfiles` y `~/.dotfiles`. `setup` ofrece esta misma migración cuando encuentra una instalación anterior, así que el comando solo hace falta en scripts. Sin `--apply` solo muestra el plan:
  ```bash
  ./bin/dotfiles switch ~/dev/personal/dotfiles            # plan: qué migra y qué no
  ./bin/dotfiles switch ~/dev/personal/dotfiles --apply    # cambio (solo enlaces)
  ./bin/dotfiles switch --rollback --apply                 # deshace el último cambio
  ```
  La instalación actual se detecta por `~/.local/bin/dotfiles` (o `~/.dotfiles/base`; `--from RUTA` la indica). Su selección se traduce: los paquetes base enlazados fijan el perfil, `wm/<x>` pasa a la capa de WM `<x>` (su recibo conserva su perfil), la instalación private anterior pasa al overlay (`--overlay RUTA`, si no el overlay guardado, si no un checkout hermano `RUTA-private` o `dotfiles-private` junto al nuevo; el plan dice cuál) con `development` como la capa `dev` y cada componente laboral `<w>` como la feature `work-<w>` del overlay, los enlaces de walls pasan al componente `walls` (el fondo que un WM guardó desde el walls anterior, `~/.local/state/<wm>/wallpaper`, pasa al mismo archivo del componente), el tema elegido para el WM al que apunta el tema compartido pasa a `~/.local/state/dotfiles/theme/selected`, y un `mimeapps.list` enlazado al checkout anterior se conserva como archivo con todas las asociaciones que las apps escribieron a través de él. Un checkout del monorepo conserva su selección guardada. Lo que no tiene equivalente se lista como `No migrado:` (agent-harness y system tienen sus propios instaladores) y sus enlaces se conservan.

  Antes de cambiar nada, el dry-run del propio checkout nuevo comprueba las colisiones: un archivo real o un enlace que apunta a otro sitio que los checkouts reemplazados aborta el cambio sin modificar nada y lista cada ruta. Después se guarda en `~/.local/state/dotfiles/transactions/` un manifiesto de cada enlace que se reemplaza (ruta y destino anterior) y una copia del directorio de estado; solo se retiran los enlaces hacia los checkouts reemplazados y la selección se aplica con el `bootstrap` del checkout nuevo (`--stow-only` salvo `--with-packages`). Si falla cualquier paso, el target se restaura tal como estaba. `switch --rollback --apply` deshace después el último cambio: vuelven los enlaces, archivos y recibos anteriores, y los archivos que aparecieron desde entonces se apartan a `transactions/displaced-*`, nunca se borran, tampoco dentro de los directorios que creó el cambio. Un cambio interrumpido antes de escribir su manifiesto no modificó nada y se descarta con un aviso. Ningún checkout se modifica.
- **Capa de Sistema Opcional (`system`):** Aplica [`layers/system`](layers/system/README.es.md) (display manager Ly, tema de Limine, DNS-over-TLS) en `/etc` y `/boot` con `sudo` explícito. Es opcional: `bootstrap`, `sync` y `update` nunca la ejecutan, y `update` solo avisa cuando un cambio descargado la tocó. La selección aplicada se guarda en `~/.local/state/dotfiles/system.receipt`:
  ```bash
  ./bin/dotfiles system setup --ly --dns --provider quad9 --install
  ./bin/dotfiles system doctor
  ```

---

## 🌐 Repositorios Relacionados

| Repositorio | Función |
| :--- | :--- |
| **[walls](https://github.com/anthonyportugal/walls)** | Colección curada de fondos en WebP, se añade con `dotfiles add walls` (ver `components.conf`) |

`dotfiles-mangowm`, `dotfiles-bspwm` y `dotfiles-system` están archivados: pasaron a ser `layers/wm/mangowm`, `layers/wm/bspwm` y `layers/system`.

---

## 🧪 Pruebas

Ejecuta la suite de smoke tests localmente:

```bash
./tests/smoke.sh
```

---

## 👤 Autor

Diseñado y mantenido por [Anthony Portugal](https://anthonyportugal.github.io/es/).

---

## 📄 Licencia

Distribuido bajo la [Licencia MIT](LICENSE).
Las paletas de colores Catppuccin y avisos de terceros se documentan en `THIRD_PARTY_NOTICES.md`.

# Dotfiles

Configuración base pública para un entorno Arch Linux/CachyOS. Este repositorio
está migrando desde una instalación dependiente de Archcraft hacia una base
portable, modular e independiente del Window Manager o compositor elegido.

> **Estado:** migración en curso. El repositorio base ya dispone de bootstrap y
> doctor propios, y el repositorio bspwm ya fue validado como proyecto
> standalone. La integración opcional entre ambos ya está disponible; la
> validación final desde un CachyOS limpio pertenece a una fase posterior.

## Responsabilidad de este repositorio

El repositorio base será responsable de:

- shell y herramientas CLI portables;
- configuración común de aplicaciones que no pertenezcan a un WM;
- perfiles y dependencias propias;
- instalación y validación de su propio alcance;
- orquestación opcional de otros repositorios mediante contratos públicos.

No será responsable de:

- contener internamente todos los Window Managers/compositores;
- requerir configuración privada para funcionar;
- gestionar secrets, drivers de GPU o display managers;
- reproducir implícitamente los archivos que Archcraft suministraba desde
  `/etc/skel`.

## Repositorios relacionados

- [`bspwm`](https://github.com/anthonyportugal/bspwm): proyecto público X11
  independiente, con instalación standalone validada.
- `mango`: futuro proyecto público e independiente para MangoWC/Wayland.
- dotfiles privados: capa opcional e independiente para configuración personal
  o laboral no secreta. Su ausencia nunca debe romper los repositorios públicos.
- wallpapers: fuente de assets independiente y opcional; actualmente privada y
  potencialmente pública en el futuro.

La base no depende arquitectónicamente de ninguno de ellos. Puede invocar el
entrypoint público de un checkout externo, pero no lo clona, actualiza ni
conoce sus internals.

## Dirección aprobada

- GNU Stow con paquetes explícitos y detección de conflictos.
- Repositorios independientes, sin submodules como mecanismo final.
- Precedencia de configuración: pública → privada opcional → local de máquina.
- Bootstrap compatible con Shelly en CachyOS, además de `paru`, `yay` y
  `pacman` cuando sus capacidades correspondan.
- Zsh sin Oh My Zsh, integrando directamente `zsh-autosuggestions`,
  `zsh-completions`, `zsh-history-substring-search` y
  `zsh-syntax-highlighting`.

Defaults de aplicaciones ya acordados:

- Alacritty con una apariencia Catppuccin compartida entre sesiones;
- Brave como navegador;
- Zathura con MuPDF para PDF;
- Micro como editor de texto;
- Yazi y Thunar como file managers de terminal y gráfico;
- mpv con `mpv-mpris` y Playerctl para reproducción/control multimedia;
- Waybar para Mango/Wayland.

El launcher Wayland sigue pendiente entre Wofi y Fuzzel. bspwm conserva Polybar
para X11; Waybar pertenece al futuro repositorio Mango y no cubre esa sesión.

## Layout durante la migración

`home/` es el stow directory dedicado. Cada directorio inmediato representa un
paquete pequeño y refleja rutas relativas al home usando sus nombres reales:

```text
home/
├── alacritty/
├── bat/
├── starship/
├── xdg-defaults/
└── zsh/
```

Estos paquetes ya fueron migrados y validados. Los dotfiles que todavía
aparezcan fuera de `home/` son estado transitorio; la raíz completa del
repositorio nunca debe tratarse como un paquete Stow.

Los perfiles y la procedencia de paquetes están documentados en
[`packages/README.md`](packages/README.md). Son datos consumidos por el
bootstrap y no deben ejecutarse directamente.

## Organización local recomendada

Los repositorios no requieren una ubicación fija, pero los ejemplos de esta
documentación usan la siguiente estructura:

```text
~/.dotfiles/
├── base/          # repositorio público de dotfiles
└── wm/
    ├── bspwm/     # repositorio público de bspwm
    └── mangowm/   # futuro repositorio público de Mango
```

Cada directorio es un checkout Git independiente con su propio `origin` e
historial. Compartir `~/.dotfiles/` como carpeta padre no los convierte en un
monorepo, no crea submodules y no permite que la base lea los internals de los
WM. También mantiene los checkouts de WM fuera de `base/`, como exige
`--wm-path`.

## Bootstrap del repositorio base

Prepara primero la carpeta contenedora:

```bash
mkdir -p "$HOME/.dotfiles"
```

Para un checkout nuevo mediante SSH:

```bash
git clone --branch refactor/modular-dotfiles \
  git@github.com:anthonyportugal/dotfiles.git "$HOME/.dotfiles/base"
cd "$HOME/.dotfiles/base"
```

Si sólo necesitas acceso público de lectura, la clonación equivalente por
HTTPS es:

```bash
git clone --branch refactor/modular-dotfiles \
  https://github.com/anthonyportugal/dotfiles.git "$HOME/.dotfiles/base"
cd "$HOME/.dotfiles/base"
```

La rama explícita es temporal mientras esta migración no se integre en `main`;
después podrá omitirse `--branch refactor/modular-dotfiles`.

El entrypoint público es [`bin/dotfiles`](bin/dotfiles). Funciona sin bspwm,
Mango ni configuración privada. Requiere una distribución basada en Arch con
Bash y pacman; Git sólo es necesario para obtener el repositorio. Desde
`~/.dotfiles/base`, ejecuta primero el dry-run:

```bash
./bin/dotfiles bootstrap --profile desktop
```

El comando muestra plataforma, backend, paquetes instalados/faltantes, comando
de instalación previsto, paquetes Stow y colisiones. También ejecuta la
simulación nativa de Stow cuando ya está disponible. Si el plan es correcto:

```bash
./bin/dotfiles bootstrap --profile desktop --apply
./bin/dotfiles doctor --profile desktop
```

### Activar Zsh como shell de login

Instalar Zsh y sus plugins no cambia automáticamente el shell de la cuenta.
Comprueba qué shell ejecuta la terminal y cuál tiene registrado el usuario:

```bash
ps -p $$ -o comm=
getent passwd "$USER" | cut -d: -f7
```

Si todavía aparece Bash, puedes probar inmediatamente la configuración pública
reemplazando el proceso de esa terminal:

```bash
exec zsh
```

Para conservar Zsh en terminales y sesiones futuras, cambia explícitamente el
shell de login. `chsh` exige una ruta incluida literalmente en su lista, aunque
otra ruta como `/usr/sbin/zsh` apunte al mismo binario. Selecciona la primera
ruta Zsh registrada y después cierra por completo la sesión de Ly antes de
volver a entrar:

```bash
zsh_login_shell=$(chsh --list-shells | awk '/\/zsh$/ { print; exit }')
printf 'Shell elegido: %s\n' "$zsh_login_shell"
chsh -s "$zsh_login_shell"
```

En una instalación normal de Arch/CachyOS el resultado suele ser `/bin/zsh` o
`/usr/bin/zsh`. No uses una variante que no aparezca en
`chsh --list-shells`.

El bootstrap y `doctor` muestran una advertencia accionable cuando operan sobre
el home actual y detectan otro shell de login. No ejecutan `chsh` por cuenta del
usuario ni intentan cargar `.zshrc` desde Bash.

No se debe ejecutar el bootstrap completo con `sudo`: el propio backend eleva
únicamente la instalación de paquetes y Stow siempre opera como el usuario. La
aplicación vuelve a simular inmediatamente antes de enlazar, usa
`--no-folding`, nunca usa `--adopt` y se detiene ante cualquier colisión.

### Perfiles, features y backend

Los perfiles acumulativos son `core`, `cli` y `desktop`; `desktop` es el valor
predeterminado. Los extras de Yazi son opt-in:

```bash
./bin/dotfiles bootstrap --profile desktop --feature yazi-extras
./bin/dotfiles bootstrap --profile desktop --feature yazi-extras --apply
```

La selección automática intenta Shelly sólo en CachyOS, luego `paru`, `yay` y,
finalmente, `pacman`. Puede inspeccionarse otro adaptador sin cambiar el valor
predeterminado:

```bash
./bin/dotfiles bootstrap --profile desktop --backend paru
```

Shelly, paru y yay pueden resolver AUR. pacman se limita a repositorios
binarios y el preflight falla antes de modificar nada si queda un paquete AUR
por instalar. En Arch genérico, Brave sólo usa el fallback AUR después de
comprobar `core`, `extra` y `multilib`; en CachyOS se consume el manifiesto
propio de CachyOS.

### Operaciones parciales, doctor y unlink

`--packages-only` y `--stow-only` permiten aislar ambos alcances. Son útiles
para auditar el plan o cuando las dependencias se administraron manualmente:

```bash
./bin/dotfiles bootstrap --profile core --packages-only
./bin/dotfiles bootstrap --profile desktop --stow-only
./bin/dotfiles doctor --profile desktop --stow-only
```

`doctor` siempre es read-only. Comprueba paquetes, capacidad del backend,
sintaxis Zsh, el TOML de Alacritty y que cada target sea un symlink hacia la
fuente pública esperada. Cuando el target es el home actual, también informa si
la cuenta todavía inicia otro shell y por eso no cargaría los plugins.

`unlink` tampoco elimina paquetes ni archivos ajenos. Su primer pase sólo
simula; `--apply` retira los enlaces que Stow administra:

```bash
./bin/dotfiles unlink --profile desktop
./bin/dotfiles unlink --profile desktop --apply
```

La interfaz completa está disponible con `./bin/dotfiles help`.

## Integración opcional con bspwm

bspwm conserva su propio repositorio, perfiles, dependencias y ciclo de vida.
La ubicación recomendada es `~/.dotfiles/wm/bspwm`. Prepara la carpeta aunque
quieras instalar este repositorio sin la base:

```bash
mkdir -p "$HOME/.dotfiles/wm"
```

Si ya tienes una clave de GitHub configurada y piensas contribuir, clónalo
mediante SSH:

```bash
git clone --branch refactor/standalone-bspwm \
  git@github.com:anthonyportugal/bspwm.git "$HOME/.dotfiles/wm/bspwm"
```

Para obtener el mismo contenido público sin configurar una identidad SSH:

```bash
git clone --branch refactor/standalone-bspwm \
  https://github.com/anthonyportugal/bspwm.git "$HOME/.dotfiles/wm/bspwm"
```

La rama explícita es necesaria mientras el trabajo standalone no se integre en
`main`; después podrá omitirse `--branch refactor/standalone-bspwm`. La URL
elegida sólo configura el `origin` de ese checkout y no cambia la integración.

Puedes instalar bspwm por separado mediante su propio `bin/bspwm`, o componer
ambos planes desde la base. El dry-run sigue siendo el valor predeterminado:

```bash
cd "$HOME/.dotfiles/base"

./bin/dotfiles bootstrap --profile desktop \
  --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" --wm-profile desktop

./bin/dotfiles bootstrap --profile desktop \
  --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" --wm-profile desktop --apply

./bin/dotfiles doctor --profile desktop \
  --wm bspwm --wm-path "$HOME/.dotfiles/wm/bspwm" --wm-profile desktop
```

El perfil del WM es independiente del perfil base. `--packages-only`,
`--stow-only`, backend, plataforma y target se propagan a su interfaz pública.
Antes de aplicar, la base ejecuta el preflight del WM; no hace `clone`, `pull`,
`checkout`, `commit` ni `push` en ninguno de los dos repositorios.

### Límites y pasos manuales

- Actualizar el sistema antes de reconstruir el entorno sigue siendo una
  decisión explícita del usuario; el bootstrap no ejecuta un upgrade global.
- Los helpers AUR conservan sus prompts para permitir revisar PKGBUILDs; no se
  fuerza `--noconfirm`.
- Los archivos que colisionen deben revisarse, respaldarse o retirarse
  manualmente antes de volver a ejecutar el comando.
- Display manager, GPU híbrida, servicios, secretos, ciclo de vida Git de los
  repositorios de WM y capa privada quedan fuera del alcance de este bootstrap.
- La prueba final desde una instalación CachyOS no-desktop limpia pertenece a
  P10; hasta entonces, las diferencias descubiertas allí deben registrarse en
  el plan de migración.

## Plan y colaboración

La arquitectura, decisiones, fases y progreso viven en el
[plan de migración](docs/migration-plan.md). Las reglas para futuras sesiones y
colaboradores están en [AGENTS.md](AGENTS.md).

No se debe comenzar una fase porque aparezca en el roadmap: cada fase necesita
aprobación explícita. Tampoco se hacen commits sin una solicitud explícita.

## Licencia

El código y la configuración originales de este repositorio se publican bajo
la [licencia MIT](LICENSE). Los componentes vendorizados conservan sus avisos
en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

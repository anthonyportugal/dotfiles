# Dotfiles

Configuración base pública para un entorno Arch Linux/CachyOS. Este repositorio
está migrando desde una instalación dependiente de Archcraft hacia una base
portable, modular e independiente del Window Manager o compositor elegido.

> **Estado:** migración en curso. El repositorio base ya dispone de bootstrap y
> doctor propios, y el repositorio bspwm ya fue validado como proyecto
> standalone. La integración opcional entre ambos y el contrato con una capa
> privada independiente ya están cerrados. P11 dejó una candidata MangoWM
> standalone y composición opcional terminadas; P10 está activa tras una primera
> instalación funcional en VM y una ronda de regresiones encontrada allí.

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
- [`mangowm`](https://github.com/anthonyportugal/dotfiles-mangowm): proyecto
  público Wayland independiente. Su sesión, bootstrap, tema y features están
  validados de forma aislada y su primera instalación gráfica abrió P10; falta
  cerrar la revalidación de las incidencias encontradas.
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

- preferencia GTK global en modo oscuro mediante `prefer-dark`;
- Alacritty con una apariencia Catppuccin compartida entre sesiones;
- Brave como navegador;
- Zathura con MuPDF para PDF;
- Micro como editor de texto;
- Yazi y Thunar como file managers de terminal y gráfico;
- mpv con `mpv-mpris` y Playerctl para reproducción/control multimedia;
- Foot como terminal de la futura sesión MangoWM;
- Fuzzel como launcher Wayland;
- Waybar para MangoWM/Wayland.

bspwm conserva Polybar y Alacritty para X11. Foot, Fuzzel y Waybar pertenecen
al repositorio MangoWM y no cubren esa sesión.

## Layout durante la migración

`home/` es el stow directory dedicado. Cada directorio inmediato representa un
paquete pequeño y refleja rutas relativas al home usando sus nombres reales:

```text
home/
├── alacritty/
├── bat/
├── git/
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
    └── mangowm/   # repositorio público standalone de MangoWM
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
MangoWM ni configuración privada. Requiere una distribución basada en Arch con
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

El perfil `desktop` instala `glib2` y `gsettings-desktop-schemas`, y aplica de
forma idempotente `org.gnome.desktop.interface color-scheme=prefer-dark` cuando
el target es el home del usuario actual. Un target aislado no puede modificar
el `dconf` del host. Si el backend de ajustes aún no está disponible durante el
bootstrap, la sesión MangoWM vuelve a intentar el mismo entrypoint público y
`doctor` reporta cualquier preferencia pendiente.

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

## Configuración privada y local opcional

La base no necesita un repositorio privado para funcionar. Expone únicamente
puntos de inclusión estables que cada persona puede completar mediante
archivos propios o cualquier repositorio externo bajo su control:

| Área | Privado opcional | Local de máquina |
| --- | --- | --- |
| Zsh | `~/.config/zsh/private.zsh` | `~/.config/zsh/local.zsh` |
| Git | `~/.config/git/private.gitconfig` | `~/.config/git/local.gitconfig` |

La precedencia es:

```text
defaults públicos → privado opcional → local de máquina
```

Git ignora limpiamente los includes ausentes. La configuración pública define
editor, rama inicial y `user.useConfigOnly = true`; no contiene ni infiere
nombre, email, firma o ajustes de organizaciones. El modo estricto hace que un
commit sin identidad clasificada falle en vez de heredar una cuenta equivocada.
Una capa privada puede usar `includeIf` para seleccionar identidades por
checkout, por ejemplo:

```gitconfig
[includeIf "gitdir:~/dev/work/example/"]
    path = ~/.config/git/identities/example.gitconfig
```

El slash final hace que la condición cubra recursivamente los repositorios bajo
esa carpeta. Conviene evitar una identidad personal global cuando también se
usan equipos laborales: un repo sin clasificar debería fallar antes que crear
un commit con la identidad incorrecta.

No debe coexistir un `~/.gitconfig` legacy. Git carga el archivo XDG y después
`~/.gitconfig`, por lo que este último podría sobrescribir el contrato
público→privado→local. `bootstrap` y `doctor` lo detectan y se detienen para que
su migración o backup sea una decisión explícita.

OpenSSH no tiene un include público porque sus hosts e identidades pertenecen a
la capa privada o local. Una configuración privada puede administrar
`~/.ssh/config` y fragmentos no secretos, pero las private keys, credenciales,
`known_hosts`, sockets y estado del agente deben permanecer fuera de Git.
Con múltiples cuentas, cada remoto debería usar un alias SSH explícito y cada
bloque debería fijar `IdentitiesOnly yes`; los hosts canónicos ambiguos no
deberían actuar como fallback personal.

El bootstrap público no busca, clona ni ejecuta una capa privada. Si existe, se
instala por separado y consume estos contratos; si se retira, base, bspwm y los
futuros repositorios públicos continúan funcionando.

### Integrar una capa privada propia

Después de instalar la base, hay dos opciones equivalentes:

1. crear manualmente sólo los archivos opcionales necesarios; o
2. mantenerlos en un repositorio privado independiente con su propio bootstrap
   o con GNU Stow.

Un layout Stow mínimo podría ser:

```text
private-dotfiles/
└── home/
    ├── git-private/
    │   └── .config/git/private.gitconfig
    ├── ssh-private/
    │   └── .ssh/config
    └── zsh-private/
        └── .config/zsh/private.zsh
```

Y se aplicaría desde ese repositorio, no desde la base pública:

```bash
stow --dir=home --target="$HOME" --no-folding \
  git-private ssh-private zsh-private
```

Los nombres de paquetes y la herramienta del repositorio privado son libres;
el contrato estable son las rutas de la tabla anterior. Si se usa Git por
contexto, las condiciones deben cubrir raíces explícitas y cada identidad debe
vivir en un archivo independiente. Para SSH, sólo deben versionarse hosts,
opciones y registros de confianza públicos; las claves privadas —idealmente
distintas por equipo y por propósito auth/sign— se provisionan por separado.

Una comprobación breve después de integrar ambas capas es:

```bash
git config --global --show-origin --get init.defaultBranch
git config --show-origin --get user.email   # dentro de un repo clasificado
zsh -lic 'alias >/dev/null'
ssh -G nombre-del-host >/dev/null
```

El archivo local de Git se carga después del privado. En OpenSSH la precedencia
depende del orden y normalmente gana el primer valor encontrado, por lo que una
capa privada que permita overrides de máquina debe incluirlos antes de sus
defaults.

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

## Integración opcional con MangoWM

MangoWM conserva el mismo contrato independiente. Puede clonarse mediante SSH:

```bash
mkdir -p "$HOME/.dotfiles/wm"
git clone git@github.com:anthonyportugal/dotfiles-mangowm.git \
  "$HOME/.dotfiles/wm/mangowm"
```

O mediante HTTPS para una instalación pública de sólo lectura:

```bash
git clone https://github.com/anthonyportugal/dotfiles-mangowm.git \
  "$HOME/.dotfiles/wm/mangowm"
```

El dry-run compuesto no depende de los internals del checkout:

```bash
cd "$HOME/.dotfiles/base"

./bin/dotfiles bootstrap --profile desktop \
  --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
  --wm-profile desktop --wm-feature laptop

./bin/dotfiles bootstrap --profile desktop \
  --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
  --wm-profile desktop --wm-feature laptop --apply

./bin/dotfiles doctor --profile desktop \
  --wm mangowm --wm-path "$HOME/.dotfiles/wm/mangowm" \
  --wm-profile desktop --wm-feature laptop
```

`--wm-feature laptop|recording` es exclusivo de MangoWM y se puede repetir. Las
features de la base continúan usando `--feature`, por lo que ambos espacios de
nombres nunca se mezclan. El entrypoint de sesión resultante es
`~/.local/bin/mangowm-session`; conectarlo a TTY o display manager se validará
en P10, no lo modifica este bootstrap.

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
  P10 y se ejecutará después de preparar MangoWM en P11; hasta entonces, las
  diferencias descubiertas deben registrarse en el plan de migración.

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

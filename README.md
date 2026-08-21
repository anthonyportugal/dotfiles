# Dotfiles

Configuración base pública para un entorno Arch Linux/CachyOS. Este repositorio
está migrando desde una instalación dependiente de Archcraft hacia una base
portable, modular e independiente del Window Manager o compositor elegido.

> **Estado:** migración en curso. El repositorio base ya dispone de bootstrap y
> doctor propios; la autonomía de bspwm, la integración opcional y la validación
> final desde un CachyOS limpio pertenecen a fases posteriores.

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
  independiente. El submodule que aún aparece en este checkout es transitorio y
  será retirado después de validar su instalación standalone.
- `mango`: futuro proyecto público e independiente para MangoWC/Wayland.
- dotfiles privados: capa opcional e independiente para configuración personal
  o laboral no secreta. Su ausencia nunca debe romper los repositorios públicos.
- wallpapers: fuente de assets independiente y opcional; actualmente privada y
  potencialmente pública en el futuro.

La base no depende arquitectónicamente de ninguno de ellos. Más adelante podrá
facilitar su clonación o invocar sus instaladores sin conocer sus internals.

## Dirección aprobada

- GNU Stow con paquetes explícitos y detección de conflictos.
- Repositorios independientes, sin submodules como mecanismo final.
- Precedencia de configuración: pública → privada opcional → local de máquina.
- Bootstrap compatible con Shelly en CachyOS, además de `paru`, `yay` y
  `pacman` cuando sus capacidades correspondan.
- Zsh sin Oh My Zsh, conservando `zsh-syntax-highlighting` y
  `zsh-autosuggestions`.

Defaults de aplicaciones ya acordados:

- Brave como navegador;
- Zathura con MuPDF para PDF;
- Micro como editor de texto;
- Yazi y Thunar como file managers de terminal y gráfico;
- mpv con `mpv-mpris` y Playerctl para reproducción/control multimedia;
- Waybar para Mango/Wayland.

El launcher Wayland sigue pendiente entre Wofi y Fuzzel. La barra X11 de bspwm
se decidirá separadamente porque Waybar no cubre esa sesión.

## Layout durante la migración

`home/` es el stow directory dedicado. Cada directorio inmediato representa un
paquete pequeño y refleja rutas relativas al home usando sus nombres reales:

```text
home/
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

## Bootstrap del repositorio base

El entrypoint público es [`bin/dotfiles`](bin/dotfiles). Funciona sin bspwm,
Mango ni configuración privada. Requiere una distribución basada en Arch con
Bash y pacman; Git sólo es necesario para obtener el repositorio. El dry-run es
el comportamiento predeterminado:

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
sintaxis Zsh y que cada target sea un symlink hacia la fuente pública esperada.

`unlink` tampoco elimina paquetes ni archivos ajenos. Su primer pase sólo
simula; `--apply` retira los enlaces que Stow administra:

```bash
./bin/dotfiles unlink --profile desktop
./bin/dotfiles unlink --profile desktop --apply
```

La interfaz completa está disponible con `./bin/dotfiles help`.

### Límites y pasos manuales

- Actualizar el sistema antes de reconstruir el entorno sigue siendo una
  decisión explícita del usuario; el bootstrap no ejecuta un upgrade global.
- Los helpers AUR conservan sus prompts para permitir revisar PKGBUILDs; no se
  fuerza `--noconfirm`.
- Los archivos que colisionen deben revisarse, respaldarse o retirarse
  manualmente antes de volver a ejecutar el comando.
- Display manager, GPU híbrida, servicios, secretos, repositorios de WM y capa
  privada quedan fuera del alcance de este bootstrap.
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

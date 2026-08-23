# Plan de arquitectura y migración de dotfiles

> Estado: activo
>
> Última actualización: 2026-08-23
>
> Fase activa: ninguna — P8 completada el 2026-08-23
>
> Siguientes fases autorizadas: ninguna

## 1. Propósito de este documento

Este documento es la fuente de verdad para reconstruir los dotfiles de forma
incremental. Conserva las decisiones arquitectónicas, el estado de la
migración y el siguiente paso autorizado sin depender del historial de una
conversación.

El plan orienta el trabajo, pero no autoriza por sí mismo a ejecutar todas las
fases. Cada fase requiere aprobación explícita. Al terminar una fase se debe
validar, revisar el diff, actualizar el progreso y detenerse antes de comenzar
la siguiente, salvo que una instrucción explícita reciente autorice varias
fases concretas.

Si durante la implementación aparece una razón para apartarse de una decisión
aprobada:

1. registrar la discrepancia;
2. explicar su causa e impacto;
3. proponer el cambio al plan;
4. esperar aprobación;
5. actualizar este documento;
6. continuar con la implementación alineada.

Las instrucciones explícitas más recientes tienen prioridad sobre este plan,
pero la contradicción debe hacerse visible y reconciliarse aquí.

## 2. Estado inicial relevante

### Repositorio base

- Repositorio público existente: `dotfiles`.
- Baseline auditado: commit `6770d42`.
- Rama local de trabajo: `refactor/modular-dotfiles`.
- `main` y `origin/main` también apuntaban a `6770d42` al comenzar la
  migración.
- El árbol contiene dotfiles directamente en la raíz, por ejemplo `.zshrc`,
  `.xprofile` y `.config/*`; todavía no existe una separación explícita por
  paquetes Stow.
- El README describe una instalación sobre Archcraft, usa `yay` directamente
  y no representa una instalación reproducible desde CachyOS sin escritorio.
- No hay bootstrap, manifiestos completos de paquetes, pruebas, CI, documento
  operativo para agentes ni mecanismo persistente de seguimiento previo a P0.
- La mayor parte del tamaño versionado corresponde a temas Catppuccin para Bat
  y Geany.

### Shell y sesión

- `.zshrc` mezcla framework, plugins, aliases, variables de entorno,
  inicialización de herramientas, lógica de Pacman y carga privada.
- Oh My Zsh se carga aunque la configuración útil no depende de una colección
  amplia de plugins.
- `zsh-syntax-highlighting` y `zsh-autosuggestions` son requisitos explícitos.
- La carga privada actual ocurre antes de varias asignaciones públicas, por lo
  que no ofrece una precedencia de overrides consistente.
- `.xprofile` contiene lógica X11 y nombres de salidas detectados con `xrandr`;
  no es una configuración base portable ni aplicable a Wayland.
- `mimeapps.list` referencia aplicaciones antiguas o aún no confirmadas. Su
  limpieza no es prioritaria y se hará junto con la selección real de apps.

### Repositorios relacionados

- `bspwm` es un repositorio público existente e independiente.
- El repositorio base todavía lo registra como gitlink en `.config/bspwm`,
  fijado al commit público `4062ad0`.
- Ese baseline de bspwm depende de archivos, scripts, fuentes, iconos y
  convenciones suministradas implícitamente por Archcraft. También contiene
  supuestos de hardware concretos.
- `.gitmodules` conserva además entradas para wallpapers y fonts que no son
  gitlinks versionados y cuyas URLs públicas auditadas no estaban disponibles.
- `mango` será un futuro repositorio público independiente.
- Existe un repositorio privado de wallpapers que podría hacerse público más
  adelante.

### Limpieza previa de referencias locales

La migración temporal basada en Archcraft fue revertida. Con autorización
explícita se eliminaron únicamente referencias locales obsoletas:

- rama `legacy/archcraft-based-dotfiles` del repositorio base;
- tag `archive/archcraft-current` del repositorio base;
- rama `legacy/archcraft-current` del repositorio bspwm;
- la rama activa se renombró de `refactor/dotfiles-v2` a
  `refactor/modular-dotfiles`.

No se cambiaron remotes ni commits durante esa limpieza.

### Plataforma objetivo

- Instalación desde CachyOS sin entorno de escritorio preconfigurado.
- Uso en un PC y una laptop con CPU/gráficos Intel y GPU NVIDIA.
- CachyOS y sus herramientas del sistema son responsables de drivers y del
  modo híbrido de GPU.
- El display manager queda fuera del alcance inicial. Se conserva el provisto
  por la instalación; actualmente es Ly.

## 3. Objetivos

1. Convertir el repositorio base en dotfiles públicos, portables y útiles sin
   depender de un WM/compositor concreto.
2. Mantener bspwm y Mango como proyectos públicos independientes, instalables y
   comprensibles por separado.
3. Permitir una capa privada opcional sin modificar archivos públicos cada vez
   que cambie información personal o laboral.
4. Poder reconstruir gradualmente el entorno desde CachyOS sin escritorio.
5. Declarar dependencias y validar capacidades en lugar de depender de lo que
   Archcraft copiaba implícitamente desde `/etc/skel`.
6. Mantener ownership exclusivo y comprensible para cada ruta configurada.
7. Proveer bootstrap inspeccionable, idempotente y con modo de simulación.
8. Evitar que datos privados o secretos terminen en repositorios públicos.
9. Conservar durante la migración el comportamiento útil de bspwm antes de
   simplificarlo o rediseñarlo.

## 4. Non-goals

- Crear un monorepo con toda la configuración.
- Hacer que el repositorio base requiera bspwm, Mango o la capa privada.
- Replicar Archcraft completo o instalar paquetes `*-settings` para recuperar
  configuración oculta.
- Fijar en esta etapa display manager, stack final de Mango, launcher, visor de
  imágenes o todos los MIME handlers.
- Gestionar drivers Intel/NVIDIA desde los dotfiles.
- Guardar passwords, tokens, private keys o credenciales en Git, aunque el
  repositorio sea privado.
- Prometer una reproducción binaria exacta de Arch Linux/CachyOS rolling
  mediante pinning indiscriminado de versiones.
- Construir un sistema complejo de project management dentro del repositorio.

## 5. Principios arquitectónicos

- `clarity > cleverness`
- `explicit > magical`
- `simple > over-engineered`
- Repositorios autónomos, composición opcional.
- Ownership exclusivo de rutas; dependencias duplicadas pueden declararse,
  pero dos repositorios no deben administrar el mismo archivo.
- Defaults públicos útiles, overrides privados opcionales y overrides locales
  de máquina al final.
- El código fuente no se modifica para cambiar de tema o generar estado de
  ejecución.
- La ausencia de repositorios opcionales nunca rompe una instalación pública.
- Detectar capacidades es preferible a codificar nombres de monitores,
  interfaces, baterías, backlights o GPUs.
- Toda automatización debe poder explicar qué cambiará antes de cambiarlo.
- Los errores y conflictos deben detener la operación con un mensaje accionable.
- La mantenibilidad y experiencia de uso se equilibran con el rendimiento.

## 6. Decisiones aprobadas

### D1 — GNU Stow como mecanismo principal

Se usará GNU Stow con un stow directory dedicado, paquetes pequeños y
`--no-folding` para mantener rutas explícitas. Cada repositorio podrá tener su
propio stow directory y marcador `.stow`. Antes de aplicar cambios se usará
simulación y detección de conflictos. El bootstrap nunca ejecutará `--adopt`
automáticamente.

Chezmoi no se adopta en esta migración: sus plantillas, estado fuente único y
mecanismos de composición añaden complejidad que no aporta una ventaja clara
para varios repositorios públicos autónomos. Puede reevaluarse si aparece una
necesidad concreta que Stow más includes explícitos no resuelva.

### D2 — Repositorios independientes, sin submodules

`dotfiles`, `bspwm`, `mango` y una eventual capa privada se mantendrán como
repositorios independientes. Los submodules actuales son estado transitorio y
se retirarán en una fase específica, no durante la fundación de Stow.

### D3 — Base autónoma con orquestación opcional

El repositorio base no dependerá de ningún WM/compositor. Podrá ofrecer un
punto de entrada opcional que clone o invoque repositorios seleccionados, pero
esa integración utilizará interfaces públicas y no conocimiento de sus
detalles internos.

### D4 — Capa privada independiente y opcional

La configuración privada vivirá fuera de los repositorios públicos, idealmente
en un segundo repositorio Git privado. Los repositorios públicos expondrán
puntos de inclusión estables y condicionales; nunca conocerán la URL privada ni
fallarán si los archivos no existen.

### D5 — Migración conservadora de bspwm

Primero se inventariará y conservará el comportamiento útil actual de bspwm.
Después de eliminar sus dependencias implícitas de Archcraft podrán proponerse
simplificaciones en pasos pequeños.

### D6 — Zsh sin Oh My Zsh

Oh My Zsh se eliminará. `zsh-autosuggestions`, `zsh-completions`,
`zsh-history-substring-search` y `zsh-syntax-highlighting` se integrarán
directamente desde paquetes del sistema, con comprobaciones claras. La
configuración se dividirá por responsabilidad y la mayoría de aliases
personales pasará a la capa privada. El repositorio público conservará sólo
aliases pequeños, genéricos y ampliamente reutilizables.

### D7 — Apps y MIME se migran por uso real

No se conservará `mimeapps.list` por inercia. Se limpiará de manera incremental
cuando estén confirmados los programas y sus desktop entries. No se dedicará
una fase temprana a decidir asociaciones que aún no importan.

### D8 — Display manager fuera del alcance inicial

El bootstrap no instalará ni reemplazará el display manager. Se respetará el
que decida la instalación de CachyOS; actualmente Ly. Una selección distinta
se tratará más adelante como decisión del sistema, no como dependencia oculta
del WM.

### D9 — GPU gestionada por CachyOS

Los dotfiles no instalarán ni configurarán globalmente drivers o modos híbridos
Intel/NVIDIA. Se seguirá el mecanismo vigente de CachyOS y se validarán las
capacidades necesarias. Podrá ofrecerse un uso opt-in de offload por aplicación,
pero no se añadirán variables NVIDIA globales ni nombres de GPU codificados.

### D10 — Mango se diseña después

El stack de Mango se decidirá en P11. La configuración de MangoWC de Archcraft
es una referencia funcional, no una plantilla que deba copiarse completa. Cada
componente se aceptará por una necesidad explícita y no se heredarán scripts
que muten el repositorio fuente.

### D11 — Wallpapers como fuente de assets independiente

Los wallpapers no serán un submodule obligatorio. Su repositorio seguirá
independiente, inicialmente privado y quizá público después. La integración
será opcional y no impedirá instalar los dotfiles o un WM sin esos assets.

### D12 — Secretos separados de dotfiles privados

La estrategia concreta se evaluará cuando sea necesaria. Hasta entonces,
passwords, tokens, private keys y credenciales quedan fuera de cualquier
repositorio Git. Un repositorio privado no se considera un secret manager.

### D13 — Backends de paquetes soportados por el bootstrap

El bootstrap soportará Shelly, disponible por defecto en CachyOS, además de
`paru` y `yay`. La selección automática recomendada será:

1. Shelly en CachyOS cuando esté disponible;
2. `paru`;
3. `yay`;
4. `pacman` como fallback sólo para paquetes de repositorios oficiales.

Existirá un override explícito para escoger backend. Los manifiestos distinguirán
repositorios oficiales, AUR y otras fuentes; el código no asumirá que todos los
backends tienen exactamente las mismas capacidades. P6 fijó los adaptadores:
Shelly separa `install standard`/`install aur`, paru y yay usan `-S --needed`
con `--repo`/`--aur`, y pacman queda limitado a paquetes binarios de
repositorio.

### D14 — Selección inicial de aplicaciones

- Navegador: Brave.
- Lector PDF: Zathura con el backend MuPDF.
- Editor de texto: Micro.
- File managers: Yazi para terminal y Thunar para entorno gráfico.
- Reproducción multimedia: mpv con `mpv-mpris` y Playerctl para control MPRIS.
- Barra Wayland: Waybar, propiedad del futuro repositorio Mango.
- Launcher Wayland: decisión pendiente entre Wofi y Fuzzel.

Waybar no cubre la sesión X11 de bspwm. La barra de bspwm se preservará o
decidirá separadamente durante P7.

### D15 — Layout Stow del repositorio base

El stow directory del repositorio base es `home/` y está marcado por
`home/.stow`. Cada hijo inmediato es un paquete pequeño que refleja literalmente
la ruta relativa a `$HOME`, incluidos los nombres que comienzan con punto:

```text
home/<paquete>/<ruta-relativa-al-home>
```

Los paquetes se nombran en minúsculas y por una única aplicación o
responsabilidad; no por una máquina concreta. Los paquetes Stow y los perfiles
de instalación son conceptos distintos: en P5 un perfil podrá seleccionar
varios paquetes sin convertirlos en un único paquete grande.

Las invocaciones usarán `--dir` y `--target` explícitos junto con
`--no-folding`. No se crea `.stowrc`, para evitar defaults implícitos o
dependientes de una ubicación local. El primer paquete es `bat`; el resto del
árbol en la raíz sigue siendo transitorio hasta su fase correspondiente.

### D16 — Toolchain JavaScript exclusivamente privada

Node.js, npm, pnpm y Bun, junto con sus aliases, completions, variables y rutas,
pertenecen a la capa privada. El repositorio público no los declara como
dependencias ni modifica el entorno para ellos, y debe funcionar cuando no
estén instalados.

### D17 — Prioridad de fuentes de paquetes

La investigación y resolución de paquetes seguirá este orden:

1. repositorios disponibles para CachyOS;
2. repositorios oficiales de Arch Linux;
3. AUR, sólo cuando el paquete no esté disponible en los anteriores.

Los manifiestos separarán procedencia y fallback. No fijarán versiones móviles
de una distribución rolling release salvo que aparezca una razón reproducible
concreta.

### D18 — Perfiles acumulativos y manifests autónomos

El repositorio base tendrá perfiles acumulativos `core` → `cli` → `desktop` y
un feature opt-in `yazi-extras`. Los paquetes de repositorio, específicos de
CachyOS, fallback AUR, externos y paquetes Stow se declaran en archivos
separados de texto plano.

Los repositorios bspwm y Mango declararán autónomamente sus dependencias,
aunque repitan nombres ya presentes en la base. La orquestación no importará
sus manifests internos: invocará sus entrypoints públicos y dejará que el
package manager deduplique instalaciones.

### D19 — Contrato del entrypoint del repositorio base

El entrypoint público es `bin/dotfiles` y expone tres operaciones:

- `bootstrap`: resuelve paquetes y enlaces;
- `doctor`: valida en modo estrictamente read-only;
- `unlink`: retira sólo enlaces Stow, nunca paquetes ni archivos ajenos.

`bootstrap` y `unlink` son dry-run por defecto y requieren `--apply` para
modificar estado. Los tres comparten perfiles, features y target; bootstrap y
doctor permiten aislar paquetes o Stow con `--packages-only` y `--stow-only`.
Backend y plataforma tienen detección automática y override explícito.

Este contrato cubría inicialmente sólo el repositorio base. D26 lo extendió en
P8 con orquestación opt-in mediante entrypoints públicos, una vez validada la
autonomía de bspwm; no añadió clonación ni lectura de internals.

### D20 — Polybar se conserva inicialmente en bspwm

P7 mantendrá Polybar como barra X11 para conservar el comportamiento y la
apariencia aceptados antes de proponer rediseños. La configuración será estática
y propiedad del repositorio bspwm: no reescribirá archivos versionados para
detectar hardware o aplicar temas. Monitores y redes se resolverán por
capacidades; batería y backlight sólo se habilitarán cuando existan. Los módulos
multimedia heredados de MPD/Spotify se sustituirán por integración genérica con
Playerctl.

### D21 — Ajustes de bspwm derivados de la primera VM

La primera instalación standalone inició correctamente tras añadir
`xorg-xauth`, usar Picom con backend `xrender` y definir explícitamente al menos
un módulo derecho de Polybar. P7 incorporará `xorg-xauth` como dependencia de
sesión. Picom conservará `glx` como default para hardware real y documentará
`xrender` como override local de VM.

Polybar mantendrá la detección por capacidades aprobada en D20, pero su launcher
comprobará que cada instancia permanezca activa y reintentará con un conjunto
mínimo seguro cuando la selección automática falle. El tray sólo se asignará a
una barra por sesión. La selección explícita mediante
`BSPWM_POLYBAR_RIGHT` seguirá teniendo precedencia y no será sustituida
silenciosamente.

La pulsación aislada de Super se recuperará con `xcape`, disponible como paquete
binario, en lugar de restaurar la dependencia Archcraft `ksuperkey`. El power
menu de Rofi recuperará su disposición visual en cuadrícula e iconos mediante la
Nerd Font ya declarada, sin depender de la fuente Feather de Archcraft.

### D22 — Pulido post-VM y alcance del layout X11

La validación visual posterior a P7 mostró espaciado inconsistente entre
módulos de Polybar y alineación óptica mejorable en los glifos del power menu.
El ajuste conservará el tema Catppuccin y la configuración estática, pero
retirará separadores decorativos redundantes, normalizará el espacio interno de
iconos/texto y centrará explícitamente los elementos de Rofi. El aspecto del
repositorio `tsjazil/dotfiles` se usa sólo como referencia visual; no se copian
su configuración, sus hardcodes ni sus dependencias.

La sesión bspwm ofrecerá por defecto los layouts XKB `us,latam` con
`Alt+Space` como selector de grupo. Esta responsabilidad queda limitada a la
sesión X11 y tendrá overrides locales y un interruptor para desactivarla; la
configuración global del teclado, modelos físicos y políticas del sistema
continúan fuera del ownership del repositorio. `xorg-setxkbmap` se declarará
como dependencia consumida por bspwm.

Picom adoptará un radio moderado usando la capacidad del paquete oficial ya
declarado, sin cambiar backend ni añadir forks. Zathura no se incorpora a
bspwm: su configuración portable será un paquete independiente del repositorio
base en un paso posterior, para que sea compartida por X11 y Wayland sin doble
ownership.

### D23 — Traducción visual de la referencia y ownership de Alacritty

La referencia `tsjazil/dotfiles` orientará el lenguaje visual de P7, no su
implementación. Polybar adoptará una geometría flotante, la paleta Catppuccin
usada por esa referencia y un workspace activo representado por un bloque de
color, sin copiar scripts, hardcodes de monitor/hardware ni dependencias AUR
antiguas. La composición predeterminada será launcher y workspaces a la
izquierda; fecha y hora al centro; y volumen, RAM usada, almacenamiento raíz
usado, red detectada, batería opcional, layout XKB y tray opcional a la derecha.
El botón de apagado se retira de la barra, pero el power menu continúa accesible
mediante `Super+X`.

El borde de foco de bspwm pasa a ancho cero por defecto porque su geometría
rectangular entra en conflicto visual con las esquinas redondeadas. Picom
indicará el foco atenuando de forma leve las ventanas inactivas. El ancho y los
colores del borde siguen disponibles como overrides locales para quien prefiera
el indicador tradicional.

Alacritty es una aplicación compartida entre sesiones y, por tanto, su
configuración Catppuccin pertenece al repositorio base, no al repositorio
bspwm. bspwm sólo declara y ejecuta el terminal, de modo que permanece
standalone y acepta cualquier configuración de Alacritty del usuario. El perfil
`desktop` del repo base añadirá el paquete Stow de Alacritty y su dependencia.
La configuración de Zathura continúa pospuesta al paso común ya acordado en
D22; no se duplica dentro de P7.

### D24 — Completions e historial interactivo de Zsh

Como mantenimiento explícitamente solicitado sobre P3/P5, el perfil `core`
añadirá los paquetes binarios `zsh-completions` y
`zsh-history-substring-search`, disponibles en `extra` de CachyOS/Arch. El
primero instala definiciones bajo `/usr/share/zsh/site-functions`, ruta que Zsh
ya incluye en `fpath`; el `compinit` público existente las descubrirá sin un
segundo inicializador ni framework.

El buscador substring se cargará desde la ruta suministrada por el paquete,
después de `zsh-syntax-highlighting` como exige su integración upstream. Las
flechas arriba/abajo se enlazarán tanto mediante `terminfo` como mediante las
secuencias ANSI habituales. La carga seguirá siendo condicional para que la
configuración degrade limpiamente si se usa `--stow-only` antes de instalar
paquetes. La colección general de completions puede contener definiciones para
comandos ausentes, pero no instala ni inicializa Node.js, npm, pnpm o Bun y no
modifica D16.

Este seguimiento no cambia la fase activa: P7 continúa esperando validación
visual en VM, y P8 permanece sin autorización.

La implementación D24 añadió ambos nombres al manifest `core`, documentó cómo
`compinit` descubre `zsh-completions` y actualizó el orden/bindings del archivo
de plugins. Se validaron sintaxis Zsh, orden del manifest, Bash, ShellCheck, el
smoke test completo del bootstrap y una sesión interactiva aislada usando los
paquetes oficiales reales, incluida la resolución de flechas normal y
`terminfo` con `TERM=alacritty`.

La comprobación posterior en VM mostró una diferencia entre instalar Zsh y
activarlo: la terminal seguía ejecutando Bash como shell de login, por lo que
ningún `.zshrc` podía cargar los plugins aunque sus paquetes y rutas fueran
correctos. El bootstrap no ejecutará `chsh` automáticamente, porque cambiar el
shell de una cuenta es una decisión explícita del usuario y requiere cerrar la
sesión para aplicarse. En su lugar, bootstrap y doctor avisarán cuando operen
sobre el home actual y detecten otro shell de login; README documentará tanto
la prueba inmediata con `zsh` como el cambio persistente con `chsh`.

El seguimiento se validó con las versiones actuales de los paquetes de Arch:
autosuggestions y syntax-highlighting desde sus rutas instaladas, completions
0.36.0 bajo el `fpath` del sistema e history-substring-search 1.1.0 después del
highlighter. Los cuatro registraron sus funciones/widgets en una sesión Zsh
aislada. El smoke test permanente simula ahora un home correctamente enlazado
con `/bin/bash` como shell de login y exige que doctor explique el diagnóstico
sin ejecutar `chsh` ni modificar la cuenta.

Un segundo seguimiento de la VM precisó dos detalles de portabilidad. Primero,
`command -v zsh` puede devolver un hardlink como `/usr/sbin/zsh` que ejecuta el
mismo binario pero no aparece literalmente en `/etc/shells`; `chsh` rechaza esa
ruta para un usuario no privilegiado. La recomendación y el diagnóstico deben
seleccionar una ruta ejecutable de Zsh anunciada por `chsh --list-shells`, con
fallback de lectura a `/etc/shells`, y nunca inferir que cualquier resultado de
`command -v` es aceptable como shell de login.

Segundo, GNU `ls` no colorea por defecto aunque `LS_COLORS` esté definido. Los
cuatro aliases públicos añadirán `--color=auto`, que emite colores sólo cuando
la salida es una terminal y mantiene limpias redirecciones y pipes. No se añade
un framework ni se duplica la paleta del sistema: GNU `ls` conserva sus defaults
o la personalización existente de `LS_COLORS`.

La implementación selecciona primero una ruta ejecutable terminada en `zsh`
desde `chsh --list-shells` y sólo recurre a `/etc/shells` si esa consulta no
está disponible. README dejó de recomendar `command -v` para `chsh`. El smoke
test usa un `chsh` falso que anuncia `/bin/zsh` y `/usr/bin/zsh`, exige que el
diagnóstico elija la primera ruta registrada y rechaza cualquier invocación que
intente cambiar realmente la cuenta. La misma prueba carga los cuatro aliases
en Zsh y comprueba que todos conserven `--color=auto`.

### D25 — Polybar anclada, foco legible y tray nativo

La revisión visual en VM sustituye la geometría flotante descrita en D23:
Polybar ocupará todo el ancho del monitor, sin offsets exteriores, borde ni
radio en el contenedor principal. Esta decisión sólo cambia la presentación;
se conservan la composición, la detección por capacidades y el ownership
standalone ya aprobados.

El acento común será Catppuccin Pink (`#F5C2E7`), igual que el estado
seleccionado de Rofi. El workspace activo usará ese acento y el tray se
mantendrá en el bloque central, inmediatamente después de fecha/hora, sólo en
la primera barra de una sesión multimonitor.

La primera implementación intentó aproximar elementos redondeados mediante
indicadores numéricos circulares y separadores de Powerline. La prueba real
mostró dos límites: los workspaces de esta sesión se nombran con glifos de
aplicación, por lo que el fallback circular ocultaba su identidad, y las
ventanas XEmbed del tray no comparten necesariamente el fondo decorativo del
módulo. El resultado final conserva `%name%` como icono del workspace y marca
el foco coloreando ese icono en Pink, sin fondo artificial. El tray usa el
renderizado nativo de Polybar con tamaño y separación controlados, pero hereda
el fondo de la barra y no añade tapas ni cápsula. Se priorizan así legibilidad y
consistencia sobre una aproximación incompleta al radio, que Polybar no ofrece
por label o módulo individual. D25 prevalece sobre la geometría flotante y la
ubicación derecha del tray descritas en D23.

### D26 — Orquestación explícita de checkouts independientes

O9 se resuelve extendiendo `bootstrap`, `doctor` y `unlink` con integración
opt-in mediante `--wm bspwm`, `--wm-path DIR` y un perfil independiente
`--wm-profile core|desktop`. Sin `--wm`, el comportamiento del repositorio base
no cambia. La ruta será obligatoria, deberá apuntar a un checkout externo al
repositorio base y sólo se consumirá el entrypoint público ejecutable
`bin/bspwm`; la base no leerá manifests, configuración ni metadata Git interna
del WM.

La base no clonará, actualizará, cambiará de branch ni hará push de otro
repositorio. La clonación y la referencia elegida permanecen explícitas y
documentadas. HTTPS será la opción universal para obtener repositorios públicos
sin configurar una identidad de GitHub; SSH será una alternativa equivalente
para colaboradores con llave configurada. El transporte sólo determina la URL
de `origin` y no forma parte del contrato de orquestación.

Backend, plataforma, target, selección paquetes/Stow y modo apply se propagan al
entrypoint del WM. El perfil del WM permanece separado porque la base dispone de
`cli` y bspwm no. Antes de una operación con `--apply`, la integración ejecutará
el dry-run del WM para evitar mutaciones si su propio preflight ya falla. La
composición no pretende ser transaccional entre repositorios; ambos entrypoints
siguen siendo idempotentes y reportarán por separado cualquier fallo parcial.

No se introduce todavía un archivo de composición ni gestión automática del
ciclo de vida Git. Mango podrá adoptar el mismo contrato público en P11 si sus
operaciones resultan equivalentes.

Como convención local documentada, los ejemplos usarán
`$HOME/.dotfiles/base` para este repositorio y
`$HOME/.dotfiles/wm/{bspwm,mangowm}` para los checkouts de WM. Esta jerarquía
no forma parte del contrato del bootstrap: cada hijo conserva su propio
repositorio Git y `--wm-path` continúa aceptando cualquier checkout externo
válido. La carpeta común no constituye un monorepo ni introduce submodules.

## 7. Decisiones descartadas por ahora

| Alternativa | Motivo principal |
| --- | --- |
| Monorepo | Reduce autonomía y mezcla ciclos de vida de base, bspwm y Mango. |
| Git submodules | Añaden estado y acoplamiento sin ser necesarios para instalar repos independientes. |
| Chezmoi como fuente única | Su modelo centraliza y agrega complejidad para la composición deseada. |
| Copiar Archcraft o instalar paquetes settings | Oculta ownership y vuelve a introducir dependencias implícitas. |
| Configuración privada dentro del repo público con ignores | Mantiene alto el riesgo de publicación accidental. |
| Secrets dentro de un repo privado | Git no proporciona el modelo de protección requerido para credenciales. |
| Configuración GPU/DM desde dotfiles | Son responsabilidades del sistema y varían por máquina. |

## 8. Arquitectura objetivo

```text
dotfiles (público, base)
├── configuración portable de shell, CLI y aplicaciones comunes
├── perfiles y dependencias propias
├── bootstrap/doctor para su propio alcance
└── orquestación opcional mediante contratos públicos

bspwm (público, independiente)
├── sesión X11 completa bajo su ownership
├── dependencias, assets y scripts propios
└── instalación/validación standalone

mango (público, independiente, futuro)
├── sesión Wayland completa bajo su ownership
├── MangoWC, Waybar y componentes seleccionados
└── instalación/validación standalone

dotfiles-private (privado, opcional)
├── identidad y configuración personal/laboral no secreta
├── overrides mediante puntos de inclusión públicos
└── configuración específica de organizaciones o máquinas

secret manager / archivos locales (fuera de Git)
└── tokens, passwords, private keys y credenciales
```

No habrá enlaces internos obligatorios entre estos repositorios. Una persona
podrá instalar cualquiera de los públicos por separado. La composición desde
el repositorio base será una comodidad opt-in.

### Contrato común mínimo entre repositorios públicos

Cada repositorio deberá documentar y, cuando corresponda, ofrecer:

- responsabilidad y rutas bajo ownership;
- dependencias por plataforma y perfil;
- instalación standalone;
- simulación antes de enlazar archivos;
- detección de conflictos sin adopción automática;
- validación o comando `doctor` proporcional a su alcance;
- desinstalación de symlinks sin eliminar datos del usuario;
- código generado y estado runtime fuera del árbol fuente;
- puntos de integración estables, sin leer internals de otros repositorios.

P6 fijó `bin/dotfiles` como entrypoint de la base y validó sus operaciones
`bootstrap`, `doctor` y `unlink`. En P7/P11 cada repositorio WM deberá exponer
un contrato público equivalente; compartir nombres es preferible si encaja con
su alcance, pero no requiere compartir implementación ni leer manifests ajenos.

## 9. Ownership

| Área | Owner previsto | Notas |
| --- | --- | --- |
| Zsh portable y plugins | `dotfiles` | Shell delgada; includes condicionales privados/locales. |
| Aliases genéricos | `dotfiles` | Conjunto pequeño. |
| Aliases personales/laborales | `dotfiles-private` | No requieren editar `.zshrc` público. |
| Git portable | `dotfiles` | La identidad y ajustes organizacionales entran por include privado. |
| SSH no secreto | `dotfiles-private` o local | Keys y credenciales permanecen fuera de Git. |
| Bat, Starship, Micro, Yazi y apps comunes | `dotfiles` | Sólo si su configuración es portable y realmente usada. |
| Brave, Zathura, Thunar | `dotfiles` | Dependencias/app defaults opcionales, no pertenecen a un WM. |
| `.config/bspwm` y sesión X11 | `bspwm` | Incluye scripts necesarios y elimina herencia Archcraft. |
| Sxhkd/Picom/bar X11 | `bspwm` mientras sean exclusivos | La barra concreta se decide en P7. |
| `.config/mango` y sesión Wayland | `mango` | No se mezcla con bspwm. |
| Waybar y launcher Wayland | `mango` | Launcher pendiente entre Wofi/Fuzzel. |
| Playerctl | Repo consumidor | Puede declararse en más de un manifiesto sin compartir ownership de archivos. |
| Wallpapers | Repo de assets independiente | Integración opcional. |
| Display manager | Sistema/CachyOS | No gestionado inicialmente. |
| Drivers y GPU híbrida | Sistema/CachyOS | Dotfiles sólo validan o exponen uso opt-in. |
| Estado generado/cache | Aplicación, bajo XDG state/cache | Nunca se reescribe el checkout para cambiar estado. |

Si un componente pasa a ser compartido por varios WMs, primero se elegirá un
único owner. No se extraerá prematuramente un quinto repositorio sin una ventaja
demostrable.

## 10. Estrategia de configuración privada

La composición preferida es un repositorio privado independiente instalado por
separado con Stow y puntos de inclusión definidos por la base. La precedencia
será:

```text
defaults públicos
→ configuración privada opcional
→ override local de máquina no versionado
```

Reglas:

- Los includes usan comprobaciones de existencia y no producen warnings por
  ausencia.
- El repositorio privado no reemplaza archivos completos bajo ownership
  público si un drop-in pequeño puede expresar el override.
- Las rutas de inclusión serán estables y estarán documentadas.
- La URL o existencia del repo privado no se codificará en repos públicos.
- Un bootstrap público puede aceptar una ruta privada explícita, pero nunca la
  buscará, clonará o habilitará silenciosamente.
- Los archivos locales de máquina no se versionan en ninguno de los repos.
- Antes de commits se validará que no aparezcan emails laborales, hosts,
  rutas personales sensibles, tokens, keys o archivos de entorno privados.

Los nombres definitivos de los drop-ins se fijarán en P3 y P9, procurando que
Zsh, Git y SSH usen sus mecanismos nativos de include cuando existan.

## 11. Estrategia Zsh

La configuración pública resultante tendrá responsabilidades separadas:

1. entorno y PATH portables;
2. completions y comportamiento interactivo;
3. plugins instalados por paquetes del sistema, con orden de carga explícito;
4. aliases públicos pequeños;
5. inicialización condicional de herramientas disponibles;
6. include privado opcional;
7. include local de máquina al final.

`EDITOR` y `VISUAL` usarán Micro como default público, con posibilidad de
override. `BROWSER` usará Brave. Las integraciones de Node, pnpm o Bun sólo
permanecerán en base si son portables y deliberadamente públicas; las
específicas de trabajo pasarán a privado.

## 12. Estrategia de paquetes y dependencias

Cada repositorio declara lo que consume. La deduplicación pertenece al
instalador, no se consigue ocultando dependencias en el repositorio base.

Los manifiestos deberán separar al menos:

- paquetes de repositorios oficiales;
- paquetes AUR;
- fuentes externas que requieran una acción distinta;
- requisitos obligatorios;
- features o perfiles opcionales.

Perfiles conceptuales iniciales del repositorio base:

- `core`: Git, GNU Stow, Zsh, los plugins requeridos y herramientas
  necesarias para instalar/validar los propios dotfiles;
- `cli`: Starship, Bat, Micro, Yazi y herramientas de terminal aceptadas;
- `desktop`: Brave, Zathura, Thunar y asociaciones gráficas aceptadas;
- `development`: herramientas públicas de desarrollo que se decida conservar.

Estos nombres son conceptuales hasta P5. Los nombres reales de paquetes se
validarán contra CachyOS/Arch/AUR antes de crear manifiestos.

Reproducibilidad en una distribución rolling significa:

- conjunto de dependencias declarado y revisable;
- procedencia conocida;
- bootstrap idempotente;
- preflight y post-validación;
- registro de excepciones o paquetes reemplazados;
- no depender de archivos copiados por una distro anterior.

No significa congelar automáticamente todo el sistema ni mantener un mirror de
paquetes.

## 13. Estrategia general de bootstrap

El bootstrap se implementará después de estabilizar layout y manifiestos. Su
flujo general será:

```text
preflight
→ detectar plataforma y backend de paquetes
→ resolver perfiles solicitados
→ mostrar plan/dry-run
→ instalar dependencias sólo con autorización de la invocación
→ comprobar conflictos Stow
→ enlazar paquetes seleccionados
→ ejecutar post-validaciones
→ resumir cambios y acciones manuales
```

Propiedades obligatorias:

- funciona para el repositorio base sin ningún WM o repo privado;
- no usa `sudo` para enlazar dotfiles;
- limita privilegios a la instalación de paquetes;
- soporta `shelly`, `paru`, `yay` y fallback oficial con `pacman`;
- permite forzar backend y perfiles;
- es idempotente;
- dispone de dry-run útil;
- se detiene ante colisiones y nunca adopta archivos automáticamente;
- no cambia display manager, drivers, configuración GPU ni servicios sin una
  decisión posterior explícita;
- no clona configuración privada;
- deja pasos manuales claramente identificados;
- permite retirar symlinks de forma segura.

La orquestación opcional de un WM sólo se añade después de que su repositorio
pueda instalarse standalone. P8 implementó ese contrato para bspwm invocando la
interfaz pública de un checkout explícito; no lo clona ni lo incorpora como
submodule. Mango deberá cumplir primero el mismo requisito de autonomía.

## 14. Estrategia de migración

- Trabajar en pasos pequeños y revisables, sin big-bang rewrite.
- Mover primero responsabilidades sin cambiar comportamiento, cuando sea
  posible.
- Introducir validaciones antes de automatizar instalaciones.
- Mantener los submodules actuales hasta que la alternativa standalone de
  bspwm esté probada.
- No limpiar MIME, aliases o paquetes sólo por estética; cada eliminación debe
  tener un reemplazo, una razón o evidencia de que está obsoleta.
- En bspwm, capturar primero la funcionalidad que Archcraft aportaba y después
  retirar dependencias una por una.
- Validar tanto instalación individual como composición.
- Tratar el PC y la laptop como perfiles/capacidades, no como listas de nombres
  de hardware codificadas.

## 15. Roadmap

| Fase | Alcance | Criterio de salida | Estado |
| --- | --- | --- | --- |
| P0 | Materializar este plan aprobado. | El documento captura audit, decisiones, arquitectura, fases, riesgos y progreso; no se implementan dotfiles. | **Completa** |
| P1 | Gobernanza y límites del repositorio base. | `README.md` explica responsabilidad y estado real; `AGENTS.md` define el flujo operativo; ambos enlazan este plan y no prometen un bootstrap inexistente. | **Completa** |
| P2 | Fundación GNU Stow del repositorio base. | Existe stow directory dedicado, paquetes mínimos y dry-run sin conflictos; las rutas movidas conservan comportamiento. | **Completa** |
| P3 | Refactor incremental de Zsh. | Oh My Zsh eliminado; plugins públicos funcionan; responsabilidades separadas; precedencia público→privado→local validada; `zsh -n` pasa. | **Completa** |
| P4 | Configuraciones base y apps actuales. | Bat/Starship y configuraciones aceptadas tienen owner claro; `.xprofile`, Geany y MIME se conservan, migran o retiran con decisión explícita. | **Completa** |
| P5 | Manifiestos de dependencias y perfiles. | Paquetes oficiales/AUR/externos separados, nombres validados en CachyOS y perfiles documentados; incluye apps seleccionadas. | **Completa** |
| P6 | Bootstrap y doctor del repositorio base. | Dry-run, selección Shelly/paru/yay/pacman, instalación por perfiles, Stow y validaciones son idempotentes; base funciona sola. | **Completa** |
| P7 | Autonomía del repositorio bspwm. | Funcionalidad útil inventariada/preservada; scripts/assets/dependencias son propios; supuestos Archcraft/hardware eliminados; instalación standalone validada. | **Completa** |
| P8 | Integración opcional y retiro de submodules. | Base puede integrar bspwm por contrato público; gitlink y entradas obsoletas se retiran sin romper instalación individual. | **Completa** |
| P9 | Contrato e integración privada. | Repo privado opcional usa includes/drop-ins, precedencia probada y controles anti-filtración; públicos funcionan sin él. | Pendiente |
| P10 | Validación desde CachyOS no-desktop. | Instalación limpia documentada y probada en un entorno controlado; diferencias PC/laptop y pasos manuales quedan registradas. | Pendiente |
| P11 | Repositorio público Mango. | Stack decidido; MangoWC/Waybar/launcher y dependencias tienen ownership; instalación standalone y composición opcional validadas. | Pendiente |
| P12 | Cierre de migración. | Documentación estable, deuda residual y decisiones históricas revisadas; el plan se conserva, transforma o archiva deliberadamente. | Pendiente |

### P0 — Materializar el plan

1. Crear este documento con el estado auditado.
2. Registrar decisiones aprobadas y abiertas.
3. Definir fases, criterios de salida y reglas de cambio.
4. Revisar el diff sin iniciar cambios de configuración.

### P1 — Gobernanza y límites

1. Reescribir el README para representar el repositorio base, su estado de
   migración y su relación no obligatoria con otros repositorios.
2. Crear `AGENTS.md` con reglas operativas breves: leer plan, respetar fase,
   detenerse, validar, no commitear sin autorización y proteger datos privados.
3. Documentar la función diferente de README, AGENTS y este plan.
4. Validar links, consistencia y que no se anuncien comandos aún inexistentes.

### P2 — Fundación Stow

1. Diseñar la taxonomía mínima de paquetes.
2. Crear el stow directory y su marcador.
3. Migrar un primer paquete de bajo riesgo.
4. Validar simulación, enlace y desinstalación.
5. Migrar el resto sólo en pasos aprobados.

Resultado del 2026-08-20:

- `home/` quedó establecido como stow directory y marcado con `home/.stow`;
- `home/bat` es el primer paquete y conserva sin cambios los cuatro temas
  Catppuccin antes ubicados directamente bajo `.config/bat`;
- GNU Stow 2.4.1 se validó primero desde el paquete oficial firmado de Arch,
  extraído temporalmente, y después con `/usr/bin/stow` cuando estuvo disponible
  globalmente durante la revisión final;
- dry-run, enlace de cuatro archivos con `--no-folding`, segunda ejecución
  idempotente, unstow y aborto ante colisión pasaron contra homes temporales;
- las pruebas no modificaron el home real ni ejecutaron una instalación de
  paquetes del sistema;
- los demás dotfiles permanecen en su layout transitorio para las fases
  posteriores.

### P3 — Zsh

1. Inventariar qué bloques son públicos, privados, locales u obsoletos.
2. Crear la estructura modular pública.
3. Retirar Oh My Zsh.
4. Cargar directamente los plugins públicos aprobados.
5. Reducir aliases públicos y establecer includes/precedencia.
6. Validar sintaxis, shell interactivo y ausencia de herramientas opcionales.

Resultado del 2026-08-20:

- `home/zsh` separa entorno, completion, historial, rehash, aliases e
  inicialización;
- Oh My Zsh y todos los aliases e integraciones JavaScript heredados fueron
  retirados del repositorio público;
- los plugins cargan directamente desde paquetes de Arch/CachyOS, con orden
  explícito según sus requisitos de integración;
- los únicos aliases públicos son cuatro variantes genéricas de `ls`;
- `~/.config/zsh/private.zsh` y `~/.config/zsh/local.zsh` son opcionales y se
  aplican en ese orden después de la configuración pública;
- `zsh -n`, arranque interactivo aislado, precedencia, plugins y el ciclo
  Stow/unstow pasaron sin modificar el home real.

### P4 — Configuración base

1. Revisar cada config existente por uso y ownership.
2. Separar o retirar supuestos X11 del repo base.
3. Alinear defaults con Brave, Zathura, Micro, Yazi y Thunar cuando sus desktop
   entries y paquetes estén confirmados.
4. Postergar asociaciones no decididas, incluido el visor de imágenes.

Resultado del 2026-08-20:

- Starship pasó a `home/starship`; sus módulos de Node.js y Bun quedan
  deshabilitados y la capa privada puede seleccionar otro `STARSHIP_CONFIG`;
- `home/xdg-defaults` contiene sólo asociaciones confirmadas: Brave para web,
  Zathura MuPDF para PDF, Micro para texto plano, Thunar para directorios y mpv
  para formatos multimedia comunes;
- el visor de imágenes permanece deliberadamente sin asociación pública;
- la configuración de Geany fue retirada porque Micro lo reemplaza;
- `.xprofile` fue retirado porque codificaba monitores y comportamiento X11 de
  una máquina dentro del repositorio base neutral a WM;
- Starship, MIME, ausencia de residuos y el ciclo conjunto Stow/restow/unstow
  pasaron contra un home temporal.

### P5 — Dependencias

1. Definir formato y perfiles sin duplicar lógica de instalación.
2. Validar nombres y procedencia de paquetes en CachyOS.
3. Marcar AUR, externos y features opcionales.
4. Definir cómo los repos WM declaran dependencias compartidas.

Resultado del 2026-08-20:

- `packages/` define perfiles acumulativos `core`, `cli`, `desktop` y el feature
  opcional `yazi-extras`, junto con su selección de paquetes Stow;
- 30 nombres bajo `repo/` fueron comprobados primero en el portal de paquetes
  de CachyOS; no se fijaron versiones;
- Brave se instala desde el repositorio propio de CachyOS y `brave-bin` queda
  documentado como fallback AUR sólo para Arch sin ese repositorio, después de
  confirmar su ausencia en los repos oficiales de Arch;
- Zathura usa `zathura-pdf-mupdf`; `poppler` sólo aparece en el feature opcional
  para previews PDF de Yazi;
- mpv incluye `mpv-mpris` para exponer la interfaz que Playerctl controla;
- Shelly, paru, yay y pacman están registrados como backends en orden de
  detección, no como dependencias que el bootstrap deba instalar por defecto;
- clipboard X11/Wayland, Waybar, launcher, GPU y display manager permanecen en
  el owner o fase correspondiente;
- formato, orden, duplicados, paquetes Stow, exclusión del stack JavaScript,
  disponibilidad CachyOS y fallback AUR pasaron las validaciones.

### P6 — Bootstrap base

1. Implementar preflight y doctor de sólo lectura.
2. Implementar resolución de perfiles y backends.
3. Integrar Shelly, paru, yay y pacman según capacidad.
4. Integrar dry-run/conflict check de Stow.
5. Implementar instalación, unlink y post-validación idempotentes.
6. Documentar los pasos manuales y límites.

Resultado del 2026-08-20:

- `bin/dotfiles` implementa `bootstrap`, `doctor` y `unlink`; bootstrap/unlink
  son dry-run por defecto y ninguna mutación ocurre sin `--apply`;
- los perfiles y el feature `yazi-extras` se resuelven directamente desde los
  manifests de P5, con detección Arch/CachyOS y overrides explícitos;
- Shelly 3.0.6 usa lotes separados `install standard`/`install aur`; paru y yay
  usan `-S --needed` restringido con `--repo`/`--aur`; pacman se limita a
  repositorios y bloquea AUR faltante;
- no se fuerza confirmación automática en AUR y el preflight completo termina
  antes de cualquier mutación si backend, capacidad o target no son válidos;
- el adaptador Stow usa siempre `--dir`, `--target` y `--no-folding`, combina
  detector interno de colisiones con simulación nativa y nunca usa `--adopt`;
- doctor valida paquetes, capacidad del backend, sintaxis Zsh y ownership de
  cada symlink; unlink simula primero y valida que no queden enlaces propios;
- `tests/bootstrap-smoke.sh` probó dry-run, apply, doctor, segunda aplicación
  idempotente, colisión, unlink y los cuatro adaptadores sin instalar paquetes
  del host;
- README documenta operación, privilegios, pasos manuales y límites. La
  instalación real de paquetes en CachyOS limpio sigue reservada a P10.
- antes del primer checkpoint se retiraron los ignores heredados del layout
  raíz y las entradas inertes de wallpapers/fonts en `.gitmodules`; bspwm se
  conserva como único gitlink transitorio y los assets Catppuccin mantienen su
  aviso MIT en `THIRD_PARTY_NOTICES.md`.

### P7 — bspwm

1. Auditar el repo nuevamente contra el sistema que sirve de referencia.
2. Crear un inventario de funciones y dependencias heredadas de Archcraft.
3. Dar ownership a scripts, assets y configs necesarios.
4. Sustituir detecciones/nombres de hardware concretos.
5. Decidir la barra X11 y preservar primero el comportamiento aceptado.
6. Añadir manifiestos, Stow/bootstrap/doctor standalone.
7. Validar sin `/etc/skel` de Archcraft.

Resultado al 2026-08-22: la implementación standalone quedó preparada en la rama
local `refactor/standalone-bspwm`, con `backup/pre-p7-archcraft` apuntando al
baseline previo. El audit comparativo, el layout Stow, los manifiestos, el
entrypoint propio, los hooks locales y la configuración estática de Polybar
están implementados. La primera VM confirmó la instalación standalone y reveló
los ajustes D21: dependencia de Xauth, fallback de Polybar, override documentado
de Picom y restauración de UX en Rofi/Super. Las correcciones están aplicadas y
han pasado las validaciones aisladas del repositorio. Una segunda prueba en VM
mostró que Polybar sólo se hacía visible cuando `BSPWM_POLYBAR_RIGHT` llegaba
definida, aunque el log confirmaba los mismos módulos en modo automático. El
launcher normaliza y exporta ahora el valor resuelto, limita la sonda de BlueZ
y serializa invocaciones concurrentes. Durante esa revalidación se detectó y
retiró un cookie de PulseAudio generado accidentalmente dentro del paquete Stow
por una prueba local que usó el source como `$HOME`; nunca se tocó el cookie
real del usuario. El bootstrap rechaza ahora cualquier ruta de `home/bspwm`
fuera de `.config/bspwm`. La validación final en VM confirmó que Polybar aparece
con selección automática y sin definir `BSPWM_POLYBAR_RIGHT` en `local.env`.
P7 queda completa; no se inicia P8 ni se retira todavía el gitlink del
repositorio base.

Seguimiento del 2026-08-22: una revisión visual posterior reabrió P7 de forma
acotada para normalizar el ritmo de Polybar, centrar los glifos de Rofi,
incorporar el selector XKB `us,latam` solicitado y aplicar el radio moderado de
Picom acordado en D22. La fase volverá a cerrarse después de las validaciones
locales y una comprobación visual en VM; P8 permanece fuera de alcance.
La implementación local ya pasó Bash, ShellCheck, parsers de Polybar/Rofi,
smoke tests de bootstrap/sesión, ejecución de Picom con `xrender`, resolución
del perfil CachyOS y controles de scope/portabilidad. Sólo queda la comprobación
visual y física del selector de layout en la VM.

Segundo seguimiento del 2026-08-22: el usuario amplió el pulido visual usando
`tsjazil/dotfiles` como objetivo de apariencia. D23 autoriza reorganizar los
módulos y colores de Polybar, retirar su botón de apagado, sustituir el borde de
foco por atenuación de ventanas inactivas y añadir Alacritty Catppuccin al repo
base bajo ownership compartido. P7 permanece activa hasta validar estos cambios
en la VM; P8 y la configuración de Zathura no se inician.

La implementación D23 ya pasó las validaciones locales de ambos repositorios:
Bash, ShellCheck, smoke tests, ciclos Stow en homes temporales, carga real de
los módulos nuevos de Polybar bajo Xvfb, Picom con `xrender`, parser/migración de
Alacritty y resolución del perfil CachyOS. El perfil base administra ahora 15
enlaces, incluido un único `alacritty.toml`. Sólo queda la comprobación visual
en VM de geometría, tipografías, métricas y nivel de atenuación antes de cerrar
P7.

Tercer seguimiento del 2026-08-22: la prueba visual sustituyó la geometría
flotante de D23 por la barra anclada definida en D25. El tray vuelve a ser
obligatorio en la composición predeterminada y pasa al bloque central, a la
derecha de fecha/hora; el workspace activo recibe un indicador circular Pink y
el tray una cápsula Surface0. P7 continúa activa hasta validar este último
ajuste en la VM.

La implementación D25 pasó Bash, ShellCheck, los smoke tests de bootstrap y
sesión, el parser de Polybar y una sesión bspwm real bajo Xvfb. La prueba de
render usó temporalmente la versión exacta de `Symbols Nerd Font Mono`
declarada y un cliente XEmbed real: confirmó geometría `1280x34+0+0`, ocho
módulos, docking del tray y ausencia de errores de formato. El material
temporal se retiró después de la prueba. Sólo queda la comprobación visual en
la VM del usuario.

Cuarto seguimiento del 2026-08-22: la captura de la VM reveló que el indicador
circular era el fallback de una tabla `ws-icon` incompatible con los nombres
por glifo de la sesión, y que las tapas decorativas del tray producían un bloque
visual inconsistente alrededor de `volumeicon`. D25 se rectifica para preservar
el nombre/icono real del workspace, aplicar Pink directamente al estado activo
y usar un tray nativo sin cápsula. `volumeicon` se mantiene fuera del manifest:
se utilizó únicamente como cliente XEmbed de prueba. P7 continúa activa hasta
revalidar este ajuste en la VM.

La rectificación pasó Bash, ShellCheck, ambos smoke tests de bspwm, el ciclo
Stow aislado, el parser de Polybar y una sesión bspwm real bajo Xvfb. El render
con los ocho nombres por glifo y la versión exacta de
`Symbols Nerd Font Mono` confirmó que el workspace activo conserva su icono y
recibe el acento Pink. El módulo tray carga sin propiedades decorativas; queda
pendiente comprobar `volumeicon` en la VM, porque el entorno Xvfb aislado no
ofrece un mixer al cliente.

El 2026-08-23 el usuario dio por terminado este checkpoint después de las
pruebas en VM y autorizó comenzar P8. P7 queda completa; cualquier refinamiento
visual posterior será mantenimiento explícito y no reabre por sí solo la
arquitectura standalone.

### P8 — Integración de repos públicos

1. Definir la interfaz de orquestación mínima.
2. Probar base+bspwm conservando autonomía.
3. Retirar el gitlink y la entrada restante de bspwm en `.gitmodules`.
4. Documentar clonación/ref seleccionada sin acoplar internals.

D26 fija la interfaz aprobada: checkout externo explícito, delegación exclusiva
al entrypoint público y ningún cambio automático de Git. La implementación debe
probar base sola, bspwm solo y composición tanto con un doble aislado como con
el repositorio público real antes de retirar el gitlink transitorio.

Resultado al 2026-08-23: `bin/dotfiles` integra de forma opt-in `bootstrap`,
`doctor` y `unlink` mediante `--wm bspwm`, `--wm-path` y `--wm-profile`. El
smoke test cubre propagación, perfiles independientes, paths con espacios,
preflight fallido y operaciones dry-run/apply. La composición también se probó
contra un clon temporal del repositorio público real en el commit `65845c2`:
dry-run, apply, doctor, segunda aplicación idempotente y unlink terminaron sin
colisiones ni enlaces residuales, sin instalar paquetes ni tocar el home real.
Tras retirar el gitlink se repitió el ciclo completo con un clon SSH y el mismo
resultado; la prueba inicial había usado HTTPS.

Antes de retirar el gitlink se verificó que el checkout local estaba limpio y
que ese commit existía en `origin/refactor/standalone-bspwm`. `.config/bspwm` y
la `.gitmodules` ya no están versionados; README documenta tanto SSH como HTTPS
y mantiene explícito el branch transitorio. Base y bspwm siguen instalándose de
forma individual. Con ello se cumplen los cuatro criterios de salida de P8.

### P9 — Privado

1. Definir rutas de includes para Zsh, Git, SSH y entorno.
2. Definir repo/layout privado sin registrar su URL en público.
3. Probar ausencia, instalación y precedencia.
4. Añadir validaciones contra datos privados/secretos accidentales.
5. Mantener secret management como problema separado.

### P10 — CachyOS limpio

1. Preparar checklist reproducible para una instalación no-desktop.
2. Probar base solo, cada WM solo y composición elegida.
3. Validar Shelly y al menos un fallback aplicable.
4. Registrar pasos del sistema que no pertenecen a dotfiles.
5. Validar Intel+NVIDIA sin hardcodes de salida/GPU.

### P11 — Mango

1. Confirmar stack mínimo usando Archcraft sólo como referencia.
2. Decidir Wofi o Fuzzel.
3. Crear repo público, ownership, dependencias y documentación.
4. Implementar MangoWC y Waybar sin mutar fuente para temas/estado.
5. Integrar Playerctl y apps sólo donde exista consumo real.
6. Validar standalone y orquestación opcional desde base.

### P12 — Cierre

1. Ejecutar validación completa y revisar deuda.
2. Consolidar instrucciones estables en README/AGENTS.
3. Trasladar decisiones arquitectónicas duraderas a documentación estable si
   mejora su consulta.
4. Decidir si este plan permanece como registro, se reduce o se archiva.

## 16. Criterios de aceptación globales

- Los tres repositorios públicos funcionan sin acceso a la capa privada.
- Base, bspwm y Mango pueden instalarse y mantenerse por separado.
- No quedan dependencias implícitas de Archcraft.
- Ningún archivo tiene ownership ambiguo entre repositorios.
- La ausencia de apps/features opcionales produce degradación clara, no fallos
  opacos.
- La instalación desde CachyOS no-desktop está documentada y validada.
- Los manifests explican qué se instala y desde qué fuente.
- Bootstrap y Stow pueden simularse y repetirse sin adoptar o borrar archivos.
- La precedencia pública/privada/local está probada.
- Los repos públicos no contienen información privada, laboral ni secretos.
- README, AGENTS y este plan describen el mismo estado.

## 17. Validaciones esperadas

Cada fase elegirá sólo las validaciones proporcionales a sus cambios. El set
final debería cubrir:

- `git diff --check` y revisión manual del diff;
- links y estructura de Markdown;
- sintaxis Zsh y arranque interactivo controlado;
- simulación, instalación y unstow por paquete;
- idempotencia del bootstrap;
- manifests resolubles con cada backend soportado según capacidad;
- detección de colisiones y ausencia de `--adopt` automático;
- búsqueda de referencias Archcraft, paths privados y hardcodes de hardware;
- instalación sin repos privados ni wallpapers;
- instalación standalone de cada WM;
- smoke tests X11/Wayland en hardware o entorno adecuado.

## 18. Riesgos conocidos

| Riesgo | Mitigación |
| --- | --- |
| Funcionalidad de bspwm vive sólo en `/etc/skel` de Archcraft. | Inventario comparativo y migración behavior-first en P7. |
| Stow colisiona con archivos existentes del home. | Dry-run, paquetes pequeños, `--no-folding`, backups manuales explícitos y nunca `--adopt` automático. |
| Datos privados se añaden al repo público. | Repo separado, drop-ins, revisión pre-commit y validaciones específicas. |
| Scripts de temas mutan archivos versionados. | Renderizar a XDG state/cache o aplicar configuración sin reescribir fuente. |
| Paquetes cambian en Arch/AUR/CachyOS. | Separar procedencia, validar en P5/P10 y reportar sustituciones. |
| Shelly, paru y yay no son interfaces idénticas. | Adaptadores pequeños por capacidad, override explícito y pruebas por backend. |
| Hardware PC/laptop diverge. | Detección de capacidades y overrides locales; sin nombres codificados. |
| Mango crece copiando todo Archcraft. | Selección feature-by-feature y non-goal explícito de réplica. |
| Documentación se separa de la implementación. | Reconciliar plan al cerrar cada fase y bloquear desvíos silenciosos. |

## 19. Decisiones abiertas

Estas decisiones no autorizan implementación hasta resolverse en su fase:

| ID | Decisión | Momento previsto |
| --- | --- | --- |
| O1 | Wofi o Fuzzel como launcher Wayland. | P11 |
| O3 | Visor de imágenes y asociaciones MIME restantes. | Cuando se seleccione un visor |
| O5 | Stack mínimo definitivo de Mango además de MangoWC/Waybar. | P11 |
| O6 | Nombre, ubicación local y estructura final del repo privado. | P9 |
| O7 | Hacer público el repositorio de wallpapers y su mecanismo opt-in. | P8/P11 |
| O8 | Herramienta/proceso de gestión de secretos. | Cuando exista la necesidad |

## 20. Seguimiento de progreso

Estados permitidos: `Pendiente`, `Activa`, `Bloqueada`, `Completa`.

| Fase | Estado | Evidencia / notas |
| --- | --- | --- |
| P0 | **Completa** | Plan materializado y validado el 2026-08-20; no modificó dotfiles. |
| P1 | **Completa** | README y AGENTS alineados con el plan y validados el 2026-08-20. |
| P2 | **Completa** | `home/.stow` y paquete `bat`; dry-run/install/idempotencia/unstow/conflicto validados con Stow 2.4.1 el 2026-08-20. |
| P3 | **Completa** | Zsh modular sin Oh My Zsh; seguimiento D24 para completions/búsqueda substring autorizado el 2026-08-22. |
| P4 | **Completa** | Apps/configs base revisadas y ciclo Stow validado el 2026-08-20. |
| P5 | **Completa** | Perfiles/fuentes validados; adiciones D23/D24 verificadas en CachyOS/Arch el 2026-08-22. |
| P6 | **Completa** | Entrypoint, dry-run/apply, doctor, unlink, adaptadores y smoke test validados el 2026-08-20. |
| P7 | **Completa** | Standalone y pulido D20–D25 validados localmente y en VM; checkpoint aceptado el 2026-08-23. |
| P8 | **Completa** | Contrato D26, composición aislada/real, documentación y retiro del gitlink validados el 2026-08-23. |
| P9 | Pendiente | Requiere nueva aprobación y alcance del repo privado. |
| P10 | Pendiente | Requiere nueva aprobación y entorno de prueba adecuado. |
| P11 | Pendiente | Requiere nueva aprobación y creación del repo Mango. |
| P12 | Pendiente | Requiere nueva aprobación. |

### Registro de cambios del plan

| Fecha | Cambio | Motivo / aprobación |
| --- | --- | --- |
| 2026-08-20 | Arquitectura y roadmap iniciales; D1–D12. | Aprobación explícita del usuario tras el audit. |
| 2026-08-20 | D13 y D14: Shelly/paru/yay y selección inicial de apps. | Instrucción explícita del usuario al autorizar P0 y P1. |
| 2026-08-20 | P0 completada y P1 iniciada. | Plan materializado, revisado y validado sin implementar configuración. |
| 2026-08-20 | P1 completada; P2 queda pendiente. | README y reglas operativas creados, sin modificar dotfiles ni bootstrap. |
| 2026-08-20 | P2 iniciada. | Autorización explícita para crear la fundación GNU Stow. |
| 2026-08-20 | D15 registrada y P2 completada. | Layout `home/<paquete>` validado con el primer paquete `bat`; P3 queda pendiente. |
| 2026-08-20 | P3–P5 autorizadas; P3 iniciada. | Se detiene antes de implementar O10/O4 para confirmar preferencias del usuario. |
| 2026-08-20 | D16 y D17; O4/O10 resueltas. | El usuario asigna el stack JavaScript a privado, elige Zathura MuPDF y fija prioridad CachyOS→Arch→AUR. |
| 2026-08-20 | P3 completada; P4 iniciada. | Zsh modular validado sin Oh My Zsh ni dependencias privadas. |
| 2026-08-20 | P4 completada; P5 iniciada. | Defaults aceptados migrados; Geany y `.xprofile` retirados con decisión explícita. |
| 2026-08-20 | D18 registrada y P5 completada. | Perfiles, fuentes y ownership de dependencias validados; P6 queda sin autorizar. |
| 2026-08-20 | Revisión conjunta P3–P5 completada. | Se recuperó el historial persistente que antes aportaba Oh My Zsh y pasó la validación integral sin tocar el home real. |
| 2026-08-20 | P6 iniciada. | Autorización explícita para implementar el bootstrap y doctor del repositorio base; P7 permanece fuera de alcance. |
| 2026-08-20 | D19 registrada y P6 completada. | Contrato `bin/dotfiles` y ciclo dry-run/apply/doctor/unlink validados; P7 queda sin autorizar. |
| 2026-08-21 | Higiene previa al primer checkpoint. | Se retiraron ignores obsoletos y metadata de submodules sin gitlink; se preservó la licencia de Catppuccin Bat. |
| 2026-08-21 | P7 iniciada. | Autorización explícita para convertir bspwm en un repositorio standalone antes de las pruebas en VM. |
| 2026-08-21 | D20; O2 resuelta. | El usuario confirmó conservar Polybar inicialmente, eliminando hardcodes y herencia runtime de Archcraft. |
| 2026-08-21 | P7 preparada para validación en VM. | Audit, ownership, bootstrap standalone y pruebas aisladas completados; la fase sigue activa hasta validar la sesión real. |
| 2026-08-22 | D21; primera validación standalone en VM. | La sesión funcionó con `xorg-xauth`, Picom `xrender` y override de módulos Polybar; se autorizaron correcciones de UX para Super, Rofi y README. |
| 2026-08-22 | Correcciones D21 listas para revalidar. | Xauth y Xcape declarados; Polybar limita el tray y prueba fallback/precedencia; Rofi recupera cuadrícula e iconos; bootstrap, sesión, parsers y runtimes aislados pasan. |
| 2026-08-22 | Segundo ajuste de Polybar listo para revalidar. | La VM confirmó que los módulos cargan pero el modo automático no se muestra; se igualó el entorno automático/explícito y se protegió el launcher frente a esperas de BlueZ y carreras. |
| 2026-08-22 | Contaminación runtime retirada del paquete bspwm. | Una prueba aislada generó `.config/pulse/cookie` dentro del source Stow; se eliminó sólo esa copia, se preservó el home real y se añadió un guard de ownership con prueba negativa. |
| 2026-08-22 | P7 completada. | La revalidación en VM confirmó instalación standalone, inicio mediante Ly y Polybar automática sin `BSPWM_POLYBAR_RIGHT`; P8 queda pendiente y sin autorización. |
| 2026-08-22 | P7 reabierta para pulido post-VM; D22. | El usuario solicitó corregir ritmo visual de Polybar/Rofi, recuperar `Alt+Space` para `us,latam` y usar `tsjazil/dotfiles` como referencia; Zathura permanece bajo ownership del repo base. |
| 2026-08-22 | Pulido D22 listo para revalidar en VM. | Espaciado/icon fonts, centrado Rofi, radio Picom y XKB fueron implementados; validaciones locales completas, sin iniciar Zathura ni P8. |
| 2026-08-22 | D23; referencia visual ampliada. | Se autoriza una Polybar flotante con métricas en unidades, foco sin borde rectangular y Alacritty Catppuccin bajo ownership del repositorio base; Zathura y P8 permanecen fuera de alcance. |
| 2026-08-22 | Implementación D23 lista para revalidar. | Polybar, Picom, Alacritty, manifiestos y ambos ciclos Stow pasan validaciones locales; P7 espera la comprobación visual en VM. |
| 2026-08-22 | D24; plugins Zsh ampliados. | El usuario solicitó `zsh-completions` y `zsh-history-substring-search`; se autoriza el mantenimiento acotado de P3/P5 sin cambiar la fase activa P7. |
| 2026-08-22 | Implementación D24 validada. | Manifest `core`, completions, orden de plugins y bindings normal/terminfo pasaron pruebas con los paquetes oficiales; P7 sigue esperando la VM. |
| 2026-08-22 | Seguimiento D24: activación del shell. | La VM seguía abriendo Bash pese a tener los paquetes; se mantiene `chsh` manual y se autoriza una advertencia accionable en bootstrap/doctor. |
| 2026-08-22 | Activación D24 validada. | Los cuatro plugins cargan en Zsh con paquetes actuales; el smoke test reproduce Bash como login shell y verifica el aviso sin mutar la cuenta. |
| 2026-08-22 | Segundo seguimiento D24: ruta de `chsh` y colores de `ls`. | La VM expuso un hardlink no registrado de Zsh y aliases sin `--color=auto`; se autoriza resolver sólo shells listados y recuperar colores explícitos. |
| 2026-08-22 | Segundo seguimiento D24 validado. | Bootstrap elige una ruta anunciada por `chsh`; los cuatro aliases activan color sólo en terminal y pasan las pruebas aisladas. |
| 2026-08-22 | D25; Polybar anclada y tray central. | El usuario reemplazó la geometría flotante por una barra sin márgenes/radio exterior, fijó Pink como acento y solicitó elementos redondeados para workspace/tray; P7 sigue activa. |
| 2026-08-22 | Implementación D25 validada localmente. | Geometría, composición multimonitor/fallback, parser, fuente exacta, indicador activo y tray XEmbed pasaron smoke tests y render bajo Xvfb; resta validar apariencia en la VM. |
| 2026-08-22 | D25 rectificada tras la captura de la VM. | El círculo ocultaba los nombres por glifo y la cápsula no componía limpiamente con `volumeicon`; se autoriza foco Pink sobre el icono real y tray nativo. |
| 2026-08-22 | Rectificación D25 validada localmente. | El icono activo se preservó con la fuente exacta en Xvfb; parser, sesión, Stow y smoke tests pasan, mientras `volumeicon` requiere la VM con mixer real. |
| 2026-08-23 | P7 completada; P8 iniciada. | El usuario cerró el checkpoint probado en VM y autorizó la integración opcional; O9 continúa abierta hasta aprobar su UX concreta. |
| 2026-08-23 | D26; O9 resuelta. | Se aprobó `--wm` con checkout externo explícito, perfil separado y delegación al entrypoint público; HTTPS y SSH son alternativas de clonación, no parte del contrato. |
| 2026-08-23 | P8 completada. | Smoke test y composición con el repositorio bspwm real pasaron el ciclo completo; se documentaron ambos transportes y se retiraron gitlink y `.gitmodules` sin alterar el remoto. |
| 2026-08-23 | Convención local posterior a P8. | Tras validar la integración, el usuario eligió organizar checkouts independientes bajo `~/.dotfiles/base` y `~/.dotfiles/wm/`; se actualizan sólo recomendaciones y ejemplos, no el contrato. |

## 21. Relación con otros documentos

- `README.md`: explicación pública, estable y orientada a usuarios. Sólo debe
  anunciar instalación que exista y esté validada.
- `AGENTS.md`: reglas operativas concisas para agentes y colaboradores; obliga
  a consultar este plan y a respetar aprobaciones/fases.
- `docs/migration-plan.md`: arquitectura, decisiones, roadmap, riesgos,
  decisiones abiertas y estado vivo de la migración.

Al finalizar la migración, la información estable de uso pertenece al README y
las reglas permanentes a AGENTS. Este documento puede conservarse como registro
arquitectónico, reducirse o archivarse, pero la decisión debe ser explícita.

## 22. Flujo de cierre de fase

```text
implementar
→ validar
→ revisar diff
→ reconciliar plan/progreso
→ proponer commit
→ esperar aprobación
→ commit sólo si se solicita explícitamente
→ seleccionar la siguiente fase aprobada
```

No se hacen commits por defecto. Completar una fase tampoco autoriza la
siguiente.

# Instrucciones para agentes y colaboradores

Estas reglas aplican a todo el repositorio.

## Antes de cambiar archivos

1. Leer [README.md](README.md) y el
   [plan de migración](docs/migration-plan.md) completos.
2. Revisar `git status`, la fase activa, sus criterios de salida y las
   decisiones abiertas.
3. Inspeccionar el estado real antes de proponer cambios.
4. Confirmar que la fase está explícitamente autorizada. El roadmap no concede
   permiso para implementar fases pendientes.

La instrucción explícita más reciente del usuario tiene prioridad. Si contradice
el plan, señalarlo y proponer cómo reconciliar ambos antes de implementar la
decisión contradictoria.

## Flujo de trabajo

Para cada fase o paso aprobado:

```text
leer plan
→ seleccionar un paso pequeño
→ explicar el alcance
→ implementar
→ validar
→ revisar el diff
→ reconciliar el progreso con el plan
→ detenerse
```

- No avanzar automáticamente a otra fase.
- No implementar decisiones marcadas como abiertas.
- No hacer commits, pushes, tags ni cambios remotos sin autorización explícita.
- No modificar decisiones arquitectónicas aprobadas de forma silenciosa.
- Si la implementación exige desviarse del plan, explicar por qué, proponer el
  cambio y esperar aprobación antes de continuar por esa ruta.
- Preservar cambios existentes que no pertenezcan a la tarea.
- Preferir cambios pequeños, reversibles y revisables.
- No usar operaciones destructivas para resolver conflictos o limpiar el árbol.

Al cerrar una fase:

1. ejecutar validaciones proporcionales al riesgo;
2. revisar `git diff` y `git diff --check`;
3. actualizar estado/evidencia en el plan;
4. informar archivos cambiados, validaciones y decisiones pendientes;
5. detenerse antes de la siguiente fase salvo autorización explícita reciente.

## Límites arquitectónicos

- Este repositorio es la base pública y no debe depender de bspwm, Mango ni de
  dotfiles privados.
- `bspwm` y `mango` son repositorios públicos autónomos. No introducir nuevos
  submodules ni acoplamiento a sus internals.
- La integración entre repositorios debe usar interfaces documentadas y ser
  opcional.
- Cada ruta tiene un único owner. No crear archivos administrados a la vez por
  base, un WM y la capa privada.
- Las dependencias se declaran en el repositorio que las consume. Que varios
  repositorios declaren el mismo paquete es preferible a ocultar la dependencia.
- Estado generado, caches y resultados de theming no deben reescribir archivos
  versionados.
- No introducir nombres fijos de monitores, GPUs, baterías, backlights,
  interfaces de red o paths propios de una máquina en la configuración pública.
- Display manager y drivers/GPU pertenecen al sistema, no al alcance inicial de
  estos dotfiles.

## Configuración privada y secretos

- La capa privada debe ser opcional y vivir fuera de los repositorios públicos.
- Los puntos de inclusión públicos deben ignorar limpiamente archivos ausentes.
- La precedencia acordada es: defaults públicos → privado → local de máquina.
- No añadir al repositorio público identidades laborales, hosts privados, rutas
  sensibles, aliases personales ni variables internas.
- Passwords, tokens, private keys y credenciales no pertenecen a Git, ni
  siquiera a un repositorio privado.
- No codificar en público la URL, ubicación o existencia del repositorio
  privado.

## Documentación vigente de herramientas

Cuando una tarea dependa del uso, configuración, API o sintaxis actual de una
librería, framework, SDK, CLI o servicio cloud, consultar Context7 antes de
responder o implementar, aunque la herramienta sea conocida. No es necesario
para refactors internos, scripts desde cero, lógica de negocio, code review o
conceptos generales.

Flujo requerido, con un máximo de tres comandos por pregunta:

```bash
pnpm dlx ctx7@latest library <nombre-oficial> "<consulta específica>"
pnpm dlx ctx7@latest docs </org/proyecto> "<concepto específico>"
```

Resolver siempre el ID antes de pedir documentación, salvo que el usuario haya
dado directamente un ID `/org/proyecto`. Elegir la coincidencia oficial con
mejor relevancia, reputación y cobertura. No incluir información sensible en
las consultas. Si Context7 informa que se agotó la cuota, avisar y sugerir
`pnpm dlx ctx7@latest login` o `CONTEXT7_API_KEY`; no ocultar el fallback.
Ejecutar estas consultas fuera del sandbox predeterminado. Ante errores DNS o
de red, reintentar fuera del sandbox en lugar de repetir dentro de él.

## Criterios de implementación

- `clarity > cleverness`
- `explicit > magical`
- `simple > over-engineered`
- Mantener el equilibrio entre rendimiento, mantenibilidad y experiencia.
- Preferir GNU Stow con paquetes pequeños, `--no-folding`, dry-run y detección
  de conflictos; nunca automatizar `stow --adopt`.
- El bootstrap debe ser idempotente, inspeccionable y funcionar sin
  repositorios opcionales.
- No anunciar en README comandos o capacidades que todavía no existan y no
  hayan sido validadas.

Validaciones mínimas cuando se modifica el bootstrap, sus manifiestos o los
paquetes Stow:

```bash
bash -n bin/dotfiles tests/bootstrap-smoke.sh
shellcheck -x bin/dotfiles tests/bootstrap-smoke.sh  # si está disponible
./tests/bootstrap-smoke.sh
git diff --check
```

El smoke test sólo enlaza dentro de un directorio temporal y usa backends
falsos para los planes de paquetes; nunca debe instalar paquetes del host.

## Responsabilidad de la documentación

- `README.md`: uso público y estado estable del repositorio.
- `AGENTS.md`: reglas operativas duraderas.
- `docs/migration-plan.md`: arquitectura, decisiones, roadmap, riesgos y
  progreso vivo.

Actualizar el plan al completar una fase. Los cambios de progreso ordinarios
registran hechos; los cambios de arquitectura requieren discusión y aprobación.

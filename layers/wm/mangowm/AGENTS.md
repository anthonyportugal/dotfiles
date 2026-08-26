# Instrucciones para agentes y colaboradores

Estas reglas aplican a todo el repositorio.

## Antes de cambiar archivos

1. Leer `README.md`, `docs/architecture.md` y este archivo completos.
2. Revisar `git status` y preservar cambios ajenos.
3. Confirmar que el checkpoint esté autorizado explícitamente.
4. No anunciar como funcional una capacidad que sólo exista en el roadmap.

## Flujo

Trabajar en verticales pequeños: inspeccionar, implementar, validar, revisar el
diff y detenerse. No hacer commits, pushes, tags, cambios remotos ni crear el
repositorio público sin autorización explícita.

Cuando un commit esté autorizado:

- usar `emoji type(scope): subject` según gitmoji y Conventional Commits;
- escribir el subject en inglés y en modo imperativo;
- comenzar en minúscula la primera palabra después de `:`;
- revisar el staged y verificar la firma antes de publicar.

## Arquitectura y ownership

- Este repositorio debe instalarse sin los dotfiles base, bspwm ni una capa
  privada.
- Sólo administra la sesión MangoWM y componentes exclusivos de Wayland
  documentados en `docs/architecture.md`.
- No administra identidades, secretos, drivers, display manager, configuración
  GPU global, wallpapers obligatorios ni aplicaciones compartidas de la base.
- No introducir nombres fijos de monitores, GPUs, baterías, backlights,
  interfaces de red o paths propios de una máquina.
- Defaults públicos → override privado opcional → override local de máquina.
- Runtime, logs, caches, temas renderizados y selección activa pertenecen a
  XDG state/cache; nunca deben reescribir el checkout.
- Cada dependencia consumida se declara aquí aunque otro repositorio también
  la declare. No leer manifests ajenos.

## Stow y bootstrap

- `home/` será el único stow directory y usará paquetes pequeños.
- Usar siempre `--dir`, `--target`, `--no-folding`, dry-run y detección de
  conflictos; nunca ejecutar `stow --adopt`.
- `bin/mango` expone `bootstrap`, `doctor` y `unlink`, es dry-run por defecto e
  idempotente; preservar este contrato público.
- No ejecutar instalación de paquetes ni Stow con privilegios globales; sólo el
  package manager podrá elevar cuando el usuario aplique un plan.

## Seguridad

- Passwords, tokens, private keys, cookies, historiales de clipboard y
  credenciales no pertenecen a Git.
- El lock público no permitirá transparencia ni passwords vacíos.
- Clipboard history/persistence permanece opt-in y fuera del scaffold inicial.
- Los portales deben tener routing explícito; no iniciar backends duplicados.

## Validación

Cuando se modifiquen el bootstrap, manifests o paquetes Stow:

```bash
bash -n bin/mango tests/bootstrap-smoke.sh tests/scaffold-smoke.sh
shellcheck -x bin/mango tests/bootstrap-smoke.sh tests/scaffold-smoke.sh
./tests/scaffold-smoke.sh
./tests/bootstrap-smoke.sh
git diff --check
```

El smoke test sólo instala enlaces bajo homes temporales y usa backends falsos
para los planes de paquetes; nunca debe instalar paquetes del host.

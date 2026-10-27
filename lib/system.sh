#!/usr/bin/env bash
# `dotfiles system`: the only entrypoint of the root-level system layer
# (layers/system: Ly, Limine theme, DNS-over-TLS). It is opt-in and never runs
# from bootstrap, sync or update. Root files are written by the layer's own
# installer under an explicit sudo; packages go through the shared backend
# engine, and the applied selection is kept in the user's system receipt.

SYSTEM_LAYER_DIR="$REPO_ROOT/layers/system"

system_usage() {
  if [[ "${DOTFILES_LANG:-en}" == "es" ]]; then
    cat <<EOF
Uso:
  $PROGRAM_NAME system [setup] [opciones del instalador] [--install] [--backend B] [--target DIR]
  $PROGRAM_NAME system doctor [--target DIR]
  $PROGRAM_NAME system help

Capa opcional de sistema (Ly, tema de Limine, DNS-over-TLS). Escribe en /etc y
/boot con sudo explícito; bootstrap, sync y update nunca la ejecutan.

  setup       Aplica los componentes elegidos (sin componentes: menú interactivo).
  doctor      Audita Ly, Limine y DNS-over-TLS sin sudo y muestra la selección guardada.
  --install   Instala el paquete ly (si Ly está elegido) con el backend de paquetes del repositorio.

Opciones del instalador: -a/--all, -l/--ly, -b/--limine, -d/--dns,
-p/--provider NOMBRE, --custom ENDPOINTS, -t/--theme ACENTO, -n/--dry-run
(ver layers/system/README.es.md).
EOF
  else
    cat <<EOF
Usage:
  $PROGRAM_NAME system [setup] [installer options] [--install] [--backend B] [--target DIR]
  $PROGRAM_NAME system doctor [--target DIR]
  $PROGRAM_NAME system help

Optional system layer (Ly, Limine theme, DNS-over-TLS). It writes to /etc and
/boot under an explicit sudo; bootstrap, sync and update never run it.

  setup       Apply the selected components (no components: interactive menu).
  doctor      Audit Ly, Limine and DNS-over-TLS without sudo and show the saved selection.
  --install   Install the ly package (when Ly is selected) with the repository's package backend.

Installer options: -a/--all, -l/--ly, -b/--limine, -d/--dns,
-p/--provider NAME, --custom ENDPOINTS, -t/--theme ACCENT, -n/--dry-run
(see layers/system/README.md).
EOF
  fi
}

# Installs (or, in a dry run, plans) the layer's repo packages through the
# shared backend engine.
system_packages() {
  local dry_run=$1

  # Read by classify_packages and the install helpers in lib/packages.sh.
  # shellcheck disable=SC2034
  REPO_PACKAGES=() AUR_PACKAGES=() EXTERNAL_PACKAGES=()
  read_manifest "$SYSTEM_LAYER_DIR/packages/repo/system.txt" REPO_PACKAGES
  command_exists pacman || die "pacman es necesario para resolver el estado de paquetes"
  detect_platform
  detect_backend
  classify_packages
  if (( dry_run == 1 )); then
    show_package_commands
  else
    execute_package_install
  fi
}

cmd_system() {
  local subcommand=setup arg dry_run=0 install=0 components=0 ly=0 status=0
  local -a installer_args=() recorded=()
  local -A saved=()

  if (( $# > 0 )); then
    case "$1" in
      setup|doctor|check|help|-h|--help)
        subcommand=$1
        shift
        ;;
    esac
  fi
  case "$subcommand" in
    help|-h|--help)
      system_usage
      return 0
      ;;
  esac

  while (( $# > 0 )); do
    arg=$1
    case "$arg" in
      --target)
        require_option_value "$arg" "${2-}"
        TARGET_DIR=$2
        shift 2
        continue
        ;;
      --target=*)
        TARGET_DIR=${arg#*=}
        ;;
      --backend)
        require_option_value "$arg" "${2-}"
        BACKEND_REQUEST=$2
        shift 2
        continue
        ;;
      --backend=*)
        BACKEND_REQUEST=${arg#*=}
        ;;
      -i|--install)
        install=1
        ;;
      -n|--dry-run)
        dry_run=1
        installer_args+=("$arg")
        ;;
      -a|--all|-l|--ly)
        components=1 ly=1
        installer_args+=("$arg")
        recorded+=("$arg")
        ;;
      -b|--limine|-d|--dns)
        components=1
        installer_args+=("$arg")
        recorded+=("$arg")
        ;;
      -p|--provider|-t|--theme)
        require_option_value "$arg" "${2-}"
        installer_args+=("$arg" "$2")
        recorded+=("$arg" "$2")
        shift 2
        continue
        ;;
      --custom)
        require_option_value "$arg" "${2-}"
        installer_args+=("$arg" "$2")
        # A custom resolver id is private: never stored.
        recorded+=("$arg" "<omitido>")
        shift 2
        continue
        ;;
      *)
        usage_error "$(_t "unknown system option: $arg" "opción de system desconocida: $arg")"
        ;;
    esac
    shift
  done
  case "$BACKEND_REQUEST" in
    auto|shelly|paru|yay|pacman) ;;
    *) usage_error "$(_t "invalid backend: $BACKEND_REQUEST" "backend inválido: $BACKEND_REQUEST")" ;;
  esac
  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")

  if [[ "$subcommand" == doctor || "$subcommand" == check ]]; then
    if read_receipt system saved; then
      info "$(_t "Saved system selection" "Selección de system guardada"): ${saved[SYSTEM_ARGS]:-}"
    else
      info "$(_t "No system selection saved yet" "Todavía no hay una selección de system guardada")"
    fi
    "$SYSTEM_LAYER_DIR/install.sh" doctor --lang "${DOTFILES_LANG:-en}"
    return
  fi

  # The package is only needed when Ly can be part of the selection.
  if (( install == 1 && (ly == 1 || components == 0) )); then
    system_packages "$dry_run" || die "$(_t "the system packages could not be installed" "no se pudieron instalar los paquetes de system")"
  fi

  if (( dry_run == 1 )); then
    "$SYSTEM_LAYER_DIR/install.sh" "${installer_args[@]}" --lang "${DOTFILES_LANG:-en}"
    return
  fi

  if (( EUID == 0 )); then
    "$SYSTEM_LAYER_DIR/install.sh" "${installer_args[@]}" --lang "${DOTFILES_LANG:-en}" || status=$?
  else
    command_exists sudo || die "$(_t "sudo is required for the system layer" "sudo es necesario para la capa system")"
    sudo "$SYSTEM_LAYER_DIR/install.sh" "${installer_args[@]}" --lang "${DOTFILES_LANG:-en}" || status=$?
  fi
  (( status == 0 )) || die "$(_t "the system installer failed (exit $status)" "el instalador de system falló (salida $status)")"

  if (( components == 1 )); then
    write_receipt system SYSTEM_ARGS="${recorded[*]}"
    success "$(_t "System selection saved" "Selección de system guardada"): ${recorded[*]}"
  else
    info "$(_t "Interactive selection is not recorded; pass components to save it" "La selección interactiva no se guarda; indique componentes para guardarla")"
  fi
}

#!/usr/bin/env bash
# lib/layer_ops.sh - Bootstrap, doctor and unlink for one declarative layer.
#
# run_layer executes the operation in a fresh process (lib/run-layer.sh), so
# the layer's package, Stow and prune settings never leak into the caller's
# plan and errexit always applies. Reads the caller's TARGET_DIR,
# PLATFORM_REQUEST, BACKEND_REQUEST, SYSTEM_ENABLED, STOW_ENABLED, FEATURES,
# PACKAGE_BACKENDS_FILE and REPO_ROOT. Requires lib/colors.sh, lib/core.sh,
# lib/receipts.sh, lib/external.sh, lib/packages.sh, lib/links.sh and lib/layers.sh.
#
# shellcheck shell=bash

# Runs operation $3 (bootstrap|doctor|unlink) of layer $2 under layers root $1
# with profile $4. Apply mode $5 is 1 to modify the system, 0 for a dry run.
run_layer() {
  local layers_root=$1
  local layer_name=$2
  local operation=$3
  local layer_profile=$4
  local apply_mode=$5

  case "$operation" in
    bootstrap|doctor|unlink) ;;
    *) die "operación de capa desconocida: $operation" ;;
  esac

  TARGET_DIR="$TARGET_DIR" PLATFORM_REQUEST="$PLATFORM_REQUEST" \
    BACKEND_REQUEST="$BACKEND_REQUEST" SYSTEM_ENABLED="$SYSTEM_ENABLED" \
    STOW_ENABLED="$STOW_ENABLED" PACKAGE_BACKENDS_FILE="${PACKAGE_BACKENDS_FILE:-}" \
    FEATURES="${FEATURES[*]-}" \
    REPO_ROOT="$REPO_ROOT" DOTFILES_LANG="${DOTFILES_LANG:-en}" PROGRAM_NAME="$PROGRAM_NAME" \
    "$BASH" "$DOTFILES_LIB_DIR/run-layer.sh" \
    "$layers_root" "$layer_name" "$operation" "$layer_profile" "$apply_mode"
}

# Points the engine globals at layer $2 (profile $3, operation $4, apply mode
# $5) and restores its saved backend. Only called by lib/run-layer.sh.
# shellcheck disable=SC2034
_layer_setup() {
  local layers_root=$1
  local -A layer_conf=() layer_receipt=()

  LAYER_NAME=$2
  PROFILE=$3
  OPERATION=$4
  APPLY=$5
  LAYER_DIR="$layers_root/$LAYER_NAME"
  [[ -d "$LAYER_DIR" ]] || die "la capa '$LAYER_NAME' no existe en $layers_root"
  read_layer_conf "$LAYER_DIR" layer_conf

  LAYER_RECEIPT=${layer_conf[receipt]:-${LAYER_NAME//\//-}}
  PACKAGES_DIR="$LAYER_DIR/packages"
  STOW_DIR="$LAYER_DIR/home"
  read -r -a PRUNE_SEARCH_DIRS <<< "${layer_conf[prune_dirs]:-}"
  read -r -a PRUNE_ROOT_LINKS <<< "${layer_conf[prune_links]:-}"

  # Only the selected features this layer declares contribute manifests.
  local -a declared_features=() selected_features=()
  local feature
  read -r -a declared_features <<< "${layer_conf[features]:-}"
  read -r -a selected_features <<< "${FEATURES:-}"
  LAYER_FEATURES=()
  for feature in "${selected_features[@]}"; do
    array_contains declared_features "$feature" && append_unique LAYER_FEATURES "$feature"
  done

  REPO_PACKAGES=()
  AUR_PACKAGES=()
  EXTERNAL_PACKAGES=()
  STOW_PACKAGES=()
  INSTALLED_REPO_PACKAGES=()
  INSTALLED_AUR_PACKAGES=()
  MISSING_REPO_PACKAGES=()
  MISSING_AUR_PACKAGES=()
  INSTALLED_EXTERNAL_PACKAGES=()
  MISSING_EXTERNAL_PACKAGES=()

  # The receipt only matters when no backend was requested explicitly.
  if [[ "$BACKEND_REQUEST" == auto ]] && read_receipt "$LAYER_RECEIPT" layer_receipt; then
    restore_saved_backend "${layer_receipt[BACKEND]:-}"
  fi
}

# Per tier: repo/<tier>.txt, cachyos/<tier>.txt on CachyOS or
# aur/<tier>-fallback.txt elsewhere, aur/<tier>.txt and external/<tier>.txt.
# Selected features add repo/, aur/ and external/<feature>.txt. Every
# manifest is optional for a layer.
layer_resolve_system_packages() {
  local -a tiers=() fallback_packages=()
  local tier package_name feature

  layer_profile_tiers "$LAYER_DIR" "$PROFILE" tiers
  for tier in "${tiers[@]}"; do
    [[ ! -f "$PACKAGES_DIR/repo/$tier.txt" ]] || \
      append_manifest_unique REPO_PACKAGES "$PACKAGES_DIR/repo/$tier.txt"
    if [[ "$PLATFORM" == "cachyos" ]]; then
      [[ ! -f "$PACKAGES_DIR/cachyos/$tier.txt" ]] || \
        append_manifest_unique REPO_PACKAGES "$PACKAGES_DIR/cachyos/$tier.txt"
    elif [[ -f "$PACKAGES_DIR/aur/$tier-fallback.txt" ]]; then
      read_manifest "$PACKAGES_DIR/aur/$tier-fallback.txt" fallback_packages
      for package_name in "${fallback_packages[@]}"; do
        if package_in_official_arch_repos "$package_name"; then
          append_unique REPO_PACKAGES "$package_name"
        else
          append_unique AUR_PACKAGES "$package_name"
        fi
      done
    fi
    [[ ! -f "$PACKAGES_DIR/aur/$tier.txt" ]] || \
      append_manifest_unique AUR_PACKAGES "$PACKAGES_DIR/aur/$tier.txt"
    [[ ! -f "$PACKAGES_DIR/external/$tier.txt" ]] || \
      append_manifest_unique EXTERNAL_PACKAGES "$PACKAGES_DIR/external/$tier.txt"
  done

  for feature in "${LAYER_FEATURES[@]}"; do
    [[ ! -f "$PACKAGES_DIR/repo/$feature.txt" ]] || \
      append_manifest_unique REPO_PACKAGES "$PACKAGES_DIR/repo/$feature.txt"
    [[ ! -f "$PACKAGES_DIR/aur/$feature.txt" ]] || \
      append_manifest_unique AUR_PACKAGES "$PACKAGES_DIR/aur/$feature.txt"
    [[ ! -f "$PACKAGES_DIR/external/$feature.txt" ]] || \
      append_manifest_unique EXTERNAL_PACKAGES "$PACKAGES_DIR/external/$feature.txt"
  done
}

layer_prepare() {
  # Fails early, in every mode, when the layer does not declare the profile.
  # shellcheck disable=SC2034
  local -a profile_tiers=()
  layer_profile_tiers "$LAYER_DIR" "$PROFILE" profile_tiers

  if (( SYSTEM_ENABLED == 1 )); then
    command_exists pacman || die "pacman es necesario para resolver el estado de paquetes"
    detect_platform
    layer_resolve_system_packages
    detect_backend
    classify_packages
  fi
  if (( STOW_ENABLED == 1 )); then
    [[ -f "$STOW_DIR/.stow" ]] || die "falta el marcador $STOW_DIR/.stow"
    TARGET_DIR=$(realpath -m -- "$TARGET_DIR")
    [[ -d "$TARGET_DIR" ]] || die "el target no es un directorio existente: $TARGET_DIR"
    [[ "$TARGET_DIR" != "/" ]] || die "se rechaza usar / como target de Stow"
    if (( APPLY == 1 )); then
      [[ -w "$TARGET_DIR" ]] || die "el target no es escribible: $TARGET_DIR"
      if (( EUID == 0 )) && [[ -n "${SUDO_USER-}" ]]; then
        die "no ejecute el bootstrap completo con sudo; el script eleva sólo el package manager"
      fi
    fi
    read_layer_stow_packages "$LAYER_DIR" "$PROFILE" STOW_PACKAGES
    layer_add_feature_stow_packages
  fi
}

# Selected features also add the Stow packages of packages/stow/<feature>.txt.
layer_add_feature_stow_packages() {
  local feature entry
  local -a entries=()

  for feature in "${LAYER_FEATURES[@]}"; do
    [[ -f "$PACKAGES_DIR/stow/$feature.txt" ]] || continue
    read_manifest "$PACKAGES_DIR/stow/$feature.txt" entries
    for entry in "${entries[@]}"; do
      [[ -d "$STOW_DIR/$entry" ]] || die "el paquete Stow '$entry' no existe bajo $STOW_DIR"
      append_unique STOW_PACKAGES "$entry"
    done
  done
}

layer_print_plan() {
  local execution_mode

  if [[ "$OPERATION" == doctor ]]; then
    execution_mode="read-only"
  elif (( APPLY == 1 )); then
    execution_mode="apply"
  else
    execution_mode="dry-run"
  fi

  info "Plan de la capa $LAYER_NAME"
  printf '  %-24s %s\n' 'Operación:' "$OPERATION"
  printf '  %-24s %s\n' 'Modo:' "$execution_mode"
  printf '  %-24s %s\n' 'Perfil:' "$PROFILE"
  (( ${#LAYER_FEATURES[@]} == 0 )) || print_array "Features" LAYER_FEATURES
  if (( SYSTEM_ENABLED == 1 )); then
    printf '  %-24s %s\n' 'Plataforma:' "$PLATFORM"
    printf '  %-24s %s\n' 'Backend:' "$BACKEND"
    print_array "Paquetes repo" REPO_PACKAGES
    print_array "Paquetes AUR" AUR_PACKAGES
    print_array "Paquetes externos" EXTERNAL_PACKAGES
    print_array "Repo faltantes" MISSING_REPO_PACKAGES
    print_array "AUR faltantes" MISSING_AUR_PACKAGES
    print_array "Externos faltantes" MISSING_EXTERNAL_PACKAGES
  fi
  if (( STOW_ENABLED == 1 )); then
    printf '  %-24s %s\n' 'Target:' "$TARGET_DIR"
    print_array "Paquetes Stow" STOW_PACKAGES
  fi
}

layer_bootstrap() {
  local plan_valid=1 replace_target

  layer_prepare
  layer_print_plan

  if (( SYSTEM_ENABLED == 1 )); then
    show_package_commands || plan_valid=0
    validate_package_plan || plan_valid=0
  fi

  if (( STOW_ENABLED == 1 )); then
    if run_layer_hook "$LAYER_DIR" validate && ensure_no_link_collisions; then
      if command_exists stow; then
        if (( ${#LINK_REPLACE[@]} > 0 )); then
          info "Autorreparación: se reemplazarán ${#LINK_REPLACE[@]} enlace(s) con --apply; omitiendo simulación inicial de Stow"
        else
          info "Simulación nativa de GNU Stow"
          run_stow install 1 || plan_valid=0
        fi
      elif (( SYSTEM_ENABLED == 1 )) && array_contains MISSING_REPO_PACKAGES stow; then
        warn "Stow aún no está instalado; el preflight interno pasó y el perfil lo instalará antes de enlazar"
      else
        error "GNU Stow no está instalado"
        plan_valid=0
      fi
    else
      plan_valid=0
    fi
  fi

  (( plan_valid == 1 )) || die "el preflight de la capa $LAYER_NAME falló; no se modificó nada"

  if (( APPLY == 0 )); then
    info "Dry-run de la capa $LAYER_NAME completado"
    return 0
  fi

  if (( SYSTEM_ENABLED == 1 )); then
    execute_package_install || die "falló la instalación de paquetes de la capa $LAYER_NAME"
  fi

  if (( STOW_ENABLED == 1 )); then
    command_exists stow || die "GNU Stow no quedó disponible después de instalar paquetes"
    run_layer_hook "$LAYER_DIR" validate || die "la capa $LAYER_NAME dejó de ser válida"
    ensure_no_link_collisions || die "apareció una colisión antes de enlazar"
    if (( ${#LINK_REPLACE[@]} > 0 )); then
      info "Reemplazando ${#LINK_REPLACE[@]} enlace(s) obsoletos o absolutos del repositorio"
      for replace_target in "${LINK_REPLACE[@]}"; do
        rm -f -- "$replace_target"
      done
    fi
    info "Última simulación de GNU Stow antes de aplicar"
    run_stow install 1 || die "la simulación de GNU Stow falló"
    info "Aplicando enlaces GNU Stow"
    run_stow install 0 || die "GNU Stow no pudo crear los enlaces"
    validate_links_installed || die "falló la validación posterior de enlaces"
    prune_dangling_dotfiles_links 1
    run_layer_hook "$LAYER_DIR" post-link || die "falló el hook post-link de la capa $LAYER_NAME"
  fi

  write_receipt "$LAYER_RECEIPT" PROFILE="$PROFILE" BACKEND="${BACKEND:-}"
  info "Bootstrap de la capa $LAYER_NAME completado"
}

layer_doctor() {
  local result=0

  layer_prepare
  layer_print_plan

  if (( SYSTEM_ENABLED == 1 )); then
    if (( ${#MISSING_REPO_PACKAGES[@]} > 0 || ${#MISSING_AUR_PACKAGES[@]} > 0 || ${#MISSING_EXTERNAL_PACKAGES[@]} > 0 )); then
      error "faltan paquetes de la capa $LAYER_NAME"
      result=1
    else
      info "Paquetes validados: ${#REPO_PACKAGES[@]} de repo, ${#AUR_PACKAGES[@]} de AUR y ${#EXTERNAL_PACKAGES[@]} externos"
    fi
    validate_package_plan || result=1
  fi

  if (( STOW_ENABLED == 1 )); then
    run_layer_hook "$LAYER_DIR" validate || result=1
    if ! command_exists stow; then
      error "GNU Stow no está instalado"
      result=1
    fi
    validate_links_installed || result=1
    prune_dangling_dotfiles_links 0
  fi

  if (( result == 0 )); then
    info "Doctor: la capa $LAYER_NAME está correcta"
  else
    error "Doctor: se encontraron problemas en la capa $LAYER_NAME"
  fi
  return "$result"
}

layer_unlink() {
  layer_prepare
  layer_print_plan

  command_exists stow || die "GNU Stow es necesario para retirar enlaces"
  run_layer_hook "$LAYER_DIR" validate || die "la capa $LAYER_NAME no pasó la validación previa al unlink"
  info "Simulación de unlink con GNU Stow"
  run_stow delete 1 || die "la simulación de unlink falló; no se modificó nada"

  if (( APPLY == 0 )); then
    info "Dry-run de unlink de la capa $LAYER_NAME completado"
    return 0
  fi

  info "Retirando enlaces GNU Stow; no se eliminarán paquetes ni archivos ajenos"
  run_stow delete 0 || die "GNU Stow no pudo retirar los enlaces"
  prune_dangling_dotfiles_links 1
  validate_links_unlinked || die "falló la validación posterior de unlink"
  rm -f -- "$(receipt_path "$LAYER_RECEIPT")"
  info "Unlink de la capa $LAYER_NAME completado"
}

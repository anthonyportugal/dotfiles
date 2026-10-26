#!/usr/bin/env bash
# lib/packages.sh - Platform detection and package backends (shelly, paru, yay, pacman).
#
# Reads PLATFORM_REQUEST, BACKEND_REQUEST, PACKAGES_DIR, PLATFORM, BACKEND,
# REPO_PACKAGES, AUR_PACKAGES and EXTERNAL_PACKAGES; fills the INSTALLED_* and
# MISSING_* package arrays. Requires lib/colors.sh and lib/core.sh.
#
# shellcheck shell=bash

read_os_release_value() {
  local requested_key=$1
  local key value

  [[ -r /etc/os-release ]] || return 1
  while IFS='=' read -r key value; do
    [[ "$key" == "$requested_key" ]] || continue
    if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
      value=${value:1:${#value}-2}
    fi
    printf '%s' "$value"
    return 0
  done < /etc/os-release
  return 1
}

detect_platform() {
  local os_id os_like os_identity

  if [[ "$PLATFORM_REQUEST" != "auto" ]]; then
    PLATFORM=$PLATFORM_REQUEST
    return 0
  fi

  os_id=$(read_os_release_value ID || true)
  os_like=$(read_os_release_value ID_LIKE || true)
  os_identity=" $os_id $os_like "

  if [[ "$os_identity" == *" cachyos "* ]]; then
    PLATFORM="cachyos"
  elif [[ "$os_identity" == *" arch "* || "$os_id" == arch* ]]; then
    PLATFORM="arch"
  else
    die "plataforma no soportada (${os_id:-desconocida}); use --platform sólo si es compatible con Arch"
  fi
}

package_in_official_arch_repos() {
  local package_name=$1
  local repo_name

  for repo_name in core extra multilib; do
    if pacman -Si "$repo_name/$package_name" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

detect_backend() {
  local -a backend_order=()
  local candidate

  if [[ "$BACKEND_REQUEST" != "auto" ]]; then
    command_exists "$BACKEND_REQUEST" || \
      die "el backend solicitado no está instalado: $BACKEND_REQUEST"
    BACKEND=$BACKEND_REQUEST
    return 0
  fi

  read_manifest "$PACKAGES_DIR/package-backends.txt" backend_order
  for candidate in "${backend_order[@]}"; do
    case "$candidate" in
      shelly)
        [[ "$PLATFORM" == "cachyos" ]] || continue
        ;;
      paru|yay|pacman)
        ;;
      *)
        die "backend desconocido en package-backends.txt: $candidate"
        ;;
    esac
    if command_exists "$candidate"; then
      BACKEND=$candidate
      return 0
    fi
  done

  die "no se encontró ningún backend de paquetes soportado"
}

package_is_installed() {
  pacman -Qq "$1" >/dev/null 2>&1
}

classify_packages() {
  local package_name
  local -A installed_set=()

  INSTALLED_REPO_PACKAGES=()
  INSTALLED_AUR_PACKAGES=()
  MISSING_REPO_PACKAGES=()
  MISSING_AUR_PACKAGES=()

  if command_exists pacman; then
    local pkg
    while IFS= read -r pkg; do
      [[ -n "$pkg" ]] && installed_set["$pkg"]=1
    done < <(pacman -Qq 2>/dev/null || true)
  fi

  for package_name in "${REPO_PACKAGES[@]}"; do
    if [[ -n "${installed_set[$package_name]:-}" ]]; then
      INSTALLED_REPO_PACKAGES+=("$package_name")
    else
      MISSING_REPO_PACKAGES+=("$package_name")
    fi
  done

  for package_name in "${AUR_PACKAGES[@]}"; do
    if [[ -n "${installed_set[$package_name]:-}" ]]; then
      INSTALLED_AUR_PACKAGES+=("$package_name")
    else
      MISSING_AUR_PACKAGES+=("$package_name")
    fi
  done
}

# ShellCheck no puede seguir el array que se devuelve mediante nameref.
# shellcheck disable=SC2034
build_repo_install_command() {
  local output_name=$1
  local -n repo_output_ref=$output_name

  repo_output_ref=()
  (( ${#MISSING_REPO_PACKAGES[@]} > 0 )) || return 0
  case "$BACKEND" in
    shelly)
      repo_output_ref=(shelly install standard "${MISSING_REPO_PACKAGES[@]}")
      ;;
    paru|yay)
      # Evita que el helper convierta silenciosamente una entrada repo en AUR.
      repo_output_ref=("$BACKEND" -S --needed --repo "${MISSING_REPO_PACKAGES[@]}")
      ;;
    pacman)
      if (( EUID == 0 )); then
        repo_output_ref=(pacman -S --needed "${MISSING_REPO_PACKAGES[@]}")
      else
        repo_output_ref=(sudo pacman -S --needed "${MISSING_REPO_PACKAGES[@]}")
      fi
      ;;
  esac
}

# ShellCheck no puede seguir el array que se devuelve mediante nameref.
# shellcheck disable=SC2034
build_aur_install_command() {
  local output_name=$1
  local -n aur_output_ref=$output_name

  aur_output_ref=()
  (( ${#MISSING_AUR_PACKAGES[@]} > 0 )) || return 0
  case "$BACKEND" in
    shelly)
      aur_output_ref=(shelly install aur "${MISSING_AUR_PACKAGES[@]}")
      ;;
    paru|yay)
      # Mantiene explícita la procedencia declarada por el manifest.
      aur_output_ref=("$BACKEND" -S --needed --aur "${MISSING_AUR_PACKAGES[@]}")
      ;;
    pacman)
      return 1
      ;;
  esac
}

show_package_commands() {
  local -a repo_command=()
  local -a aur_command=()
  local result=0

  info "Comandos de instalación previstos"
  build_repo_install_command repo_command
  if (( ${#repo_command[@]} > 0 )); then
    format_command "${repo_command[@]}"
  fi

  if ! build_aur_install_command aur_command; then
    error "pacman no puede instalar los paquetes AUR faltantes: ${MISSING_AUR_PACKAGES[*]}"
    result=1
  elif (( ${#aur_command[@]} > 0 )); then
    format_command "${aur_command[@]}"
  fi

  if (( ${#repo_command[@]} == 0 && ${#aur_command[@]} == 0 )); then
    printf '    (todos los paquetes seleccionados ya están instalados)\n'
  fi
  return "$result"
}

validate_package_plan() {
  local result=0

  if (( ${#EXTERNAL_PACKAGES[@]} > 0 )); then
    error "no hay adaptador para fuentes externas: ${EXTERNAL_PACKAGES[*]}"
    result=1
  fi
  if [[ "$BACKEND" == "pacman" && ${#MISSING_AUR_PACKAGES[@]} -gt 0 ]]; then
    error "el perfil necesita AUR pero pacman sólo gestiona repositorios; instale Shelly, paru o yay, o fuerce otro backend"
    result=1
  fi
  return "$result"
}

execute_package_install() {
  local -a repo_command=()
  local -a aur_command=()

  validate_package_plan || return 1
  if [[ "$BACKEND" == "pacman" && "$EUID" -ne 0 ]]; then
    command_exists sudo || die "sudo es necesario para instalar paquetes con pacman"
  fi

  build_repo_install_command repo_command
  build_aur_install_command aur_command

  if (( ${#repo_command[@]} > 0 )); then
    info "Instalando paquetes de repositorio con $BACKEND"
    "${repo_command[@]}"
  fi
  if (( ${#aur_command[@]} > 0 )); then
    info "Instalando paquetes AUR con $BACKEND; revise PKGBUILD y prompts del helper"
    "${aur_command[@]}"
  fi

  classify_packages
  if (( ${#MISSING_REPO_PACKAGES[@]} > 0 || ${#MISSING_AUR_PACKAGES[@]} > 0 )); then
    print_array "Repo aún faltantes" MISSING_REPO_PACKAGES
    print_array "AUR aún faltantes" MISSING_AUR_PACKAGES
    error "la validación posterior de paquetes falló"
    return 1
  fi
  return 0
}

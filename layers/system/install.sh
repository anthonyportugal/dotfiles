#!/usr/bin/env bash
# ==============================================================================
# dotfiles-system - Master System Components Installer
# ==============================================================================
# Unified installer for Ly display manager, Limine bootloader, and DNS-over-TLS.
# Theme: Catppuccin Mocha
# ==============================================================================

set -euo pipefail

# shellcheck disable=SC2034
BOLD='\033[1m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'
C_MAUVE='\033[38;2;203;166;247m'
C_BLUE='\033[38;2;137;180;250m'

DOTFILES_LANG="${DOTFILES_LANG:-en}"

_t() {
    local en_text=$1
    local es_text=${2:-$1}
    if [[ "${DOTFILES_LANG}" == "es" ]]; then
        printf '%b' "$es_text"
    else
        printf '%b' "$en_text"
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LY_SETUP="${SCRIPT_DIR}/ly/setup.sh"
LIMINE_SETUP="${SCRIPT_DIR}/limine/setup.sh"
DNS_SETUP="${SCRIPT_DIR}/dns/setup.sh"

INSTALL_LY=false
INSTALL_LIMINE=false
INSTALL_DNS=false

THEME_NAME="mauve"
PROVIDER_NAME="quad9"
CUSTOM_ENDPOINTS=""
DRY_RUN=false
CHECK_ONLY=false
AUTO_INSTALL=false

log_info()    { printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${RESET}   %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*"; }

usage() {
    cat <<USAGE
Usage: sudo ./install.sh [OPTIONS]

Component Selection (Composable):
  -a, --all               Install Ly, Limine, and DNS-over-TLS configurations
  -l, --ly                Install Ly display manager configuration
  -b, --limine            Install Limine bootloader theme
  -d, --dns               Install DNS-over-TLS configuration

Configuration Options:
  -p, --provider <name>   DNS-over-TLS provider: quad9 (default), cloudflare, cloudflare-security, adguard, mullvad, custom
  --custom <endpoints>    Custom DoT endpoints (e.g. "45.90.28.0#your-id.dns.nextdns.io")
  -t, --theme <name>      Theme accent for Limine: mauve (default), pink, blue
  -i, --install           Automatically install Ly package if not present (shelly/paru/yay/pacman)
  -n, --dry-run           Simulate installations without writing to disk
  -c, --check             Audit current state of Ly, Limine, and DNS-over-TLS
  --lang <en|es>          Language for interactive menu (default: en)
  -h, --help              Show this help message

Interactive Mode:
  Run without options to display an interactive menu.
USAGE
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all)
            INSTALL_LY=true
            INSTALL_LIMINE=true
            INSTALL_DNS=true
            shift
            ;;
        -l|--ly)
            INSTALL_LY=true
            shift
            ;;
        -b|--limine)
            INSTALL_LIMINE=true
            shift
            ;;
        -d|--dns)
            INSTALL_DNS=true
            shift
            ;;
        -p|--provider)
            PROVIDER_NAME="$2"
            shift 2
            ;;
        --custom)
            CUSTOM_ENDPOINTS="$2"
            PROVIDER_NAME="custom"
            shift 2
            ;;
        -t|--theme)
            THEME_NAME="$2"
            shift 2
            ;;
        -i|--install)
            AUTO_INSTALL=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --lang)
            DOTFILES_LANG="$2"
            shift 2
            ;;
        --lang=*)
            DOTFILES_LANG="${1#*=}"
            shift
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

printf '%b' "\n${C_MAUVE}"
cat <<'BANNER'
╭─────────────────────────────────────────────────────────────╮
│                      ANTHONY PORTUGAL                       │
│               dotfiles-system • Setup Wizard                │
│             Ly, Limine Bootloader & DNS-over-TLS            │
╰─────────────────────────────────────────────────────────────╯
BANNER
printf '%b\n' "${RESET}"

# Run check mode if requested
if [[ "${CHECK_ONLY}" == true ]]; then
    log_info "Running comprehensive system audit..."
    "${LY_SETUP}" --check
    printf "\n"
    "${LIMINE_SETUP}" --check
    printf "\n"
    "${DNS_SETUP}" --check
    exit 0
fi

# Interactive menu if no components were specified
if [[ "${INSTALL_LY}" == false && "${INSTALL_LIMINE}" == false && "${INSTALL_DNS}" == false ]]; then
    printf '%b%s%b\n' "${BOLD}${C_MAUVE}" "$(_t "Select components to configure:" "Selecciona los componentes a configurar:")" "${RESET}"
    echo "  1) $(_t "All components (Ly + Limine + DNS) [Recommended]" "Todos los componentes (Ly + Limine + DNS) [Recomendado]")"
    echo "  2) $(_t "Ly display manager only" "Solo Display Manager Ly")"
    echo "  3) $(_t "Limine bootloader only" "Solo bootloader Limine")"
    echo "  4) $(_t "DNS-over-TLS only" "Solo DNS-over-TLS")"
    echo "  5) $(_t "Custom selection (choose interactively)" "Selección personalizada interactiva")"
    echo "  6) $(_t "Audit system status (--check)" "Auditar estado del sistema (--check)")"
    echo "  7) $(_t "Exit" "Salir")"
    printf "\n%b%s [1-7]: %b" "${C_BLUE}" "$(_t "Enter choice" "Ingresa una opción")" "${RESET}"
    read -r choice
    case "${choice}" in
        1)
            INSTALL_LY=true
            INSTALL_LIMINE=true
            INSTALL_DNS=true
            ;;
        2)
            INSTALL_LY=true
            ;;
        3)
            INSTALL_LIMINE=true
            ;;
        4)
            INSTALL_DNS=true
            ;;
        5)
            printf "\n%b%s%b [%s]: " "${BOLD}" "$(_t "Configure Ly display manager?" "¿Configurar gestor de pantalla Ly?")" "${RESET}" "$(_t "y/N" "s/N")"
            read -r ans_ly
            [[ "${ans_ly}" =~ ^[yYsS]$ ]] && INSTALL_LY=true

            printf "%b%s%b [%s]: " "${BOLD}" "$(_t "Configure Limine bootloader theme?" "¿Configurar tema de Limine?")" "${RESET}" "$(_t "y/N" "s/N")"
            read -r ans_limine
            [[ "${ans_limine}" =~ ^[yYsS]$ ]] && INSTALL_LIMINE=true

            printf "%b%s%b [%s]: " "${BOLD}" "$(_t "Configure DNS-over-TLS?" "¿Configurar DNS-over-TLS?")" "${RESET}" "$(_t "y/N" "s/N")"
            read -r ans_dns
            [[ "${ans_dns}" =~ ^[yYsS]$ ]] && INSTALL_DNS=true
            ;;
        6)
            "${LY_SETUP}" --check
            printf "\n"
            "${LIMINE_SETUP}" --check
            printf "\n"
            "${DNS_SETUP}" --check
            exit 0
            ;;
        7|q|Q)
            _t "Operation cancelled.\n" "Operación cancelada.\n"
            exit 0
            ;;
        *)
            log_error "$(_t "Invalid selection." "Selección inválida.")"
            exit 1
            ;;
    esac
fi

if [[ "${INSTALL_LY}" == false && "${INSTALL_LIMINE}" == false && "${INSTALL_DNS}" == false ]]; then
    log_info "No components selected for installation. Exiting."
    exit 0
fi

# Ensure scripts exist and are executable
chmod +x "${LY_SETUP}" "${LIMINE_SETUP}" "${DNS_SETUP}"

LY_FLAGS=()
LIMINE_FLAGS=()
DNS_FLAGS=()

if [[ "${DRY_RUN}" == true ]]; then
    LY_FLAGS+=("--dry-run")
    LIMINE_FLAGS+=("--dry-run")
    DNS_FLAGS+=("--dry-run")
fi

if [[ "${AUTO_INSTALL}" == true ]]; then
    LY_FLAGS+=("--install")
fi

LIMINE_FLAGS+=("--theme" "${THEME_NAME}")

if [[ -n "${PROVIDER_NAME}" ]]; then
    DNS_FLAGS+=("--provider" "${PROVIDER_NAME}")
fi

if [[ -n "${CUSTOM_ENDPOINTS}" ]]; then
    DNS_FLAGS+=("--custom" "${CUSTOM_ENDPOINTS}")
fi

run_ly() {
    log_info "Executing Ly installer..."
    "${LY_SETUP}" "${LY_FLAGS[@]}"
}

run_limine() {
    log_info "Executing Limine installer..."
    "${LIMINE_SETUP}" "${LIMINE_FLAGS[@]}"
}

run_dns() {
    log_info "Executing DNS-over-TLS installer..."
    "${DNS_SETUP}" "${DNS_FLAGS[@]}"
}

EXECUTED=false

if [[ "${INSTALL_LY}" == true ]]; then
    run_ly
    EXECUTED=true
fi

if [[ "${INSTALL_LIMINE}" == true ]]; then
    [[ "${EXECUTED}" == true ]] && printf "\n"
    run_limine
    EXECUTED=true
fi

if [[ "${INSTALL_DNS}" == true ]]; then
    [[ "${EXECUTED}" == true ]] && printf "\n"
    run_dns
fi

printf '%b\n\n' "\n${GREEN}${BOLD}✓ Setup finished successfully!${RESET}"

#!/usr/bin/env bash
# ==============================================================================
# dotfiles-system - Master System Components Installer
# ==============================================================================
# Unified installer for Ly display manager, Limine bootloader, and DNS-over-TLS.
# Theme: Catppuccin Mocha
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

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

printf '%b' "\n${CYAN}${BOLD}"
cat <<'BANNER'
    __      __  _____ __                                
   / /_  __/ /_/ __(_) /__  _____     _______  _______ _____
  / / / / / __/ /_/ / / _ \/ ___/____/ ___/ / / / ___// ___/
 / / /_/ / /_/ __/ / /  __(__  )/___(__  ) /_/ (__  ) /_    
/_/\__, /\__/_/ /_/_/\___/____/    /____/\__, /____/_/      
  /____/                                /____/              
BANNER
printf '%b\n' "${RESET}"
printf '%b\n\n' "${BOLD}Catppuccin Mocha • Ly, Limine & DNS-over-TLS${RESET}"

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
    printf '%b\n' "${BOLD}Select components to configure:${RESET}"
    echo "  1) All components (Ly + Limine + DNS)"
    echo "  2) Ly display manager only"
    echo "  3) Limine bootloader only"
    echo "  4) DNS-over-TLS only"
    echo "  5) Custom selection (choose interactively)"
    echo "  6) Audit system status (--check)"
    echo "  7) Exit"
    printf "\nEnter choice [1-7]: "
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
            printf "\n${BOLD}Configure Ly display manager?${RESET} [y/N]: "
            read -r ans_ly
            [[ "${ans_ly}" =~ ^[yYsS]$ ]] && INSTALL_LY=true

            printf "${BOLD}Configure Limine bootloader theme?${RESET} [y/N]: "
            read -r ans_limine
            [[ "${ans_limine}" =~ ^[yYsS]$ ]] && INSTALL_LIMINE=true

            printf "${BOLD}Configure DNS-over-TLS?${RESET} [y/N]: "
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
            echo "Operation cancelled."
            exit 0
            ;;
        *)
            log_error "Invalid selection."
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

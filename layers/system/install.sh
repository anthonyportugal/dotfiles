#!/usr/bin/env bash
# ==============================================================================
# dotfiles-system - Master System Components Installer
# ==============================================================================
# Unified installer for Ly display manager and Limine bootloader theming.
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

MODE=""
THEME_NAME="mauve"
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

Options:
  -a, --all             Install both Ly and Limine configurations
  -l, --ly              Install only Ly display manager configuration
  -b, --limine          Install only Limine bootloader theme
  -t, --theme <name>    Theme accent for Limine: mauve (default), pink, blue
  -i, --install         Automatically install Ly package if not present (shelly/paru/yay/pacman)
  -n, --dry-run         Simulate installations without writing to disk
  -c, --check           Audit current state of Ly and Limine
  -h, --help            Show this help message

Interactive Mode:
  Run without options to display an interactive menu.
USAGE
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all)
            MODE="all"
            shift
            ;;
        -l|--ly)
            MODE="ly"
            shift
            ;;
        -b|--limine)
            MODE="limine"
            shift
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
printf '%b\n\n' "${BOLD}Catppuccin Mocha • Ly Display Manager & Limine Bootloader${RESET}"

# Run check mode if requested
if [[ "${CHECK_ONLY}" == true ]]; then
    log_info "Running comprehensive system audit..."
    "${LY_SETUP}" --check
    printf "\n"
    "${LIMINE_SETUP}" --check
    exit 0
fi

# Interactive menu if no mode specified
if [[ -z "${MODE}" ]]; then
    printf '%b\n' "${BOLD}Select components to configure:${RESET}"
    echo "  1) All (Ly + Limine)"
    echo "  2) Ly display manager only"
    echo "  3) Limine bootloader only"
    echo "  4) Audit system status (--check)"
    echo "  5) Exit"
    printf "\nEnter choice [1-5]: "
    read -r choice
    case "${choice}" in
        1) MODE="all" ;;
        2) MODE="ly" ;;
        3) MODE="limine" ;;
        4)
            "${LY_SETUP}" --check
            printf "\n"
            "${LIMINE_SETUP}" --check
            exit 0
            ;;
        5|q|Q)
            echo "Operation cancelled."
            exit 0
            ;;
        *)
            log_error "Invalid selection."
            exit 1
            ;;
    esac
fi

# Ensure scripts exist and are executable
chmod +x "${LY_SETUP}" "${LIMINE_SETUP}"

LY_FLAGS=()
LIMINE_FLAGS=()

if [[ "${DRY_RUN}" == true ]]; then
    LY_FLAGS+=("--dry-run")
    LIMINE_FLAGS+=("--dry-run")
fi

if [[ "${AUTO_INSTALL}" == true ]]; then
    LY_FLAGS+=("--install")
fi

LIMINE_FLAGS+=("--theme" "${THEME_NAME}")

run_ly() {
    log_info "Executing Ly installer..."
    "${LY_SETUP}" "${LY_FLAGS[@]}"
}

run_limine() {
    log_info "Executing Limine installer..."
    "${LIMINE_SETUP}" "${LIMINE_FLAGS[@]}"
}

case "${MODE}" in
    all)
        run_ly
        printf "\n"
        run_limine
        ;;
    ly)
        run_ly
        ;;
    limine)
        run_limine
        ;;
esac

printf '%b\n\n' "\n${GREEN}${BOLD}✓ Setup finished successfully!${RESET}"

#!/usr/bin/env bash
# ==============================================================================
# Ly Display Manager - Setup & Configuration Installer
# ==============================================================================
# Safely installs the Catppuccin Mocha configuration to /etc/ly/
# Supports both legacy INI (Ly <= 1.4.x) and modern Lua (Ly >= 1.5.x / master).
# Injects Catppuccin Mocha palette into Linux Virtual Terminal via startup.sh.
# Provides automatic timestamped backups, binary discovery, and service checks.
# ==============================================================================

set -euo pipefail

# Visual formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_INI="${SCRIPT_DIR}/config.ini"
SOURCE_LUA="${SCRIPT_DIR}/config.lua"
SOURCE_STARTUP="${SCRIPT_DIR}/startup.sh"
TARGET_DIR="/etc/ly"
TARGET_INI="${TARGET_DIR}/config.ini"
TARGET_LUA="${TARGET_DIR}/config.lua"
TARGET_STARTUP="${TARGET_DIR}/startup.sh"

DRY_RUN=false
CHECK_ONLY=false

log_info()    { printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${RESET}   %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*"; }

usage() {
    cat <<USAGE
Usage: sudo $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run     Simulate actions without writing any files
  -c, --check       Audit current Ly configuration and service state
  -h, --help        Show this help message

Description:
  Installs the Catppuccin Mocha theme for the Ly display manager.
  Deploys config.ini, config.lua, and startup.sh (Linux VT palette injection)
  to ensure full compatibility across official packages (ly-dm / Ly 1.4.1)
  and manual source builds.
  Preserves automatic timestamped backups of any existing configurations.
USAGE
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
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

printf "${BOLD}================================================================${RESET}\n"
printf "${BOLD}       Ly Display Manager - Catppuccin Mocha Installer          ${RESET}\n"
printf "${BOLD}================================================================${RESET}\n\n"

# Verify source configuration files exist
if [[ ! -f "${SOURCE_INI}" ]]; then
    log_error "Source INI configuration not found: ${SOURCE_INI}"
    exit 1
fi
if [[ ! -f "${SOURCE_LUA}" ]]; then
    log_error "Source Lua configuration not found: ${SOURCE_LUA}"
    exit 1
fi
if [[ ! -f "${SOURCE_STARTUP}" ]]; then
    log_error "Source startup script not found: ${SOURCE_STARTUP}"
    exit 1
fi

# Multi-path binary discovery (supports ly, ly-dm, manual installs, and package builds)
find_ly_binary() {
    local candidates=(
        "ly"
        "ly-dm"
        "/usr/bin/ly"
        "/usr/bin/ly-dm"
        "/usr/local/bin/ly"
        "/usr/local/bin/ly-dm"
        "/opt/ly/bin/ly"
        "/opt/ly/ly"
    )

    for bin in "${candidates[@]}"; do
        if [[ "${bin}" == /* ]]; then
            if [[ -f "${bin}" && -x "${bin}" ]]; then
                echo "${bin}"
                return 0
            fi
        else
            if command -v "${bin}" >/dev/null 2>&1; then
                command -v "${bin}"
                return 0
            fi
        fi
    done

    # Check running processes
    if pgrep -x "ly" >/dev/null 2>&1; then
        echo "(running process 'ly')"
        return 0
    elif pgrep -x "ly-dm" >/dev/null 2>&1; then
        echo "(running process 'ly-dm')"
        return 0
    fi

    return 1
}

# Systemd service discovery
find_ly_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    local units=(
        "ly@tty1.service"
        "ly@tty2.service"
        "ly.service"
        "ly@.service"
        "ly-kmsconvt@.service"
    )

    for unit in "${units[@]}"; do
        if systemctl is-enabled "${unit}" >/dev/null 2>&1; then
            echo "${unit} (enabled)"
            return 0
        elif systemctl is-active "${unit}" >/dev/null 2>&1; then
            echo "${unit} (active)"
            return 0
        fi
    done

    # Check if any unit file exists
    for unit in "${units[@]}"; do
        if systemctl list-unit-files "${unit}" 2>/dev/null | grep -q "${unit}"; then
            echo "${unit} (available, disabled)"
            return 0
        fi
    done

    return 1
}

DETECTED_BIN="$(find_ly_binary || true)"
DETECTED_SERVICE="$(find_ly_service || true)"

# Check / Audit mode
if [[ "${CHECK_ONLY}" == true ]]; then
    log_info "Performing configuration and service audit..."
    if [[ -n "${DETECTED_BIN}" ]]; then
        log_success "Ly binary detected: ${DETECTED_BIN}"
    else
        log_warn "Ly binary was not found in common system paths or PATH."
    fi

    if [[ -n "${DETECTED_SERVICE}" ]]; then
        log_success "Ly service state: ${DETECTED_SERVICE}"
    else
        log_info "No enabled Ly systemd service detected."
    fi

    if [[ -f "${TARGET_STARTUP}" ]]; then
        log_success "Startup script exists at ${TARGET_STARTUP}"
        if grep -q "1E1E2E" "${TARGET_STARTUP}" 2>/dev/null; then
            log_success "Catppuccin Mocha TTY palette configured in ${TARGET_STARTUP}"
        fi
    else
        log_warn "No startup script found in ${TARGET_DIR}"
    fi

    if [[ -f "${TARGET_INI}" ]]; then
        log_success "INI config exists at ${TARGET_INI}"
        if grep -q "0x001e1e2e" "${TARGET_INI}" 2>/dev/null; then
            log_success "Catppuccin Mocha theme detected in ${TARGET_INI}"
        fi
        if grep -q "bigclock = en" "${TARGET_INI}" 2>/dev/null; then
            log_success "Central digital clock (bigclock) enabled in ${TARGET_INI}"
        fi
    fi

    if [[ -f "${TARGET_LUA}" ]]; then
        log_success "Lua config exists at ${TARGET_LUA}"
        if grep -q "0x001e1e2e" "${TARGET_LUA}" 2>/dev/null; then
            log_success "Catppuccin Mocha theme detected in ${TARGET_LUA}"
        fi
    fi

    exit 0
fi

# Ensure root privileges
if [[ "${DRY_RUN}" == false && "$(id -u)" -ne 0 ]]; then
    log_error "This script requires root privileges to modify ${TARGET_DIR}."
    printf "\nPlease run with sudo:\n  sudo %s\n\n" "$0"
    exit 1
fi

if [[ -n "${DETECTED_BIN}" ]]; then
    log_success "Found Ly binary: ${DETECTED_BIN}"
else
    log_warn "Could not automatically locate Ly binary in standard paths."
    log_info "Configuration files will still be deployed to ${TARGET_DIR}."
fi

# Handle dry-run mode
if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] Target directory: ${TARGET_DIR}"
    if [[ -f "${TARGET_STARTUP}" ]]; then
        log_info "[DRY-RUN] Would create backup: ${TARGET_STARTUP}.bak_$(date +%Y%m%d_%H%M%S)"
    fi
    if [[ -f "${TARGET_INI}" ]]; then
        log_info "[DRY-RUN] Would create backup: ${TARGET_INI}.bak_$(date +%Y%m%d_%H%M%S)"
    fi
    if [[ -f "${TARGET_LUA}" ]]; then
        log_info "[DRY-RUN] Would create backup: ${TARGET_LUA}.bak_$(date +%Y%m%d_%H%M%S)"
    fi
    log_info "[DRY-RUN] Would deploy startup.sh: ${SOURCE_STARTUP} -> ${TARGET_STARTUP} (mode 0755)"
    log_info "[DRY-RUN] Would deploy INI config: ${SOURCE_INI} -> ${TARGET_INI} (mode 0644)"
    log_info "[DRY-RUN] Would deploy Lua config: ${SOURCE_LUA} -> ${TARGET_LUA} (mode 0644)"
    log_success "[DRY-RUN] Simulation completed. No system changes made."
    exit 0
fi

# Ensure destination directory exists
if [[ ! -d "${TARGET_DIR}" ]]; then
    log_info "Creating target directory: ${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Backup existing startup script if present
if [[ -f "${TARGET_STARTUP}" ]]; then
    BACKUP_STARTUP="${TARGET_STARTUP}.bak_${TIMESTAMP}"
    log_info "Backing up existing startup script to: ${BACKUP_STARTUP}"
    cp -a "${TARGET_STARTUP}" "${BACKUP_STARTUP}"
    log_success "Backup preserved: ${BACKUP_STARTUP}"
fi

# Backup existing INI configuration if present
if [[ -f "${TARGET_INI}" ]]; then
    BACKUP_INI="${TARGET_INI}.bak_${TIMESTAMP}"
    log_info "Backing up existing INI configuration to: ${BACKUP_INI}"
    cp -a "${TARGET_INI}" "${BACKUP_INI}"
    log_success "Backup preserved: ${BACKUP_INI}"
fi

# Backup existing Lua configuration if present
if [[ -f "${TARGET_LUA}" ]]; then
    BACKUP_LUA="${TARGET_LUA}.bak_${TIMESTAMP}"
    log_info "Backing up existing Lua configuration to: ${BACKUP_LUA}"
    cp -a "${TARGET_LUA}" "${BACKUP_LUA}"
    log_success "Backup preserved: ${BACKUP_LUA}"
fi

# Deploy files
log_info "Deploying Catppuccin Mocha TTY startup palette script..."
install -m 0755 "${SOURCE_STARTUP}" "${TARGET_STARTUP}"

log_info "Deploying Catppuccin Mocha configuration (INI & Lua)..."
install -m 0644 "${SOURCE_INI}" "${TARGET_INI}"
install -m 0644 "${SOURCE_LUA}" "${TARGET_LUA}"

log_success "Configurations and startup scripts deployed to ${TARGET_DIR}."

# Service status and recommendations
if [[ -n "${DETECTED_SERVICE}" ]]; then
    log_success "Service status: ${DETECTED_SERVICE}"
else
    log_info "To enable Ly on boot, run:"
    if [[ -f "/usr/lib/systemd/system/ly@.service" || -f "/lib/systemd/system/ly@.service" ]]; then
        printf "    ${BOLD}sudo systemctl enable ly@tty1.service${RESET}\n"
    else
        printf "    ${BOLD}sudo systemctl enable ly.service${RESET}\n"
    fi

    # Check for competing display managers
    for dm in sddm gdm lightdm greetd; do
        if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled "${dm}.service" >/dev/null 2>&1; then
            log_warn "Conflicting display manager '${dm}.service' is currently enabled."
            log_warn "Disable it with: sudo systemctl disable ${dm}.service"
        fi
    done
fi

printf "\n${GREEN}${BOLD}✓ Ly display manager configuration complete!${RESET}\n"
printf "${BLUE}[NOTE]${RESET} Restart Ly (e.g. sudo systemctl restart ly@tty1.service) or reboot the machine\n"
printf "       to see the new Catppuccin Mocha palette and clock on your TTY.\n\n"

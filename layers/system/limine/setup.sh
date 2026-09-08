#!/usr/bin/env bash
# ==============================================================================
# Limine Bootloader - Catppuccin Mocha Palette Injector
# ==============================================================================
# Safely and idempotently applies the Catppuccin Mocha theme to limine.conf
# without altering kernel definitions, initramfs, UUIDs, or boot parameters.
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
THEMES_DIR="${SCRIPT_DIR}/themes"

THEME_NAME="mauve"
CUSTOM_CONFIG_PATH=""
DRY_RUN=false
CHECK_ONLY=false
AUTO_ENROLL=false

log_info()    { printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${RESET}   %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*"; }

usage() {
    cat <<USAGE
Usage: sudo $(basename "$0") [OPTIONS]

Options:
  -t, --theme <name>    Theme accent to apply: mauve (default), pink, blue
  -c, --config <path>   Explicit path to limine.conf
  -n, --dry-run         Simulate actions without modifying files
  -k, --check           Audit current Limine configuration and bootloader files
  -e, --enroll          Run limine-enroll-config after applying (for Secure Boot)
  -h, --help            Show this help message

Description:
  Applies the official Catppuccin Mocha palette to Limine's limine.conf.
  The script automatically locates the active configuration file in /boot,
  preserves an automatic timestamped backup (.bak_YYYYMMDD_HHMMSS), and
  injects the theme headers non-destructively.
USAGE
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--theme)
            THEME_NAME="$2"
            shift 2
            ;;
        -c|--config)
            CUSTOM_CONFIG_PATH="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -k|--check)
            CHECK_ONLY=true
            shift
            ;;
        -e|--enroll)
            AUTO_ENROLL=true
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

printf '%b\n' "${BOLD}================================================================${RESET}"
printf '%b\n' "${BOLD}       Limine Bootloader - Catppuccin Mocha Palette Injector    ${RESET}"
printf '%b\n\n' "${BOLD}================================================================${RESET}"

# Validate selected theme
THEME_FILE="${THEMES_DIR}/catppuccin-mocha-${THEME_NAME}.conf"
if [[ ! -f "${THEME_FILE}" ]]; then
    # Fallback check directly in limine directory
    if [[ -f "${SCRIPT_DIR}/catppuccin-mocha-${THEME_NAME}.conf" ]]; then
        THEME_FILE="${SCRIPT_DIR}/catppuccin-mocha-${THEME_NAME}.conf"
    elif [[ -f "${SCRIPT_DIR}/catppuccin-mocha.conf" && "${THEME_NAME}" == "mauve" ]]; then
        THEME_FILE="${SCRIPT_DIR}/catppuccin-mocha.conf"
    else
        log_error "Theme '${THEME_NAME}' not found. Available variants: mauve, pink, blue"
        exit 1
    fi
fi

# Function to detect limine.conf location
find_limine_config() {
    if [[ -n "${CUSTOM_CONFIG_PATH}" ]]; then
        if [[ -f "${CUSTOM_CONFIG_PATH}" ]]; then
            echo "${CUSTOM_CONFIG_PATH}"
            return 0
        else
            log_error "Specified config file does not exist: ${CUSTOM_CONFIG_PATH}"
            return 1
        fi
    fi

    local candidates=(
        "/boot/limine.conf"
        "/boot/limine/limine.conf"
        "/boot/efi/limine.conf"
        "/boot/efi/limine/limine.conf"
        "/boot/EFI/limine/limine.conf"
        "/boot/EFI/BOOT/limine.conf"
    )

    for path in "${candidates[@]}"; do
        if [[ -f "${path}" ]]; then
            echo "${path}"
            return 0
        fi
    done

    return 1
}

TARGET_CONFIG="$(find_limine_config || true)"

# Audit/Check mode
if [[ "${CHECK_ONLY}" == true ]]; then
    log_info "Performing Limine audit..."
    if command -v limine >/dev/null 2>&1; then
        log_success "Limine CLI tool found: $(command -v limine)"
    elif command -v limine-entry-tool >/dev/null 2>&1; then
        log_success "CachyOS limine-entry-tool found: $(command -v limine-entry-tool)"
    else
        log_warn "Neither 'limine' nor 'limine-entry-tool' found in PATH."
    fi

    if [[ -n "${TARGET_CONFIG}" && -f "${TARGET_CONFIG}" ]]; then
        log_success "Active limine.conf found at: ${TARGET_CONFIG}"
        if grep -q "1e1e2e" "${TARGET_CONFIG}" 2>/dev/null; then
            log_success "Catppuccin Mocha theme appears to be already present in ${TARGET_CONFIG}."
        else
            log_info "Configuration found, but default/other colors are currently used."
        fi
    else
        log_warn "No limine.conf detected in standard /boot locations."
    fi
    exit 0
fi

# Ensure root privileges when modifying system boot files
if [[ "${DRY_RUN}" == false && "$(id -u)" -ne 0 ]]; then
    if [[ -z "${TARGET_CONFIG}" || ! -w "${TARGET_CONFIG}" ]]; then
        log_error "Modifying bootloader configurations requires root privileges."
        printf "\nPlease run with sudo:\n  sudo %s\n\n" "$0"
        exit 1
    fi
fi

if [[ -z "${TARGET_CONFIG}" ]]; then
    if [[ "${DRY_RUN}" == true ]]; then
        log_warn "[DRY-RUN] No active limine.conf found in standard /boot locations on this machine."
        log_info "[DRY-RUN] On a machine with Limine installed, it will automatically detect and patch /boot/limine.conf."
        exit 0
    fi
    log_error "Could not find 'limine.conf' in any standard /boot location."
    log_info "If your configuration is in a custom path or mounted ESP partition, pass it with:"
    printf "    ${BOLD}sudo %s --config /path/to/limine.conf${RESET}\n\n" "$0"
    exit 1
fi

log_info "Target configuration: ${TARGET_CONFIG}"
log_info "Selected theme accent: ${THEME_NAME} (${THEME_FILE})"

# Dry-run preview
if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] Target file: ${TARGET_CONFIG}"
    log_info "[DRY-RUN] Would create backup: ${TARGET_CONFIG}.bak_$(date +%Y%m%d_%H%M%S)"
    log_info "[DRY-RUN] Theme block to inject:"
    printf "\n%s\n" "--- THEME PREVIEW ---"
    cat "${THEME_FILE}"
    printf "%s\n\n" "--- END THEME PREVIEW ---"
    log_success "[DRY-RUN] Simulation completed. No boot files modified."
    exit 0
fi

# Create timestamped backup
BACKUP_FILE="${TARGET_CONFIG}.bak_$(date +%Y%m%d_%H%M%S)"
log_info "Creating safety backup: ${BACKUP_FILE}"
cp -a "${TARGET_CONFIG}" "${BACKUP_FILE}"
log_success "Backup verified."

# Safely inject theme
TMP_CLEAN="$(mktemp)"
TMP_FINAL="$(mktemp)"

# Remove any existing Catppuccin block or legacy standalone term_* color options
sed -e '/# === CATPPUCCIN THEME START ===/,/# === CATPPUCCIN THEME END ===/d' \
    -e '/^[[:space:]]*term_palette[[:space:]]*:/d' \
    -e '/^[[:space:]]*term_palette_bright[[:space:]]*:/d' \
    -e '/^[[:space:]]*term_background[[:space:]]*:/d' \
    -e '/^[[:space:]]*term_foreground[[:space:]]*:/d' \
    -e '/^[[:space:]]*term_background_bright[[:space:]]*:/d' \
    -e '/^[[:space:]]*term_foreground_bright[[:space:]]*:/d' \
    -e '/^[[:space:]]*interface_branding_color[[:space:]]*:/d' \
    -e '/^[[:space:]]*interface_help_color[[:space:]]*:/d' \
    -e '/^[[:space:]]*interface_help_color_bright[[:space:]]*:/d' \
    "${TARGET_CONFIG}" > "${TMP_CLEAN}"

# Construct new limine.conf with theme header
{
    echo "# === CATPPUCCIN THEME START ==="
    cat "${THEME_FILE}"
    echo "# === CATPPUCCIN THEME END ==="
    echo ""
    sed '/./,$!d' "${TMP_CLEAN}"
} > "${TMP_FINAL}"

# Overwrite target configuration
cp "${TMP_FINAL}" "${TARGET_CONFIG}"
chmod 0644 "${TARGET_CONFIG}"
rm -f "${TMP_CLEAN}" "${TMP_FINAL}"

log_success "Catppuccin Mocha theme applied cleanly to ${TARGET_CONFIG}."

# Secure Boot check for CachyOS / Limine 11.2+
if command -v limine-enroll-config >/dev/null 2>&1; then
    if [[ "${AUTO_ENROLL}" == true ]]; then
        log_info "Enrolling updated configuration checksum with limine-enroll-config..."
        limine-enroll-config
        log_success "Secure Boot configuration checksum enrolled."
    else
        log_info "Note: If Secure Boot is enabled, update the config checksum by running:"
        printf '%b\n' "    ${BOLD}sudo limine-enroll-config${RESET}"
    fi
fi

printf '%b\n' "\n${GREEN}${BOLD}✓ Limine bootloader theme configuration complete!${RESET}"

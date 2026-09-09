#!/usr/bin/env bash
# ==============================================================================
# systemd-resolved - DNS-over-TLS (DoT) Setup & Installer
# ==============================================================================
# Safely configures systemd-resolved to use encrypted DNS-over-TLS (port 853).
# Supports presets (Cloudflare, Quad9, AdGuard, Mullvad) and custom providers.
# Provides automatic timestamped backups, dry-run simulation, and audit checks.
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
PROVIDERS_DIR="${SCRIPT_DIR}/providers"
TARGET_DIR="/etc/systemd/resolved.conf.d"
TARGET_CONF="${TARGET_DIR}/dns_over_tls.conf"

PROVIDER_NAME="quad9"
CUSTOM_ENDPOINTS=""
DRY_RUN=false
CHECK_ONLY=false
UNINSTALL=false
CLI_SPECIFIED_PROVIDER=false

log_info()    { printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${RESET}   %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*"; }

usage() {
    cat <<USAGE
Usage: sudo $(basename "$0") [OPTIONS]

Options:
  -p, --provider <name>   DNS provider preset: quad9 (default), cloudflare, cloudflare-security, adguard, mullvad, custom
  --custom <endpoints>    Space-separated custom DoT endpoints (e.g. "45.90.28.0#your-id.dns.nextdns.io")
  -n, --dry-run           Simulate configuration and service actions without modifying files
  -c, --check             Audit current DNS-over-TLS status and systemd-resolved service
  -u, --uninstall         Remove drop-in configuration and reload systemd-resolved
  -h, --help              Show this help message

Presets:
  quad9                Strong privacy and automatic threat/malware blocking (9.9.9.9, Default)
  cloudflare           Fast, general purpose (1.1.1.1)
  cloudflare-security  Automatic malware and phishing protection (1.1.1.2)
  adguard              Ad and tracker blocking at DNS level
  mullvad              Zero-logging, Swiss/Swedish privacy jurisdiction
  custom               Specify custom DoT endpoints (NextDNS, Pi-hole, personal resolver)

Description:
  Installs a drop-in systemd-resolved configuration to enforce DNS-over-TLS.
  All actions are idempotent and create timestamped backups on changes.
USAGE
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--provider)
            PROVIDER_NAME="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
            CLI_SPECIFIED_PROVIDER=true
            shift 2
            ;;
        --custom)
            CUSTOM_ENDPOINTS="$2"
            PROVIDER_NAME="custom"
            CLI_SPECIFIED_PROVIDER=true
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -u|--uninstall)
            UNINSTALL=true
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
printf '%b\n' "${BOLD}        systemd-resolved - DNS-over-TLS (DoT) Installer         ${RESET}"
printf '%b\n\n' "${BOLD}================================================================${RESET}"

# Audit / Check Mode
if [[ "${CHECK_ONLY}" == true ]]; then
    log_info "Auditing systemd-resolved and DNS-over-TLS status..."

    # Check systemd-resolved service state
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet systemd-resolved.service 2>/dev/null; then
            log_success "systemd-resolved service: active (running)"
        else
            log_warn "systemd-resolved service: inactive or not running"
        fi

        if systemctl is-enabled --quiet systemd-resolved.service 2>/dev/null; then
            log_success "systemd-resolved service: enabled on boot"
        else
            log_warn "systemd-resolved service: not enabled on boot"
        fi
    else
        log_warn "systemctl command not found; skipping service check."
    fi

    # Check configuration drop-in file
    if [[ -f "${TARGET_CONF}" ]]; then
        log_success "Drop-in configuration exists at: ${TARGET_CONF}"
        if grep -q "DNSOverTLS=yes" "${TARGET_CONF}" 2>/dev/null; then
            log_success "DNSOverTLS=yes is active in configuration"
        else
            log_warn "DNSOverTLS=yes is not found in ${TARGET_CONF}"
        fi

        # Detect configured provider
        if grep -q "security.cloudflare-dns.com" "${TARGET_CONF}" 2>/dev/null; then
            log_success "Configured provider: Cloudflare Security (1.1.1.2)"
        elif grep -q "cloudflare-dns.com" "${TARGET_CONF}" 2>/dev/null; then
            log_success "Configured provider: Cloudflare Standard (1.1.1.1)"
        elif grep -q "dns.quad9.net" "${TARGET_CONF}" 2>/dev/null; then
            log_success "Configured provider: Quad9 (9.9.9.9)"
        elif grep -q "adguard-dns.com" "${TARGET_CONF}" 2>/dev/null; then
            log_success "Configured provider: AdGuard DNS"
        elif grep -q "dns.mullvad.net" "${TARGET_CONF}" 2>/dev/null; then
            log_success "Configured provider: Mullvad DNS"
        else
            log_info "Configured provider: Custom"
        fi
    else
        log_info "No drop-in configuration found at ${TARGET_CONF}"
    fi

    # Check resolvectl runtime status if available
    if command -v resolvectl >/dev/null 2>&1; then
        log_info "Querying runtime resolvectl protocols..."
        if resolvectl status 2>/dev/null | grep -q "+DNSOverTLS"; then
            log_success "Runtime DNS-over-TLS (+DNSOverTLS) is ACTIVE"
        else
            log_info "Runtime DNS-over-TLS is not currently active (-DNSOverTLS)"
        fi
    fi

    exit 0
fi

# Privilege check
if [[ "${DRY_RUN}" == false && "$(id -u)" -ne 0 ]]; then
    log_error "This script requires root privileges to modify ${TARGET_DIR}."
    printf "\nPlease run with sudo:\n  sudo %s\n\n" "$0"
    exit 1
fi

# Uninstall Mode
if [[ "${UNINSTALL}" == true ]]; then
    log_info "Uninstalling DNS-over-TLS drop-in configuration..."
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY-RUN] Would remove ${TARGET_CONF} if present."
        log_info "[DRY-RUN] Would restart systemd-resolved.service."
        exit 0
    fi

    if [[ -f "${TARGET_CONF}" ]]; then
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        BACKUP_FILE="${TARGET_CONF}.bak_${TIMESTAMP}"
        mv "${TARGET_CONF}" "${BACKUP_FILE}"
        log_info "Moved ${TARGET_CONF} to backup: ${BACKUP_FILE}"
    else
        log_info "No configuration file found at ${TARGET_CONF} to remove."
    fi

    if command -v systemctl >/dev/null 2>&1; then
        log_info "Restarting systemd-resolved service..."
        systemctl restart systemd-resolved.service || true
    fi

    log_success "DNS-over-TLS drop-in uninstalled successfully."
    exit 0
fi

# Interactive provider selection if not passed as CLI argument and running in terminal
if [[ "${CLI_SPECIFIED_PROVIDER}" == false && -t 0 ]]; then
    printf '%b\n' "${BOLD}Select DNS Provider for DNS-over-TLS:${RESET}"
    echo "  1) Quad9 (9.9.9.9) [Privacy & Threat Protection, Recommended Default]"
    echo "  2) Cloudflare Standard (1.1.1.1) [Fast, General Purpose]"
    echo "  3) Cloudflare Security (1.1.1.2) [Malware & Phishing Protection]"
    echo "  4) AdGuard DNS [Ad & Tracker Blocking]"
    echo "  5) Mullvad DNS [Strict Zero-Logs]"
    echo "  6) Custom DoT endpoint (NextDNS, Personal Resolver)"
    printf "\nEnter choice [1-6] (default: 1): "
    read -r choice
    case "${choice}" in
        1|"") PROVIDER_NAME="quad9" ;;
        2) PROVIDER_NAME="cloudflare" ;;
        3) PROVIDER_NAME="cloudflare-security" ;;
        4) PROVIDER_NAME="adguard" ;;
        5) PROVIDER_NAME="mullvad" ;;
        6)
            PROVIDER_NAME="custom"
            printf "Enter primary DoT endpoint (e.g. 45.90.28.0#your-id.dns.nextdns.io): "
            read -r CUSTOM_ENDPOINTS
            ;;
        *)
            log_warn "Invalid selection. Defaulting to Quad9."
            PROVIDER_NAME="quad9"
            ;;
    esac
fi

# Prepare source content
TEMP_SOURCE=""
cleanup() {
    if [[ -n "${TEMP_SOURCE}" && -f "${TEMP_SOURCE}" ]]; then
        rm -f "${TEMP_SOURCE}"
    fi
}
trap cleanup EXIT

if [[ "${PROVIDER_NAME}" == "custom" ]]; then
    if [[ -z "${CUSTOM_ENDPOINTS}" ]]; then
        log_error "Custom provider requested but no endpoints provided (use --custom '<ip#domain>')."
        exit 1
    fi
    TEMP_SOURCE="$(mktemp)"
    cat <<EOF > "${TEMP_SOURCE}"
# ==============================================================================
# Custom DNS-over-TLS Provider Configuration
# ==============================================================================
[Resolve]
DNS=${CUSTOM_ENDPOINTS}
FallbackDNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
DNSOverTLS=yes
DNSSEC=allow-downgrade
MulticastDNS=yes
LLMNR=resolve
Cache=yes
EOF
    SOURCE_CONF="${TEMP_SOURCE}"
    log_info "Using custom DNS-over-TLS endpoints: ${CUSTOM_ENDPOINTS}"
else
    SOURCE_CONF="${PROVIDERS_DIR}/${PROVIDER_NAME}.conf"
    if [[ ! -f "${SOURCE_CONF}" ]]; then
        log_error "Provider configuration not found: ${SOURCE_CONF}"
        log_info "Available providers in ${PROVIDERS_DIR}: $(ls -1 "${PROVIDERS_DIR}" | sed 's/\.conf//' | tr '\n' ' ')"
        exit 1
    fi
    log_info "Selected provider: ${BOLD}${PROVIDER_NAME}${RESET}"
fi

# Simulation / Dry-run Mode
if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] Target directory: ${TARGET_DIR}"
    if [[ -f "${TARGET_CONF}" ]]; then
        log_info "[DRY-RUN] Existing configuration detected. Would create backup: ${TARGET_CONF}.bak_$(date +%Y%m%d_%H%M%S)"
    fi
    log_info "[DRY-RUN] Would install provider [${PROVIDER_NAME}] -> ${TARGET_CONF}"
    log_info "[DRY-RUN] Would enable and restart systemd-resolved.service"
    log_success "[DRY-RUN] Simulation finished without errors."
    exit 0
fi

# Apply Mode (Privileged)
log_info "Deploying DNS-over-TLS configuration (${PROVIDER_NAME})..."

# Create target directory if needed
if [[ ! -d "${TARGET_DIR}" ]]; then
    log_info "Creating target directory: ${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
    chmod 0755 "${TARGET_DIR}"
fi

# Backup existing configuration if present and different
if [[ -f "${TARGET_CONF}" ]]; then
    if cmp -s "${SOURCE_CONF}" "${TARGET_CONF}"; then
        log_info "Configuration is already identical to [${PROVIDER_NAME}]. No changes required."
    else
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        BACKUP_FILE="${TARGET_CONF}.bak_${TIMESTAMP}"
        cp -a "${TARGET_CONF}" "${BACKUP_FILE}"
        log_info "Created backup: ${BACKUP_FILE}"
    fi
fi

# Copy configuration
cp "${SOURCE_CONF}" "${TARGET_CONF}"
chmod 0644 "${TARGET_CONF}"
log_success "Installed configuration to: ${TARGET_CONF}"

# Enable and restart service
if command -v systemctl >/dev/null 2>&1; then
    log_info "Enabling and restarting systemd-resolved.service..."
    systemctl enable systemd-resolved.service >/dev/null 2>&1 || true
    systemctl restart systemd-resolved.service
    log_success "systemd-resolved.service restarted successfully"
fi

# Verify active status
if command -v resolvectl >/dev/null 2>&1; then
    log_info "Verifying runtime DNS-over-TLS status..."
    if resolvectl status 2>/dev/null | grep -q "+DNSOverTLS"; then
        log_success "DNS-over-TLS is confirmed ACTIVE (+DNSOverTLS)"
    else
        log_info "Configuration loaded. Active interfaces may take a moment to refresh."
    fi
fi

printf '%b\n' "\n${GREEN}${BOLD}✓ DNS-over-TLS setup completed successfully (${PROVIDER_NAME})!${RESET}"

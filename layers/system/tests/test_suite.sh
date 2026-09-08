#!/usr/bin/env bash
# ==============================================================================
# dotfiles-system - Automated Test Suite
# ==============================================================================
# Tests shell syntax, configuration validity, and bootloader idempotency in an
# isolated, unprivileged environment.
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

pass() {
    TOTAL_TESTS=$(( TOTAL_TESTS + 1 ))
    PASSED_TESTS=$(( PASSED_TESTS + 1 ))
    printf '%b\n' "${GREEN}[PASS]${RESET} $*"
}

fail() {
    TOTAL_TESTS=$(( TOTAL_TESTS + 1 ))
    FAILED_TESTS=$(( FAILED_TESTS + 1 ))
    printf '%b\n' "${RED}[FAIL]${RESET} $*"
}

printf '%b\n' "\n${BOLD}================================================================${RESET}"
printf '%b\n' "${BOLD}         Running dotfiles-system Automated Test Suite           ${RESET}"
printf '%b\n\n' "${BOLD}================================================================${RESET}"

# ------------------------------------------------------------------------------
# 1. Shell Script Syntax Validation (bash -n)
# ------------------------------------------------------------------------------
printf '%b\n' "${BLUE}==> 1. Validating Shell Script Syntax (bash -n)...${RESET}"

for script in install.sh ly/setup.sh ly/startup.sh limine/setup.sh; do
    if bash -n "${REPO_DIR}/${script}"; then
        pass "Syntax valid: ${script}"
    else
        fail "Syntax error in: ${script}"
    fi
done

# ------------------------------------------------------------------------------
# 2. Lua Syntax Validation (if luajit or lua is available)
# ------------------------------------------------------------------------------
printf '%b\n' "\n${BLUE}==> 2. Validating Lua Configuration Syntax...${RESET}"

if command -v luajit >/dev/null 2>&1; then
    TMP_BYTECODE="$(mktemp)"
    if luajit -b "${REPO_DIR}/ly/config.lua" "${TMP_BYTECODE}" 2>/dev/null; then
        pass "Lua syntax valid: ly/config.lua (checked with luajit)"
    else
        fail "Lua syntax error in: ly/config.lua"
    fi
    rm -f "${TMP_BYTECODE}"
elif command -v lua >/dev/null 2>&1; then
    if lua -e "dofile('${REPO_DIR}/ly/config.lua')" >/dev/null 2>&1; then
        pass "Lua syntax valid: ly/config.lua (checked with lua)"
    else
        fail "Lua syntax error in: ly/config.lua"
    fi
else
    pass "Lua syntax check skipped (neither luajit nor lua found in PATH)"
fi

# ------------------------------------------------------------------------------
# 3. Ly Configuration & Startup Palette Assertions
# ------------------------------------------------------------------------------
printf '%b\n' "\n${BLUE}==> 3. Verifying Ly Theme & Startup Configuration...${RESET}"

LY_INI="${REPO_DIR}/ly/config.ini"
if grep -q "start_cmd = /etc/ly/startup.sh" "${LY_INI}" && \
   grep -q "bigclock = en" "${LY_INI}" && \
   grep -q "bg = 0x001e1e2e" "${LY_INI}" && \
   grep -q "border_fg = 0x00cba6f7" "${LY_INI}"; then
    pass "Ly config.ini contains expected Catppuccin Mocha tokens and clock settings"
else
    fail "Ly config.ini is missing required Catppuccin Mocha options or bigclock"
fi

LY_STARTUP="${REPO_DIR}/ly/startup.sh"
if grep -q "BLACK=\"1E1E2E\"" "${LY_STARTUP}" && \
   grep -q "DARK_MAGENTA=\"CBA6F7\"" "${LY_STARTUP}" && \
   grep -q "LIGHT_GRAY=\"CDD6F4\"" "${LY_STARTUP}"; then
    pass "Ly startup.sh contains 16-color Catppuccin Mocha TTY escape palette"
else
    fail "Ly startup.sh does not declare the expected Catppuccin Mocha TTY colors"
fi

# ------------------------------------------------------------------------------
# 4. Limine Theme File Assertions
# ------------------------------------------------------------------------------
printf '%b\n' "\n${BLUE}==> 4. Verifying Limine Theme Variants...${RESET}"

for variant in mauve pink blue; do
    theme_file="${REPO_DIR}/limine/themes/catppuccin-mocha-${variant}.conf"
    if [[ -f "${theme_file}" ]] && grep -q "term_background: 1e1e2e" "${theme_file}"; then
        pass "Theme variant valid: catppuccin-mocha-${variant}.conf"
    else
        fail "Theme variant missing or malformed: catppuccin-mocha-${variant}.conf"
    fi
done

# ------------------------------------------------------------------------------
# 5. Bootloader Idempotency & Safety Mock Test
# ------------------------------------------------------------------------------
printf '%b\n' "\n${BLUE}==> 5. Testing Limine Palette Injection & Strict Idempotency...${RESET}"

MOCK_DIR="$(mktemp -d)"
MOCK_CONF="${MOCK_DIR}/limine.conf"

cat <<'INNER_EOF' > "${MOCK_CONF}"
timeout: 5
default_entry: 1

/CachyOS Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    kernel_cmdline: root=UUID=847a988d-784f-4ba9-a78b-90f6707f18b3 rw quiet splash
    module_path: boot():/initramfs-linux-cachyos.img

/CachyOS Linux (fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    kernel_cmdline: root=UUID=847a988d-784f-4ba9-a78b-90f6707f18b3 rw
    module_path: boot():/initramfs-linux-cachyos-fallback.img
INNER_EOF

# Pass 1: Apply Mauve theme
"${REPO_DIR}/limine/setup.sh" --config "${MOCK_CONF}" --theme mauve >/dev/null

if grep -q "interface_branding_color: cba6f7" "${MOCK_CONF}" && \
   grep -q "root=UUID=847a988d-784f-4ba9-a78b-90f6707f18b3" "${MOCK_CONF}"; then
    pass "Pass 1: Theme applied cleanly and kernel UUIDs preserved"
else
    fail "Pass 1: Injected theme failed or corrupted kernel entries"
fi

# Pass 2: Re-apply Pink theme over Mauve
"${REPO_DIR}/limine/setup.sh" --config "${MOCK_CONF}" --theme pink >/dev/null

COUNT_START="$(grep -c "# === CATPPUCCIN THEME START ===" "${MOCK_CONF}" || true)"
if [[ "${COUNT_START}" -eq 1 ]] && \
   grep -q "interface_branding_color: f5c2e7" "${MOCK_CONF}" && \
   ! grep -q "cba6f7" "${MOCK_CONF}"; then
    pass "Pass 2: Replaced theme cleanly without duplicate blocks (idempotent)"
else
    fail "Pass 2: Theme injection caused block duplication or failed to replace previous palette"
fi

# Pass 3: Re-apply Blue theme over Pink
"${REPO_DIR}/limine/setup.sh" --config "${MOCK_CONF}" --theme blue >/dev/null

COUNT_START_3="$(grep -c "# === CATPPUCCIN THEME START ===" "${MOCK_CONF}" || true)"
if [[ "${COUNT_START_3}" -eq 1 ]] && \
   grep -q "interface_branding_color: 89b4fa" "${MOCK_CONF}" && \
   grep -q "/CachyOS Linux (fallback)" "${MOCK_CONF}"; then
    pass "Pass 3: Multiple successive theme switches verified 100% idempotent"
else
    fail "Pass 3: Repeated theme switches resulted in corrupted boot configuration"
fi

rm -rf "${MOCK_DIR}"

# ------------------------------------------------------------------------------
# 6. Diagnostic & Dry-Run CLI Flags
# ------------------------------------------------------------------------------
printf '%b\n' "\n${BLUE}==> 6. Testing Diagnostic & Dry-Run Flags...${RESET}"

if "${REPO_DIR}/install.sh" --check < /dev/null >/dev/null 2>&1; then
    pass "Master installer --check flag executed successfully"
else
    fail "Master installer --check flag failed"
fi

if "${REPO_DIR}/install.sh" --dry-run --all < /dev/null >/dev/null 2>&1; then
    pass "Master installer --dry-run --all executed without errors"
else
    fail "Master installer --dry-run --all returned an error"
fi

if "${REPO_DIR}/install.sh" --help < /dev/null >/dev/null 2>&1; then
    pass "Master installer --help flag executed successfully"
else
    fail "Master installer --help flag failed"
fi

# ------------------------------------------------------------------------------
# Final Test Summary
# ------------------------------------------------------------------------------
printf '%b\n' "\n${BOLD}================================================================${RESET}"
printf '%b\n' "${BOLD}                         Test Results                           ${RESET}"
printf '%b\n' "${BOLD}================================================================${RESET}"
printf "Total Tests:   %d\n" "${TOTAL_TESTS}"
printf '%b\n' "Passed Tests:  ${GREEN}${PASSED_TESTS}${RESET}"
printf '%b\n' "Failed Tests:  ${RED}${FAILED_TESTS}${RESET}"

if [[ "${FAILED_TESTS}" -eq 0 ]]; then
    printf '%b\n\n' "\n${GREEN}${BOLD}✓ All test assertions passed successfully!${RESET}"
    exit 0
else
    printf '%b\n\n' "\n${RED}${BOLD}✗ Some tests failed. Please review the output above.${RESET}"
    exit 1
fi

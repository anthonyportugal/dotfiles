-- ==============================================================================
-- Ly Display Manager Configuration (Lua Format - Ly >= 1.5.0 / master)
-- Palette: Catppuccin Mocha
-- Documentation: https://codeberg.org/fairyglade/ly
-- ==============================================================================

ly = {
    -- ==========================================================================
    -- Visual & Aesthetic Settings (Catppuccin Mocha)
    -- ==========================================================================

    -- Enable 24-bit true color mode
    full_color = true,

    -- Background color (Mocha Base #1e1e2e)
    bg = 0x001e1e2e,

    -- Text / Foreground color (Mocha Text #cdd6f4)
    fg = 0x00cdd6f4,

    -- Main box border color (Mocha Mauve #cba6f7)
    border_fg = 0x00cba6f7,

    -- Error message colors (Mocha Red #f38ba8, bold)
    error_fg = 0x01f38ba8,
    error_bg = 0x001e1e2e,

    -- Fill background of the main dialog box
    blank_box = true,

    -- Display borders around the login dialog
    hide_borders = false,

    -- Show Ly version string in the top-left corner
    hide_version_string = false,

    -- Show function key hints (F1 Shutdown, F2 Restart, etc.)
    hide_key_hints = false,

    -- ==========================================================================
    -- Clock & Time
    -- ==========================================================================

    -- Top-right corner clock format (strftime format: Day DD Mon HH:MM)
    clock = "%a %d %b %H:%M",

    -- Large ASCII big clock (disabled in favor of minimal top-right clock)
    bigclock = "en",
    bigclock_12hr = false,
    bigclock_seconds = false,

    -- ==========================================================================
    -- Animations (Disabled for clean, instantaneous boot)
    -- ==========================================================================

    animation = "none",
    animation_frame_delay = 5,
    animation_timeout_sec = 0,

    -- ==========================================================================
    -- Authentication & Inputs
    -- ==========================================================================

    -- Password masking character
    asterisk = '*',

    -- Erase entered password buffer on failed authentication
    clear_password = true,

    -- Number of failed logins before Easter egg animation
    auth_fails = 10,

    -- Input box active by default on startup (session, login, password)
    default_input = "login",

    -- Input field length in characters
    input_len = 34,

    -- Dialog box margins
    margin_box_h = 2,
    margin_box_v = 1,

    -- Save directory for last desktop and login
    save_file_dir = "/etc/ly",

    -- Allow empty password (disabled for security)
    allow_empty_password = false,

    -- ==========================================================================
    -- Sessions & Environment
    -- ==========================================================================

    waylandsessions = "/usr/share/wayland-sessions",
    xsessions = "/usr/share/xsessions",
    xinitrc = "~/.xinitrc",

    -- Show shell console session in the session list
    shell = true,

    -- Center the session name
    text_in_center = false,

    -- Default system PATH
    path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",

    -- ==========================================================================
    -- Power Management & Shortcuts
    -- ==========================================================================

    shutdown_key = "F1",
    shutdown_cmd = "/sbin/shutdown -h now",

    restart_key = "F2",
    restart_cmd = "/etc/ly/startup.sh",

    sleep_key = "F3",
    sleep_cmd = nil,

    hibernate_key = "F4",
    hibernate_cmd = nil,

    show_password_key = "F7",
}

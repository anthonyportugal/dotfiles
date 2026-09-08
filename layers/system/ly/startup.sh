#!/bin/sh
# ==============================================================================
# Ly Display Manager - TTY Palette Setup Script
# ==============================================================================
# Executes before Ly takes control of the TTY.
# Transforms the standard 16-color Linux kernel console palette into Catppuccin Mocha.
# ==============================================================================

if [ "$TERM" = "linux" ]; then
    # Catppuccin Mocha Palette (16 ANSI colors for Linux VT)
    BLACK="1E1E2E"        # Color 0:  Base (Background)
    DARK_RED="F38BA8"     # Color 1:  Red
    DARK_GREEN="A6E3A1"   # Color 2:  Green
    DARK_YELLOW="F9E2AF"  # Color 3:  Yellow
    DARK_BLUE="89B4FA"    # Color 4:  Blue
    DARK_MAGENTA="CBA6F7" # Color 5:  Mauve (Border & Accents)
    DARK_CYAN="94E2D5"    # Color 6:  Teal
    LIGHT_GRAY="CDD6F4"   # Color 7:  Text (Default Foreground)
    DARK_GRAY="585B70"    # Color 8:  Surface2
    RED="F38BA8"          # Color 9:  Bright Red
    GREEN="A6E3A1"        # Color 10: Bright Green
    YELLOW="F9E2AF"       # Color 11: Bright Yellow
    BLUE="89B4FA"         # Color 12: Bright Blue
    MAGENTA="F5C2E7"      # Color 13: Pink
    CYAN="89DCEB"         # Color 14: Sky
    WHITE="FFFFFF"        # Color 15: Bright White

    COLORS="${BLACK} ${DARK_RED} ${DARK_GREEN} ${DARK_YELLOW} ${DARK_BLUE} ${DARK_MAGENTA} ${DARK_CYAN} ${LIGHT_GRAY} ${DARK_GRAY} ${RED} ${GREEN} ${YELLOW} ${BLUE} ${MAGENTA} ${CYAN} ${WHITE}"

    i=0
    for col in $COLORS; do
        printf "\033]P%x%s" $i "$col"
        i=$(( i + 1 ))
    done

    # Clear screen to eliminate background artifacting with new palette
    clear
fi

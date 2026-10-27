#!/usr/bin/env bash
# lib/wizard.sh - Interactive setup wizard and prompt helpers for dotfiles
#
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

wizard_colors() {
  setup_colors
}

prompt_choice() {
  local var_name=$1
  local title=$2
  shift 2
  local -a options=("$@")
  local choice=""

  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$title" "$C_RESET"
  local i=1
  for opt in "${options[@]}"; do
    printf '  %b[%d]%b %s\n' "$C_PINK" "$i" "$C_RESET" "$opt"
    (( i++ ))
  done

  while true; do
    printf '%b%s (1-%d): %b' "$C_BLUE" "$(_t "Select an option" "Selecciona una opción")" "${#options[@]}" "$C_RESET"
    read -r choice || return 1
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf -v "$var_name" '%d' "$(( choice - 1 ))"
      return 0
    fi
    printf '%b%s%b\n' "$C_RED" "$(_t "Invalid option. Please try again." "Opción inválida. Intenta nuevamente.")" "$C_RESET"
  done
}

prompt_yes_no() {
  local question=$1
  local default_val=${2:-Y}
  local response=""
  local prompt_suffix="[Y/n]"
  [[ "$default_val" =~ ^[Nn]$ ]] && prompt_suffix="[y/N]"
  if [[ "${DOTFILES_LANG:-en}" == "es" ]]; then
    prompt_suffix="[S/n]"
    [[ "$default_val" =~ ^[Nn]$ ]] && prompt_suffix="[s/N]"
  fi

  while true; do
    printf '%b%s %b%s%b ' "${C_BOLD}" "$question" "${C_SUBTEXT}" "$prompt_suffix" "$C_RESET"
    read -r response || return 1
    if [[ -z "$response" ]]; then
      response=$default_val
    fi
    case "$response" in
      [yY]|[yY][eE][sS]|[sS]|[sS][iI])
        return 0
        ;;
      [nN]|[nN][oO])
        return 1
        ;;
      *)
        printf '%b%s%b\n' "$C_RED" "$(_t "Please answer Y or N." "Por favor responde S o N.")" "$C_RESET"
        ;;
    esac
  done
}

prompt_input() {
  local prompt_text=$1
  local default_text=${2-}
  local var_name=$3
  local -n result_ref=$var_name
  local input_val=""

  if [[ -n "$default_text" ]]; then
    printf '%b%s %b[%s]: %b' "${C_BOLD}" "$prompt_text" "${C_SUBTEXT}" "$default_text" "$C_RESET"
  else
    printf '%b%s: %b' "${C_BOLD}" "$prompt_text" "$C_RESET"
  fi
  read -r input_val || return 1
  if [[ -z "$input_val" ]]; then
    result_ref=$default_text
  else
    result_ref=$input_val
  fi
}

wizard_clone_if_missing() {
  local repo_name=$1
  local default_url_https=$2
  local default_url_ssh=$3
  local target_dest=$4

  if [[ -d "$target_dest" ]]; then
    return 0
  fi

  printf '\n%b%s no está presente en %s.%b\n' "$C_YELLOW" "$repo_name" "$target_dest" "$C_RESET"
  if prompt_yes_no "¿Deseas clonarlo automáticamente desde GitHub?" Y; then
    local proto_choice=0
    prompt_choice proto_choice "¿Qué protocolo deseas usar?" \
      "HTTPS (Recomendado / Sin llaves SSH previas)" \
      "SSH (Requiere claves SSH activas en GitHub)"
    local clone_url="$default_url_https"
    if (( proto_choice == 1 )); then
      clone_url="$default_url_ssh"
    fi

    info "Clonando $repo_name ($clone_url) en $target_dest..."
    mkdir -p "$(dirname "$target_dest")"
    if git clone "$clone_url" "$target_dest"; then
      info "$repo_name clonado exitosamente."
      return 0
    else
      warn "No se pudo clonar $repo_name automáticamente."
      return 1
    fi
  fi
  return 1
}

prettify_path() {
  local p=${1:-}
  local clean
  clean="$(cd -P "$p" 2>/dev/null && pwd -P)" || clean="$p"
  [[ "$clean" == "$HOME"* ]] && clean="~${clean#"$HOME"}"
  printf '%s' "$clean"
}

# Picks the private overlay: an existing checkout with layers/, or a Git URL
# cloned into ~/.dotfiles-private. Returns 1 when none was chosen.
wizard_choose_overlay() {
  local candidate existing="" url="" dest="$TARGET_DIR/.dotfiles-private"

  for candidate in "$OVERLAY_PATH" "$dest" "$REPO_ROOT/../dotfiles-private"; do
    [[ -n "$candidate" && -d "$candidate/layers" ]] || continue
    existing=$candidate
    break
  done
  if [[ -n "$existing" ]]; then
    if prompt_yes_no "$(_t "Overlay detected at $(prettify_path "$existing"). Apply it?" "Overlay detectado en $(prettify_path "$existing"). ¿Aplicarlo?")" Y; then
      OVERLAY_PATH=$existing
      OVERLAY_EXPLICIT=1
      return 0
    fi
    NO_OVERLAY=1
    return 1
  fi

  prompt_input "$(_t "Git URL of your private overlay, cloned into ~/.dotfiles-private (ENTER to skip)" "URL Git de tu overlay privado, se clona en ~/.dotfiles-private (ENTER para omitir)")" "" url
  [[ -n "$url" ]] || return 1
  if git clone "$url" "$dest"; then
    OVERLAY_PATH=$dest
    OVERLAY_EXPLICIT=1
    return 0
  fi
  warn "$(_t "Could not clone the overlay. Continuing without it." "No se pudo clonar el overlay. Se continúa sin él.")"
  return 1
}

run_interactive_wizard() {
  wizard_colors

  if [[ -z "${DOTFILES_LANG:-}" ]]; then
    clear 2>/dev/null || true
    local lang_choice=0
    prompt_choice lang_choice "Select language / Selecciona el idioma" \
      "English [Default]" \
      "Español"
    if (( lang_choice == 1 )); then
      DOTFILES_LANG="es"
    else
      DOTFILES_LANG="en"
    fi
    export DOTFILES_LANG
  fi

  clear 2>/dev/null || true
  printf '%b' "$C_MAUVE"
  cat <<'EOF'
╭─────────────────────────────────────────────────────────────╮
│                      ANTHONY PORTUGAL                       │
│                 dotfiles-base • Setup Wizard                │
│           Modular Arch Linux Configuration System           │
│ ╰─────────────────────────────────────────────────────────────╯
EOF
  printf '%b\n' "$C_RESET"

  printf '%b%s%b\n' "${C_BOLD}" "$(_t "Detected environment:" "Estado actual detectado:")" "$C_RESET"
  printf '  • Base:     %b[✓ %s]%b (%s)\n' "$C_GREEN" "$(_t "Present" "Presente")" "$C_RESET" "$(prettify_path "$REPO_ROOT")"

  local mango_dir=""
  [[ ! -f "$LAYERS_DIR/wm/mangowm/layer.conf" ]] || mango_dir="$LAYERS_DIR/wm/mangowm"
  local mango_status
  mango_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$mango_dir" ]] && mango_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • MangoWM:  %b\n' "$mango_status"

  local bspwm_dir=""
  [[ ! -f "$LAYERS_DIR/wm/bspwm/layer.conf" ]] || bspwm_dir="$LAYERS_DIR/wm/bspwm"
  local bspwm_status
  bspwm_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$bspwm_dir" ]] && bspwm_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • BSPWM:    %b\n' "$bspwm_status"

  local walls_dir=""
  if [[ -d "$REPO_ROOT/../walls" ]]; then
    walls_dir="$REPO_ROOT/../walls"
  elif [[ -d "$TARGET_DIR/.dotfiles/walls" ]]; then
    walls_dir="$TARGET_DIR/.dotfiles/walls"
  fi
  local walls_status
  walls_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$walls_dir" ]] && walls_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • Walls:    %b\n' "$walls_status"

  # The system layer ships in this repository; show whether it was applied.
  local system_status
  local -A system_saved=()
  system_status="${C_SUBTEXT}[$(_t "Optional, not applied" "Opcional, sin aplicar")]${C_RESET}"
  if read_receipt system system_saved; then
    system_status="${C_GREEN}[✓ ${system_saved[SYSTEM_ARGS]:-}]${C_RESET}"
  fi
  printf '  • System:   %b\n' "$system_status"

  local -A overlay_saved=()
  local overlay_status
  overlay_status="${C_SUBTEXT}[$(_t "Not configured" "Sin configurar")]${C_RESET}"
  if read_receipt dotfiles overlay_saved && [[ -n "${overlay_saved[OVERLAY]:-}" ]]; then
    overlay_status="${C_GREEN}[✓ $(prettify_path "${overlay_saved[OVERLAY]}")]${C_RESET}"
  fi
  printf '  • Overlay:  %b\n' "$overlay_status"

  local action_choice=0
  prompt_choice action_choice "$(_t "What would you like to do?" "¿Qué deseas hacer?")" \
    "$(_t "Guided Full Setup (Step-by-step onboarding for Base + Modules)" "Asistente de Configuración Guiada (Instalación por capas)")" \
    "$(_t "Configure Base System Profile Only" "Configurar solo Perfil Base del Sistema")" \
    "$(_t "Configure MangoWM (Wayland Environment)" "Configurar MangoWM (Entorno Wayland)")" \
    "$(_t "Configure BSPWM (X11 Environment)" "Configurar BSPWM (Entorno X11)")" \
    "$(_t "Configure System Layer (Ly, Limine, DNS-over-TLS)" "Configurar Capa del Sistema (Ly, Limine, DNS)")" \
    "$(_t "Configure Private Overlay (Identity, SSH, Work)" "Configurar Overlay Privado (Identidad, SSH, Laboral)")" \
    "$(_t "Configure Wallpapers (walls)" "Configurar Fondos de Pantalla (walls)")" \
    "$(_t "Re-sync Local Environment (Sync links and packages)" "Re-sincronizar Entorno Local (Sync enlaces y paquetes)")" \
    "$(_t "Update from GitHub (Remote Update + Sync)" "Actualizar desde GitHub (Remote Update + Sync)")" \
    "$(_t "Health Diagnostics (Doctor)" "Diagnóstico de Salud (Doctor)")" \
    "$(_t "Unlink Dotfiles" "Retirar Enlaces (Unlink)")" \
    "$(_t "Exit" "Salir")"

  case "$action_choice" in
    1) # Configure Base Profile Only
      local b_profile=2
      prompt_choice b_profile "$(_t "Select Base System Profile" "Selecciona el Perfil Base del Sistema")" \
        "$(_t "Core (Zsh, Git, essential CLI tools)" "Core (Zsh, Git, herramientas esenciales de terminal)")" \
        "$(_t "CLI (Core + Micro, Yazi, Neovim/modern CLI tools)" "CLI (Core + Micro, Yazi, Neovim/herramientas modernas)")" \
        "$(_t "Desktop [Recommended] (CLI + Catppuccin GTK theme, fonts, audio, portals)" "Desktop [Recomendado] (CLI + Tema GTK Catppuccin, fuentes, audio, portales)")"
      case "$b_profile" in
        0) PROFILE="core" ;;
        1) PROFILE="cli" ;;
        2) PROFILE="desktop" ;;
      esac
      local b_mode=0
      prompt_choice b_mode "$(_t "Select Installation Scope" "Selecciona el Alcance de la Instalación")" \
        "$(_t "Complete: Install packages (repo/AUR) + Deploy Stow symlinks [Recommended]" "Completo: Instalar paquetes (repo/AUR) + Enlaces Stow [Recomendado]")" \
        "$(_t "Symlinks only: Deploy Stow symlinks only (No package install / No sudo)" "Solo enlaces: Enlazar dotfiles con Stow (Sin tocar paquetes / Sin sudo)")"
      if (( b_mode == 1 )); then
        MODE_SELECTION="stow"
        SYSTEM_ENABLED=0
        STOW_ENABLED=1
      else
        MODE_SELECTION="both"
        SYSTEM_ENABLED=1
        STOW_ENABLED=1
      fi
      local b_act=0
      prompt_choice b_act "$(_t "How would you like to proceed?" "¿Cómo deseas proceder?")" \
        "$(_t "Apply changes now (--apply)" "Aplicar los cambios ahora mismo (--apply)")" \
        "$(_t "Dry-run simulation" "Simulación previa (Dry-Run)")" \
        "$(_t "Cancel and exit" "Cancelar y salir")"
      case "$b_act" in
        0) APPLY=1 ;;
        1) APPLY=0 ;;
        2) return 0 ;;
      esac
      COMMAND="bootstrap"
      bootstrap_with_optional_components
      return 0
      ;;
    2|3) # Window manager layer (with the base it builds on)
      local wm_name="mangowm"
      (( action_choice == 3 )) && wm_name="bspwm"
      [[ -f "$LAYERS_DIR/wm/$wm_name/layer.conf" ]] || {
        error "$(_t "WM layer not found: $LAYERS_DIR/wm/$wm_name" "Capa de WM no encontrada: $LAYERS_DIR/wm/$wm_name")"
        return 1
      }
      WMS=("$wm_name")
      local wm_act=0
      prompt_choice wm_act "$(_t "How would you like to proceed?" "¿Cómo deseas proceder?")" \
        "$(_t "Apply changes now (--apply)" "Aplicar los cambios ahora mismo (--apply)")" \
        "$(_t "Dry-run simulation" "Simulación previa (Dry-Run)")" \
        "$(_t "Cancel and exit" "Cancelar y salir")"
      case "$wm_act" in
        0) APPLY=1 ;;
        1) APPLY=0 ;;
        2) return 0 ;;
      esac
      COMMAND="bootstrap"
      resolve_wm_layers
      bootstrap_with_optional_components
      return 0
      ;;
    4) # System setup
      # A subshell keeps a failing installer from ending the wizard.
      ( cmd_system setup ) || \
        warn "$(_t "The system layer was not applied" "La capa system no se aplicó")"
      return 0
      ;;
    5) # Private overlay: choose it, then re-apply the saved selection with it.
      if wizard_choose_overlay; then
        sync_environment
      fi
      return 0
      ;;
    6) # Wallpapers setup
      local w_path="${walls_dir:-$TARGET_DIR/.dotfiles/walls}"
      if [[ ! -d "$w_path" ]]; then
        wizard_clone_if_missing "walls" \
          "https://github.com/anthonyportugal/walls.git" \
          "git@github.com:anthonyportugal/walls.git" \
          "$w_path" || return 1
      fi
      if [[ -x "$w_path/bin/walls" ]]; then
        "$w_path/bin/walls" setup --lang "$DOTFILES_LANG"
      else
        error "$(_t "Walls executable not found in $w_path" "Ejecutable walls no encontrado en $w_path")"
      fi
      return 0
      ;;
    7)
      sync_environment || true
      return 0
      ;;
    8)
      update_from_remote || true
      return 0
      ;;
    9)
      cmd_doctor || true
      return 0
      ;;
    10)
      unlink_with_optional_components || true
      return 0
      ;;
    11)
      info "$(_t "Goodbye!" "¡Hasta luego!")"
      return 0
      ;;
  esac

  printf '\n%b=== %s ===%b\n' "${C_BOLD}${C_PINK}" "$(_t "GUIDED MODULAR SETUP" "ASISTENTE DE CONFIGURACIÓN POR CAPAS")" "$C_RESET"

  local profile_choice=2
  prompt_choice profile_choice "$(_t "Step 1: Select Base System Profile" "Paso 1: Selecciona el Perfil Base del Sistema")" \
    "$(_t "Core (Zsh, Git, essential CLI tools)" "Core (Zsh, Git, herramientas esenciales de terminal)")" \
    "$(_t "CLI (Core + Micro, Yazi, Neovim/modern CLI tools)" "CLI (Core + Micro, Yazi, Neovim/herramientas modernas)")" \
    "$(_t "Desktop [Recommended] (CLI + Catppuccin GTK theme, fonts, audio, portals)" "Desktop [Recomendado] (CLI + Tema GTK Catppuccin, fuentes, audio, portales)")"
  case "$profile_choice" in
    0) PROFILE="core" ;;
    1) PROFILE="cli" ;;
    2) PROFILE="desktop" ;;
  esac

  WMS=()
  local wm_choice=0
  prompt_choice wm_choice "$(_t "Step 2: Select Window Managers to configure" "Paso 2: Selecciona los Entornos de Ventana a configurar")" \
    "MangoWM (Wayland + Waybar + Fuzzel + Mako)" \
    "BSPWM (X11 + Polybar + Rofi + Dunst + Picom)" \
    "$(_t "Both (MangoWM and BSPWM)" "Ambos (MangoWM y BSPWM)")" \
    "$(_t "None (Terminal only / Bring your own WM)" "Ninguno (Solo terminal / Ya poseo mi propio gestor)")"

  case "$wm_choice" in
    0) append_unique WMS "mangowm" ;;
    1) append_unique WMS "bspwm" ;;
    2) append_unique WMS "mangowm"; append_unique WMS "bspwm" ;;
    3) ;;
  esac

  WALLPAPERS=0
  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$(_t "Step 3: Wallpaper Collection (walls)" "Paso 3: Colección de Fondos de Pantalla (walls)")" "$C_RESET"
  if prompt_yes_no "$(_t "Integrate wallpaper collection (anthonyportugal/walls)?" "¿Deseas integrar la colección de wallpapers (anthonyportugal/walls)?")" Y; then
    WALLPAPERS=1
    local walls_dest="$TARGET_DIR/.dotfiles/walls"
    wizard_clone_if_missing "walls" \
      "https://github.com/anthonyportugal/walls.git" \
      "git@github.com:anthonyportugal/walls.git" \
      "$walls_dest" || true
    if [[ -x "$walls_dest/bin/walls" ]]; then
      if prompt_yes_no "$(_t "Run Wallpapers setup wizard now?" "¿Ejecutar el asistente de wallpapers ahora?")" Y; then
        "$walls_dest/bin/walls" setup --lang "$DOTFILES_LANG" || true
      fi
    fi
  fi

  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$(_t "Step 4: Optional System Layer (Ly, Limine & DNS-over-TLS, needs sudo)" "Paso 4: Capa de Sistema Opcional (Ly, Limine y DNS-over-TLS, requiere sudo)")" "$C_RESET"
  if prompt_yes_no "$(_t "Run the system layer installer now? (sudo; also later with 'dotfiles system')" "¿Ejecutar ahora el instalador de la capa system? (sudo; también luego con 'dotfiles system')")" N; then
    ( cmd_system setup ) || \
      warn "$(_t "The system layer was not applied" "La capa system no se aplicó")"
  fi

  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$(_t "Step 5: Private Overlay (your own layers: identity, SSH, work)" "Paso 5: Overlay Privado (tus propias capas: identidad, SSH, trabajo)")" "$C_RESET"
  if ! wizard_choose_overlay; then
    if prompt_yes_no "$(_t "Configure local Git identity (user.name and user.email)?" "¿Deseas configurar tu identidad Git local (user.name y user.email)?")" Y; then
      local git_name="" git_email=""
      prompt_input "$(_t "Git Name" "Nombre para Git")" "" git_name
      prompt_input "$(_t "Git Email" "Email para Git")" "" git_email
      if [[ -n "$git_name" && -n "$git_email" ]]; then
        mkdir -p "$TARGET_DIR/.config/git"
        git config --file "$TARGET_DIR/.config/git/local.gitconfig" user.name "$git_name"
        git config --file "$TARGET_DIR/.config/git/local.gitconfig" user.email "$git_email"
        info "$(_t "Git identity saved to ~/.config/git/local.gitconfig" "Identidad Git guardada en ~/.config/git/local.gitconfig")"
      fi
    fi
  fi

  local mode_choice=0
  prompt_choice mode_choice "$(_t "Step 6: Select Base System Installation Scope" "Paso 6: Selecciona el Alcance de la Instalación Base")" \
    "$(_t "Complete: Install base packages (repo/AUR) + Deploy Stow symlinks [Recommended]" "Completo: Instalar paquetes del sistema (repo/AUR) + Enlaces Stow [Recomendado]")" \
    "$(_t "Symlinks only: Deploy Stow dotfiles symlinks only (No package install / No sudo)" "Solo enlaces: Enlazar dotfiles con Stow (Sin tocar paquetes / Sin sudo)")"
  if (( mode_choice == 1 )); then
    MODE_SELECTION="stow"
    SYSTEM_ENABLED=0
    STOW_ENABLED=1
  else
    MODE_SELECTION="both"
    SYSTEM_ENABLED=1
    STOW_ENABLED=1
  fi

  printf '\n%b' "$C_BLUE"
  cat <<EOF
╭─────────────────────────────────────────────────────────────╮
│               BASE REPO INSTALLATION SUMMARY                │
├─────────────────────────────────────────────────────────────┤
EOF
  printf '│  • %-20s %-33s│\n' "$(_t "Base Profile:" "Perfil Base:")" "$PROFILE"
  local wms_str="${WMS[*]:-(none)}"
  printf '│  • %-20s %-33s│\n' "$(_t "Window Managers:" "Window Managers:")" "$wms_str"
  local walls_str="No"
  (( WALLPAPERS == 1 )) && walls_str="$(_t "Yes" "Sí")"
  printf '│  • %-20s %-33s│\n' "$(_t "Wallpapers:" "Wallpapers:")" "$walls_str"
  local overlay_str="No"
  [[ -z "$OVERLAY_PATH" ]] || overlay_str=$(prettify_path "$OVERLAY_PATH")
  printf '│  • %-20s %-33s│\n' "$(_t "Private Overlay:" "Overlay Privado:")" "$overlay_str"
  printf '│  • %-20s %-33s│\n' "$(_t "Operation Mode:" "Modo de Operación:")" "$MODE_SELECTION"
  printf '│  • %-20s %-33s│\n' "$(_t "Target Home:" "Directorio Target:")" "$(prettify_path "$TARGET_DIR")"
  cat <<'EOF'
╰─────────────────────────────────────────────────────────────╯
EOF
  printf '%b\n' "$C_RESET"

  local final_choice=0
  prompt_choice final_choice "$(_t "Step 7: How would you like to proceed with Base?" "Paso 7: ¿Cómo deseas proceder con la Base?")" \
    "$(_t "Apply changes now (--apply)" "Aplicar los cambios ahora mismo (--apply)")" \
    "$(_t "Dry-run simulation (Check actions without modifying)" "Simulación previa (Dry-Run: ver qué se tocaría sin modificar)")" \
    "$(_t "Cancel and exit" "Cancelar y salir")"

  case "$final_choice" in
    0) APPLY=1 ;;
    1) APPLY=0 ;;
    2)
      info "$(_t "Operation cancelled by user." "Operación cancelada por el usuario.")"
      return 0
      ;;
  esac

  COMMAND="bootstrap"
  validate_wm_checkout
  validate_wallpapers_checkout
  bootstrap_with_optional_components
}

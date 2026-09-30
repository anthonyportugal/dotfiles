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
  if [[ -d "$REPO_ROOT/../wm/mangowm" ]]; then
    mango_dir="$REPO_ROOT/../wm/mangowm"
  elif [[ -d "$TARGET_DIR/.dotfiles/wm/mangowm" ]]; then
    mango_dir="$TARGET_DIR/.dotfiles/wm/mangowm"
  fi
  local mango_status
  mango_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$mango_dir" ]] && mango_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • MangoWM:  %b\n' "$mango_status"

  local bspwm_dir=""
  if [[ -d "$REPO_ROOT/../wm/bspwm" ]]; then
    bspwm_dir="$REPO_ROOT/../wm/bspwm"
  elif [[ -d "$TARGET_DIR/.dotfiles/wm/bspwm" ]]; then
    bspwm_dir="$TARGET_DIR/.dotfiles/wm/bspwm"
  fi
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

  local system_dir=""
  if [[ -d "$REPO_ROOT/../system" ]]; then
    system_dir="$REPO_ROOT/../system"
  elif [[ -d "$TARGET_DIR/.dotfiles/system" ]]; then
    system_dir="$TARGET_DIR/.dotfiles/system"
  fi
  local system_status
  system_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$system_dir" ]] && system_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • System:   %b\n' "$system_status"

  local private_dir=""
  if [[ -d "$REPO_ROOT/../private" ]]; then
    private_dir="$REPO_ROOT/../private"
  elif [[ -d "$TARGET_DIR/.dotfiles/private" ]]; then
    private_dir="$TARGET_DIR/.dotfiles/private"
  fi
  local private_status
  private_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$private_dir" ]] && private_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • Private:  %b\n' "$private_status"

  local harness_dir=""
  if [[ -d "$REPO_ROOT/../agent-harness" ]]; then
    harness_dir="$REPO_ROOT/../agent-harness"
  elif [[ -d "$TARGET_DIR/.dotfiles/agent-harness" ]]; then
    harness_dir="$TARGET_DIR/.dotfiles/agent-harness"
  fi
  local harness_status
  harness_status="${C_SUBTEXT}[$(_t "Not present" "No presente")]${C_RESET}"
  [[ -n "$harness_dir" ]] && harness_status="${C_GREEN}[✓ $(_t "Present" "Presente")]${C_RESET}"
  printf '  • Harness:  %b\n' "$harness_status"

  local action_choice=0
  prompt_choice action_choice "$(_t "What would you like to do?" "¿Qué deseas hacer?")" \
    "$(_t "Guided Full Setup (Step-by-step onboarding for Base + Modules)" "Asistente de Configuración Guiada (Instalación por capas)")" \
    "$(_t "Configure Base System Profile Only" "Configurar solo Perfil Base del Sistema")" \
    "$(_t "Configure MangoWM (Wayland Environment)" "Configurar MangoWM (Entorno Wayland)")" \
    "$(_t "Configure BSPWM (X11 Environment)" "Configurar BSPWM (Entorno X11)")" \
    "$(_t "Configure System Layer (Ly, Limine, DNS-over-TLS)" "Configurar Capa del Sistema (Ly, Limine, DNS)")" \
    "$(_t "Configure Private Layer (Identity, SSH, Work)" "Configurar Capa Privada (Identidad, SSH, Laboral)")" \
    "$(_t "Configure Wallpapers (walls)" "Configurar Fondos de Pantalla (walls)")" \
    "$(_t "Configure Agent Harness (AI Agents, Rules, MCP, Skills)" "Configurar Agent Harness (AI Agents, Rules, MCP, Skills)")" \
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
      bootstrap
      return 0
      ;;
    2) # MangoWM setup
      local m_path="${mango_dir:-$TARGET_DIR/.dotfiles/wm/mangowm}"
      if [[ ! -d "$m_path" ]]; then
        wizard_clone_if_missing "dotfiles-mangowm" \
          "https://github.com/anthonyportugal/dotfiles-mangowm.git" \
          "git@github.com:anthonyportugal/dotfiles-mangowm.git" \
          "$m_path" || return 1
      fi
      if [[ -x "$m_path/bin/mango" ]]; then
        "$m_path/bin/mango" setup --lang "$DOTFILES_LANG"
      else
        error "$(_t "MangoWM executable not found in $m_path" "Ejecutable MangoWM no encontrado en $m_path")"
      fi
      return 0
      ;;
    3) # BSPWM setup
      local b_path="${bspwm_dir:-$TARGET_DIR/.dotfiles/wm/bspwm}"
      if [[ ! -d "$b_path" ]]; then
        wizard_clone_if_missing "dotfiles-bspwm" \
          "https://github.com/anthonyportugal/dotfiles-bspwm.git" \
          "git@github.com:anthonyportugal/dotfiles-bspwm.git" \
          "$b_path" || return 1
      fi
      if [[ -x "$b_path/bin/bspwm" ]]; then
        "$b_path/bin/bspwm" setup --lang "$DOTFILES_LANG"
      else
        error "$(_t "BSPWM executable not found in $b_path" "Ejecutable BSPWM no encontrado en $b_path")"
      fi
      return 0
      ;;
    4) # System setup
      local s_path="${system_dir:-$TARGET_DIR/.dotfiles/system}"
      if [[ ! -d "$s_path" ]]; then
        wizard_clone_if_missing "dotfiles-system" \
          "https://github.com/anthonyportugal/dotfiles-system.git" \
          "git@github.com:anthonyportugal/dotfiles-system.git" \
          "$s_path" || return 1
      fi
      if [[ -f "$s_path/install.sh" ]]; then
        sudo "$s_path/install.sh" --lang "$DOTFILES_LANG"
      else
        error "$(_t "System installer not found in $s_path" "Instalador del sistema no encontrado en $s_path")"
      fi
      return 0
      ;;
    5) # Private setup
      local p_path="${private_dir:-$TARGET_DIR/.dotfiles/private}"
      if [[ -x "$p_path/bin/dotfiles-private" ]]; then
        "$p_path/bin/dotfiles-private" setup --lang "$DOTFILES_LANG"
      else
        warn "$(_t "Private repository not found in $p_path" "Repositorio privado no encontrado en $p_path")"
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
    7) # Agent Harness setup
      local h_path="${harness_dir:-$TARGET_DIR/.dotfiles/agent-harness}"
      if [[ ! -d "$h_path" ]]; then
        wizard_clone_if_missing "agent-harness" \
          "https://github.com/anthonyportugal/agent-harness.git" \
          "git@github.com:anthonyportugal/agent-harness.git" \
          "$h_path" || return 1
      fi
      if [[ -x "$h_path/bin/agent-harness" ]]; then
        "$h_path/bin/agent-harness" setup
      else
        error "$(_t "Agent Harness executable not found in $h_path" "Ejecutable agent-harness no encontrado en $h_path")"
      fi
      return 0
      ;;
    8)
      sync_environment || true
      return 0
      ;;
    9)
      update_from_remote || true
      return 0
      ;;
    10)
      doctor_with_optional_components || true
      return 0
      ;;
    11)
      unlink_with_optional_components || true
      return 0
      ;;
    12)
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

  local wm
  for wm in "${WMS[@]}"; do
    local wm_target_path="$TARGET_DIR/.dotfiles/wm/$wm"
    case "$wm" in
      mangowm)
        wizard_clone_if_missing "dotfiles-mangowm" \
          "https://github.com/anthonyportugal/dotfiles-mangowm.git" \
          "git@github.com:anthonyportugal/dotfiles-mangowm.git" \
          "$wm_target_path" || true
        if [[ -x "$wm_target_path/bin/mango" ]]; then
          if prompt_yes_no "$(_t "Run MangoWM setup wizard now?" "¿Ejecutar el asistente interactivo de MangoWM ahora?")" Y; then
            "$wm_target_path/bin/mango" setup --lang "$DOTFILES_LANG" || true
          fi
        fi
        ;;
      bspwm)
        wizard_clone_if_missing "dotfiles-bspwm" \
          "https://github.com/anthonyportugal/dotfiles-bspwm.git" \
          "git@github.com:anthonyportugal/dotfiles-bspwm.git" \
          "$wm_target_path" || true
        if [[ -x "$wm_target_path/bin/bspwm" ]]; then
          if prompt_yes_no "$(_t "Run BSPWM setup wizard now?" "¿Ejecutar el asistente interactivo de BSPWM ahora?")" Y; then
            "$wm_target_path/bin/bspwm" setup --lang "$DOTFILES_LANG" || true
          fi
        fi
        ;;
    esac
  done

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

  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$(_t "Step 4: System Layer (Ly, Limine & DNS-over-TLS in dotfiles-system)" "Paso 4: Capa del Sistema (Ly, Limine & DNS-over-TLS en dotfiles-system)")" "$C_RESET"
  local existing_system=""
  if [[ -d "$REPO_ROOT/../system" ]]; then
    existing_system="$REPO_ROOT/../system"
  elif [[ -d "$TARGET_DIR/.dotfiles/system" ]]; then
    existing_system="$TARGET_DIR/.dotfiles/system"
  fi

  if [[ -n "$existing_system" ]]; then
    if prompt_yes_no "$(_t "System layer detected at $(prettify_path "$existing_system"). Run its installer wizard now? (sudo)" "Capa del sistema detectada en $(prettify_path "$existing_system"). ¿Ejecutar su asistente ahora? (sudo)")" Y; then
      sudo "$existing_system/install.sh" --lang "$DOTFILES_LANG" || true
    fi
  else
    if prompt_yes_no "$(_t "Clone and run system installer (anthonyportugal/dotfiles-system)?" "¿Clonar y ejecutar instalador del sistema (anthonyportugal/dotfiles-system)?")" Y; then
      local system_dest="$TARGET_DIR/.dotfiles/system"
      if wizard_clone_if_missing "dotfiles-system" \
        "https://github.com/anthonyportugal/dotfiles-system.git" \
        "git@github.com:anthonyportugal/dotfiles-system.git" \
        "$system_dest"; then
        sudo "$system_dest/install.sh" --lang "$DOTFILES_LANG" || true
      fi
    fi
  fi

  PRIVATE=0
  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$(_t "Step 5: Private Configuration Layer (dotfiles-private)" "Paso 5: Capa Privada de Configuración (dotfiles-private)")" "$C_RESET"
  local existing_private=""
  if [[ -d "$REPO_ROOT/../private" ]]; then
    existing_private="$REPO_ROOT/../private"
  elif [[ -d "$TARGET_DIR/.dotfiles/private" ]]; then
    existing_private="$TARGET_DIR/.dotfiles/private"
  fi

  if [[ -n "$existing_private" ]]; then
    if prompt_yes_no "$(_t "Private layer detected at $(prettify_path "$existing_private"). Run its setup wizard now?" "Capa privada detectada en $(prettify_path "$existing_private"). ¿Ejecutar su asistente ahora?")" Y; then
      PRIVATE=1
      PRIVATE_PATH="$existing_private"
      "$existing_private/bin/dotfiles-private" setup --lang "$DOTFILES_LANG" || true
    fi
  else
    printf '%b%s%b\n' "$C_SUBTEXT" "$(_t "No private layer detected at ~/.dotfiles/private." "No se detectó capa privada en ~/.dotfiles/private.")" "$C_RESET"
    local custom_private_url=""
    prompt_input "$(_t "Enter private repository Git URL to clone (or press ENTER to skip)" "Ingresa la URL del repo privado a clonar (o ENTER para omitir)")" "" custom_private_url
    if [[ -n "$custom_private_url" ]]; then
      local private_dest="$TARGET_DIR/.dotfiles/private"
      info "Clonando repositorio privado en $private_dest..."
      mkdir -p "$TARGET_DIR/.dotfiles"
      if git clone "$custom_private_url" "$private_dest"; then
        PRIVATE=1
        PRIVATE_PATH="$private_dest"
        info "$(_t "Private repository cloned successfully." "Repositorio privado clonado exitosamente.")"
        if [[ -x "$private_dest/bin/dotfiles-private" ]]; then
          "$private_dest/bin/dotfiles-private" setup --lang "$DOTFILES_LANG" || true
        fi
      else
        warn "$(_t "Could not clone private repository. Continuing without private layer." "No se pudo clonar el repositorio privado. Continuando sin capa privada.")"
      fi
    else
      if prompt_yes_no "$(_t "Configure local Git identity (user.name and user.email)?" "¿Deseas configurar tu identidad Git local (user.name y user.email)?")" Y; then
        local git_name="" git_email=""
        prompt_input "$(_t "Git Name" "Nombre para Git")" "Anthony Portugal" git_name
        prompt_input "$(_t "Git Email" "Email para Git")" "" git_email
        if [[ -n "$git_name" && -n "$git_email" ]]; then
          mkdir -p "$TARGET_DIR/.config/git"
          git config --file "$TARGET_DIR/.config/git/local.gitconfig" user.name "$git_name"
          git config --file "$TARGET_DIR/.config/git/local.gitconfig" user.email "$git_email"
          info "$(_t "Git identity saved to ~/.config/git/local.gitconfig" "Identidad Git guardada en ~/.config/git/local.gitconfig")"
        fi
      fi
    fi
  fi

  HARNESS=0
  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$(_t "Step 6: Agent Harness (AI Coding Agents, Rules, MCP & Skills)" "Paso 6: Agent Harness (Agentes IA, Reglas, MCP y Skills)")" "$C_RESET"
  local existing_harness=""
  if [[ -d "$REPO_ROOT/../agent-harness" ]]; then
    existing_harness="$REPO_ROOT/../agent-harness"
  elif [[ -d "$TARGET_DIR/.dotfiles/agent-harness" ]]; then
    existing_harness="$TARGET_DIR/.dotfiles/agent-harness"
  fi

  if [[ -n "$existing_harness" ]]; then
    if prompt_yes_no "$(_t "Agent Harness detected at $(prettify_path "$existing_harness"). Configure runtimes now?" "Agent Harness detectado en $(prettify_path "$existing_harness"). ¿Configurar runtimes ahora?")" Y; then
      HARNESS=1
      HARNESS_PATH="$existing_harness"
      if [[ -x "$existing_harness/bin/agent-harness" ]]; then
        "$existing_harness/bin/agent-harness" setup || true
      fi
    fi
  else
    if prompt_yes_no "$(_t "Integrate Agent Harness (anthonyportugal/agent-harness)?" "¿Deseas integrar Agent Harness (anthonyportugal/agent-harness)?")" Y; then
      local harness_dest="$TARGET_DIR/.dotfiles/agent-harness"
      if wizard_clone_if_missing "agent-harness" \
        "https://github.com/anthonyportugal/agent-harness.git" \
        "git@github.com:anthonyportugal/agent-harness.git" \
        "$harness_dest"; then
        HARNESS=1
        HARNESS_PATH="$harness_dest"
        if [[ -x "$harness_dest/bin/agent-harness" ]]; then
          "$harness_dest/bin/agent-harness" setup || true
        fi
      fi
    fi
  fi

  local mode_choice=0
  prompt_choice mode_choice "$(_t "Step 7: Select Base System Installation Scope" "Paso 7: Selecciona el Alcance de la Instalación Base")" \
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
  local priv_str="No"
  (( PRIVATE == 1 )) && priv_str="$(_t "Yes" "Sí")"
  printf '│  • %-20s %-33s│\n' "$(_t "Private Layer:" "Capa Privada:")" "$priv_str"
  local harness_str="No"
  (( HARNESS == 1 )) && harness_str="$(_t "Yes" "Sí")"
  printf '│  • %-20s %-33s│\n' "$(_t "Agent Harness:" "Agent Harness:")" "$harness_str"
  printf '│  • %-20s %-33s│\n' "$(_t "Operation Mode:" "Modo de Operación:")" "$MODE_SELECTION"
  printf '│  • %-20s %-33s│\n' "$(_t "Target Home:" "Directorio Target:")" "$(prettify_path "$TARGET_DIR")"
  cat <<'EOF'
╰─────────────────────────────────────────────────────────────╯
EOF
  printf '%b\n' "$C_RESET"

  local final_choice=0
  prompt_choice final_choice "$(_t "Step 8: How would you like to proceed with Base?" "Paso 8: ¿Cómo deseas proceder con la Base?")" \
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
  validate_private_checkout
  validate_harness_checkout
  bootstrap_with_optional_components
}

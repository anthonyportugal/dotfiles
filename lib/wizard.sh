#!/usr/bin/env bash
# lib/wizard.sh - `dotfiles setup`: one short guided flow and prompt helpers.
#
# When the target has links of another install (the pre-monorepo ~/.dotfiles
# or another monorepo checkout, as `dotfiles switch` detects it), setup first
# shows what it found and offers to migrate it with the switch logic, to go on
# to the questions without migrating, or to cancel; a migration ends setup.
#
# The flow asks four questions, prints the plan and runs the normal bootstrap:
#   1. profile: server (cli) or desktop;
#   2. WMs (desktop only): any of layers/wm/*/layer.conf, none included;
#   3. overlay: an existing checkout with layers/, or a Git URL cloned next
#      to this checkout (wizard_overlay_dir) on apply, or Enter to skip;
#   4. extras: opt-in layers, features (the chosen overlay's included) and
#      components.conf entries that fit the chosen profile and WMs,
#      discovered at run time, none checked;
# on a target with a selection receipt every question starts from the
# recorded selection (Enter keeps it) and the plan names what an unchecked
# answer retires;
# then apply, dry-run or cancel (the default). Answers are read one line at a
# time; an empty line or the end of input takes the default, so piped input
# always ends. Maintenance (sync, update, doctor, unlink) and the system layer
# stay CLI commands.
#
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Set once stdin ends; every later prompt then takes its default.
WIZARD_EOF=0
# Set when the migration offer ended setup (migrated or cancelled).
WIZARD_ENDED=0
# Overlay URL to clone on apply (dry-run and cancel never clone).
WIZARD_OVERLAY_URL=""

# Prints where the overlay is looked for and cloned: next to this checkout
# (DIR-private, where the switch looks for it too), or DOTFILES_OVERLAY_DIR.
wizard_overlay_dir() {
  printf '%s' "${DOTFILES_OVERLAY_DIR:-$REPO_ROOT-private}"
}
# Extras offered by the current run: kind (layer|feature|component), name and
# description share the index.
declare -a WIZARD_EXTRA_KINDS=() WIZARD_EXTRA_NAMES=() WIZARD_EXTRA_DESCRIPTIONS=()

# Yes/no question used by `dotfiles update` on a terminal.
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

prettify_path() {
  local p=${1:-}
  local clean
  clean="$(cd -P "$p" 2>/dev/null && pwd -P)" || clean="$p"
  [[ "$clean" == "$HOME"* ]] && clean="~${clean#"$HOME"}"
  printf '%s' "$clean"
}

# Without an explicit --lang or DOTFILES_LANG, setup speaks Spanish when $LANG
# is a Spanish locale and English otherwise.
wizard_detect_language() {
  (( ${DOTFILES_LANG_EXPLICIT:-0} == 0 )) || return 0
  case "${LANG:-}" in
    es|es_*|es.*) DOTFILES_LANG=es ;;
    *) DOTFILES_LANG=en ;;
  esac
  export DOTFILES_LANG
}

# Reads one trimmed answer into the variable named $1. Returns 1 at the end of
# input, and from then on for every later call. Piped answers are echoed so
# the transcript reads like a terminal session.
wizard_read() {
  local -n _wz_answer=$1

  _wz_answer=""
  if (( WIZARD_EOF == 0 )) && ! IFS= read -r _wz_answer; then
    WIZARD_EOF=1
  fi
  _wz_answer=$(trim_line "$_wz_answer")
  if [[ ! -t 0 ]]; then
    printf '%s\n' "$_wz_answer"
  fi
  # A last line without a newline still counts as an answer.
  (( WIZARD_EOF == 0 )) || [[ -n "$_wz_answer" ]]
}

wizard_heading() {
  printf '\n%b%s%b\n' "${C_BOLD}${C_MAUVE}" "$1" "$C_RESET"
}

# Prints option $1 named $2 with description $3; a mark $4 ("[x]" or "[ ]")
# shows a pre-selected multiple choice.
wizard_option() {
  printf '  %b[%d]%b %s%s%s\n' "$C_PINK" "$1" "$C_RESET" "${4:+$4 }" "$2" "${3:+ - $3}"
}

wizard_invalid() {
  printf '%b%s%b\n' "$C_RED" "$(_t "Invalid answer: $1" "Respuesta inválida: $1")" "$C_RESET"
}

# Single choice: sets the variable named $1 to one of the option names, $2 by
# default. Options follow the title $3 as name/description pairs; an answer is
# an option number or name.
wizard_select() {
  local -n _wz_choice=$1
  local default=$2 title=$3
  shift 3
  local -a names=() descriptions=()
  local index answer

  while (( $# > 1 )); do
    names+=("$1")
    descriptions+=("$2")
    shift 2
  done
  wizard_heading "$title"
  for index in "${!names[@]}"; do
    wizard_option "$(( index + 1 ))" "${names[index]}" "${descriptions[index]}"
  done
  while true; do
    printf '%b%s [%s]: %b' "$C_BLUE" "$(_t "Choose" "Elige")" "$default" "$C_RESET"
    if ! wizard_read answer || [[ -z "$answer" ]]; then
      _wz_choice=$default
      return 0
    fi
    if [[ "$answer" =~ ^[1-9][0-9]*$ ]] && (( answer <= ${#names[@]} )); then
      _wz_choice=${names[answer - 1]}
      return 0
    fi
    for index in "${!names[@]}"; do
      if [[ "${answer,,}" == "${names[index]}" ]]; then
        _wz_choice=${names[index]}
        return 0
      fi
    done
    wizard_invalid "$answer"
  done
}

# Multiple choice: fills the array named $1 with the indexes chosen among the
# names of array $3 (descriptions in array $4) under title $2. An answer lists
# numbers or names separated by spaces or commas; empty means none. With the
# indexes of array $5 pre-selected (the current selection), they are marked,
# Enter keeps them, "-" clears them and any other answer replaces them.
wizard_multiselect() {
  local -n _wz_selected=$1
  local title=$2
  local -n _wz_names=$3 _wz_descriptions=$4
  local index answer token found valid mark=""
  local -a tokens=() _wz_picked=() _wz_defaults=()

  if [[ -n "${5:-}" ]]; then
    local -n _wz_defaults_ref=$5
    _wz_defaults=("${_wz_defaults_ref[@]}")
  fi
  _wz_selected=()
  wizard_heading "$title"
  for index in "${!_wz_names[@]}"; do
    if (( ${#_wz_defaults[@]} > 0 )); then
      mark="[ ]"
      ! array_contains _wz_defaults "$index" || mark="[x]"
    fi
    wizard_option "$(( index + 1 ))" "${_wz_names[index]}" "${_wz_descriptions[index]}" "$mark"
  done
  while true; do
    if (( ${#_wz_defaults[@]} > 0 )); then
      printf '%b%s: %b' "$C_BLUE" "$(_t "Numbers or names separated by spaces (Enter = keep the marked ones, - = none)" "Números o nombres separados por espacios (Enter = conservar los marcados, - = ninguno)")" "$C_RESET"
      if ! wizard_read answer || [[ -z "$answer" ]]; then
        _wz_selected=("${_wz_defaults[@]}")
        return 0
      fi
      [[ "$answer" != - ]] || return 0
    else
      printf '%b%s: %b' "$C_BLUE" "$(_t "Numbers or names separated by spaces (Enter = none)" "Números o nombres separados por espacios (Enter = ninguno)")" "$C_RESET"
      wizard_read answer || return 0
    fi
    IFS=$' \t,' read -r -a tokens <<< "$answer"
    _wz_picked=()
    valid=1
    for token in "${tokens[@]}"; do
      found=""
      if [[ "$token" =~ ^[1-9][0-9]*$ ]] && (( token <= ${#_wz_names[@]} )); then
        found=$(( token - 1 ))
      else
        for index in "${!_wz_names[@]}"; do
          [[ "${token,,}" != "${_wz_names[index]}" ]] || { found=$index; break; }
        done
      fi
      if [[ -z "$found" ]]; then
        wizard_invalid "$token"
        valid=0
        break
      fi
      append_unique _wz_picked "$found"
    done
    if (( valid == 1 )); then
      _wz_selected=("${_wz_picked[@]}")
      return 0
    fi
    # At the end of input an invalid list keeps the pre-selection, if any.
    if (( WIZARD_EOF == 1 )); then
      _wz_selected=("${_wz_defaults[@]}")
      return 0
    fi
  done
}

# Yes/no question $1 with default $2 (Y or N); the end of input takes it.
wizard_confirm() {
  local question=$1 default=${2:-Y} answer suffix

  suffix=$(_t "[Y/n]" "[S/n]")
  [[ "$default" != [Nn] ]] || suffix=$(_t "[y/N]" "[s/N]")
  while true; do
    printf '%b%s %b%s%b ' "${C_BOLD}" "$question" "${C_SUBTEXT}" "$suffix" "$C_RESET"
    wizard_read answer || true
    [[ -n "$answer" ]] || answer=$default
    case "${answer,,}" in
      y|yes|s|si|sí) return 0 ;;
      n|no) return 1 ;;
    esac
    wizard_invalid "$answer"
    # At the end of input an invalid answer takes the default.
    (( WIZARD_EOF == 0 )) || { [[ "$default" == [Yy] ]]; return; }
  done
}

# Prints the description declared by layer dir $1 for key $2.
wizard_layer_description() {
  local -A conf=()
  read_layer_conf "$1" conf
  printf '%s' "${conf[$2]:-}"
}

# True when every layer that layer $1 pulls in fits the chosen PROFILE and WMS.
wizard_layer_fits() {
  local pulled_layer
  local -a pulled=()

  resolve_layers "$LAYERS_DIR" pulled "$1"
  for pulled_layer in "${pulled[@]}"; do
    if [[ "$pulled_layer" == wm/* ]]; then
      array_contains WMS "${pulled_layer#wm/}" || return 1
    elif array_contains BASE_LAYERS "$pulled_layer"; then
      (( $(base_layer_rank "$pulled_layer") <= $(base_layer_rank "$PROFILE") )) || return 1
    fi
  done
}

# Fills WIZARD_EXTRA_* with the opt-in layers, the features of base, opt-in
# and chosen overlay layers, and the components that fit the chosen profile
# and WMs.
wizard_collect_extras() {
  local name layer

  WIZARD_EXTRA_KINDS=() WIZARD_EXTRA_NAMES=() WIZARD_EXTRA_DESCRIPTIONS=()
  for name in "${SUPPORTED_LAYERS[@]}"; do
    wizard_layer_fits "$name" || continue
    WIZARD_EXTRA_KINDS+=(layer)
    WIZARD_EXTRA_NAMES+=("$name")
    WIZARD_EXTRA_DESCRIPTIONS+=("$(wizard_layer_description "$LAYERS_DIR/$name" description)")
  done
  for name in "${SUPPORTED_FEATURES[@]}"; do
    layer=${FEATURE_LAYERS[$name]}
    wizard_layer_fits "$layer" || continue
    WIZARD_EXTRA_KINDS+=(feature)
    WIZARD_EXTRA_NAMES+=("$name")
    WIZARD_EXTRA_DESCRIPTIONS+=("$(wizard_layer_description "$LAYERS_DIR/$layer" "description.$name")")
  done
  wizard_collect_overlay_features
  load_components
  for name in "${COMPONENT_NAMES[@]}"; do
    WIZARD_EXTRA_KINDS+=(component)
    WIZARD_EXTRA_NAMES+=("$name")
    WIZARD_EXTRA_DESCRIPTIONS+=("${COMPONENT_DESCRIPTIONS[$name]:-}")
  done
}

# Adds to WIZARD_EXTRA_* the features declared by the layers of the chosen
# overlay (OVERLAY_PATH) whose requirements fit the profile and WMs. Only
# reads the overlay: the engine validates it in prepare_overlay, so a layer it
# would refuse (a bad name, a missing requirement, a repeated feature) is
# skipped here and fails in the bootstrap itself.
wizard_collect_overlay_features() {
  local layer_dir layer feature
  local -A conf=()
  local -a declared=()

  [[ -n "$OVERLAY_PATH" && -d "$OVERLAY_PATH/layers" ]] || return 0
  for layer_dir in "$OVERLAY_PATH"/layers/*/; do
    layer_dir=${layer_dir%/}
    layer=${layer_dir##*/}
    [[ "$layer" =~ ^[a-z0-9][a-z0-9-]*$ && -f "$layer_dir/layer.conf" && ! -e "$LAYERS_DIR/$layer" ]] || continue
    # The fit check resolves the layer's requirements through the overlay; a
    # subshell keeps a requirement the engine would refuse from ending setup.
    ( LAYER_OVERLAY_ROOT="$OVERLAY_PATH/layers"; wizard_layer_fits "$layer" ) >/dev/null 2>&1 || continue
    read_layer_conf "$layer_dir" conf
    read -r -a declared <<< "${conf[features]:-}"
    for feature in "${declared[@]}"; do
      ! array_contains SUPPORTED_FEATURES "$feature" || continue
      ! array_contains WIZARD_EXTRA_NAMES "$feature" || continue
      WIZARD_EXTRA_KINDS+=(feature)
      WIZARD_EXTRA_NAMES+=("$feature")
      WIZARD_EXTRA_DESCRIPTIONS+=("${conf[description.$feature]:-}")
    done
  done
}

# Chooses the overlay. An existing checkout with layers/ (the --overlay path,
# the receipt's overlay or wizard_overlay_dir) is offered with Yes by
# default; otherwise a Git URL is cloned into wizard_overlay_dir on apply,
# or Enter skips it.
wizard_choose_overlay() {
  local candidate existing="" url="" dest
  dest=$(wizard_overlay_dir)
  local -A saved=()
  local recorded=""

  (( NO_OVERLAY == 0 )) || return 0
  ! read_receipt dotfiles saved || recorded=${saved[OVERLAY]:-}
  for candidate in "$OVERLAY_PATH" "$recorded" "$dest"; do
    [[ -n "$candidate" && -d "$candidate/layers" ]] || continue
    existing=$candidate
    break
  done

  wizard_heading "$(_t "Private overlay" "Overlay privado")"
  if [[ -n "$existing" ]]; then
    if wizard_confirm "$(_t "Overlay detected at $(prettify_path "$existing"). Apply it?" "Overlay detectado en $(prettify_path "$existing"). ¿Aplicarlo?")" Y; then
      OVERLAY_PATH=$existing
      OVERLAY_EXPLICIT=1
      return 0
    fi
    OVERLAY_PATH=""
    NO_OVERLAY=1
  else
    printf '%b%s: %b' "${C_BOLD}" "$(_t "Git URL of your overlay, cloned into $(prettify_path "$dest") on apply (Enter to skip)" "URL Git de tu overlay, se clona en $(prettify_path "$dest") al aplicar (Enter para omitir)")" "$C_RESET"
    wizard_read url || true
    WIZARD_OVERLAY_URL=$url
    OVERLAY_PATH=""
    [[ -z "$url" ]] || return 0
  fi
  info "$(_t "No overlay: the public Git config stays fail-closed until an identity is configured (~/.config/git/local.gitconfig)." "Sin overlay: la configuración Git pública queda fail-closed hasta configurar una identidad (~/.config/git/local.gitconfig).")"
}

# Clones WIZARD_OVERLAY_URL into wizard_overlay_dir.
wizard_clone_overlay() {
  local dest
  dest=$(wizard_overlay_dir)

  info "$(_t "Cloning the overlay into $dest" "Clonando el overlay en $dest")"
  if git clone -q -- "$WIZARD_OVERLAY_URL" "$dest" && [[ -d "$dest/layers" ]]; then
    OVERLAY_PATH=$dest
    OVERLAY_EXPLICIT=1
    return 0
  fi
  warn "$(_t "Could not clone an overlay with layers/ from $WIZARD_OVERLAY_URL. Continuing without it." "No se pudo clonar un overlay con layers/ desde $WIZARD_OVERLAY_URL. Se continúa sin él.")"
  NO_OVERLAY=1
}

# Adds component $1 (apply mode $2) like `dotfiles add`. A subshell keeps a
# refused add from ending the wizard.
wizard_add_component() {
  local -a add_args=("$1" --target "$TARGET_DIR")
  (( $2 == 1 )) || add_args+=(--dry-run)
  ( cmd_add "${add_args[@]}" ) || \
    warn "$(_t "The $1 component was not added" "El componente $1 no se añadió")"
}

# Prints what the chosen selection would retire from the recorded one, the
# same names the bootstrap plan lists. Runs the engine's resolution in a
# subshell, so nothing of this run changes; a selection the engine refuses
# prints nothing here and fails in the bootstrap itself.
wizard_retire_preview() {
  ( _wizard_retire_names ) 3>&1 >/dev/null 2>&1 || true
}

# Body of wizard_retire_preview; only ever run in its subshell. The names go
# to file descriptor 3, everything the engine prints is discarded.
_wizard_retire_names() {
  COMMAND=bootstrap
  prepare_overlay
  validate_features
  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")
  resolve_selected_layers
  RECORDED_COMPONENTS=()
  (( STOW_ENABLED == 0 )) || recorded_components RECORDED_COMPONENTS
  compute_retired_selection
  printf '%s' "${RETIRE_NAMES[*]}" >&3
}

wizard_plan_line() {
  printf '  %-12s %s\n' "$1" "$2"
}

# Prepares the switch from the current install of the target to this
# checkout, the way `dotfiles switch` does (an explicit --overlay or
# --no-overlay of setup carries over, otherwise switch resolves it). Only
# ever run in a subshell: the switch stops the process when nothing is found.
_wizard_switch_prepare() {
  local overlay_arg=""
  (( OVERLAY_EXPLICIT == 0 )) || overlay_arg=$OVERLAY_PATH
  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")
  switch_prepare "$REPO_ROOT" "" "$overlay_arg" "$NO_OVERLAY" 0 0
}

# Prints, on file descriptor 3, the summary of an install of another checkout
# (the pre-monorepo ~/.dotfiles or another monorepo checkout) that has links
# in the target; nothing when there is none or the target already uses this
# checkout. Everything the switch prints is discarded.
_wizard_migration_summary() {
  local item old
  local -a extras=()

  _wizard_switch_prepare >/dev/null 2>&1
  (( SW_ALREADY_ACTIVE == 0 && ${#SW_LINKS[@]} > 0 )) || return 0
  old=$(prettify_path "$SW_OLD")
  [[ "$SW_KIND" != legacy ]] || old="$old $(_t "(previous ecosystem)" "(ecosistema anterior)")"
  extras=("${SW_LAYERS[@]}" "${SW_FEATURES[@]}" "${SW_NEW_COMPONENTS[@]}")
  {
    wizard_heading "$(_t "Previous install detected" "Instalación anterior detectada")"
    wizard_summary_line "$(_t "Install:" "Instalación:")" "$old"
    wizard_summary_line "$(_t "Profile:" "Perfil:")" "$SW_PROFILE"
    (( ${#SW_WMS[@]} == 0 )) || wizard_summary_line "WMs:" "${SW_WMS[*]}"
    wizard_summary_line "Extras:" "${extras[*]:-$(_t "none" "ninguno")}"
    if [[ -n "$SW_OVERLAY" ]]; then
      wizard_summary_line "Overlay:" "$(prettify_path "$SW_OVERLAY")"
    else
      wizard_summary_line "Overlay:" "$(_t "none" "ninguno")"
    fi
    wizard_summary_line "$(_t "Links to replace:" "Enlaces a reemplazar:")" "${#SW_LINKS[@]}"
    for item in "${SW_NOT_MIGRATED[@]}"; do
      wizard_summary_line "$(_t "Not migrated:" "No migrado:")" "$item"
    done
  } >&3
}

wizard_summary_line() {
  printf '  %-22s %s\n' "$1" "$2"
}

# The migration itself, only ever run in a subshell with errexit: the switch
# plan, then apply, dry-run or cancel (the default), like the final step.
_wizard_migrate() {
  local choice

  _wizard_switch_prepare
  _sw_print_plan ""
  wizard_select choice cancel "$(_t "How do you want to continue?" "¿Cómo deseas continuar?")" \
    apply "$(_t "Migrate now" "Migrar ahora")" \
    dry-run "$(_t "Check for collisions without modifying anything" "Comprobar colisiones sin modificar nada")" \
    cancel "$(_t "Exit without changes" "Salir sin cambios")"
  case "$choice" in
    cancel)
      info "$(_t "Setup cancelled; nothing was changed." "Configuración cancelada; no se modificó nada.")"
      ;;
    dry-run)
      switch_run 0 0 </dev/null
      info "$(_t "Dry-run: nothing changed. Run setup again and choose apply to migrate." "Dry-run: nada cambió. Vuelva a ejecutar setup y elija apply para migrar.")"
      ;;
    apply)
      # Checked again as `dotfiles switch --apply` does before its preflight:
      # the plan was shown in dry-run mode.
      switch_check_pending 1
      switch_run 1 </dev/null
      info "$(_t "Migration done; setup starts from this selection next time. To undo it: dotfiles switch --rollback --apply" "Migración hecha; setup partirá de esta selección la próxima vez. Para deshacerla: dotfiles switch --rollback --apply")"
      ;;
  esac
}

# Prints what keeps the switch from being prepared, when the target is worth
# telling about: "pending" for a change left unfinished, "install" for another
# install that is there; nothing otherwise (a fresh home). Only ever run in a
# subshell.
_wizard_prepare_blocker() {
  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")
  if txn_pending 0 >/dev/null 2>&1; then
    printf 'pending'
  elif switch_install_root "" >/dev/null; then
    printf 'install'
  fi
}

# The rollback of the change left unfinished, only ever run in a subshell with
# errexit: its plan, then apply or cancel (the default), like
# `dotfiles switch --rollback --apply`.
_wizard_rollback() {
  local choice dir

  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")
  dir=$(switch_rollback_dir 0)
  switch_print_rollback_plan "$dir" ""
  wizard_select choice cancel "$(_t "How do you want to continue?" "¿Cómo deseas continuar?")" \
    apply "$(_t "Undo it now" "Deshacerlo ahora")" \
    cancel "$(_t "Exit without changes" "Salir sin cambios")"
  if [[ "$choice" == cancel ]]; then
    info "$(_t "Setup cancelled; nothing was changed." "Configuración cancelada; no se modificó nada.")"
    return 0
  fi
  dir=$(switch_rollback_dir 1)
  switch_rollback_apply "$dir"
  info "$(_t "Run setup again to continue from the restored install." "Vuelva a ejecutar setup para seguir desde la instalación restaurada.")"
}

# Runs the subshell step $1 with errexit and exits with its status when it
# failed; sets WIZARD_ENDED otherwise.
_wizard_end_with() {
  local status=0
  set +e
  ( set -e; "$1" )
  status=$?
  set -e
  (( status == 0 )) || exit "$status"
  WIZARD_ENDED=1
}

# When another install or an unfinished change is there but the switch cannot
# be prepared: shows the switch's own error and what to do, then asks to
# continue to the questions or cancel (the default, also at the end of
# input), and offers the rollback first for an unfinished change.
_wizard_explain_blocker() {
  local blocker=$1 errors choice
  local -a choices=()

  errors=$( (_wizard_switch_prepare) 2>&1 >/dev/null ) || true
  if [[ "$blocker" == pending ]]; then
    wizard_heading "$(_t "An unfinished change was left in this home" "Quedó un cambio sin cerrar en este home")"
  else
    wizard_heading "$(_t "Another install was found, but it cannot be migrated" "Se encontró otra instalación, pero no se puede migrar")"
  fi
  [[ -z "$errors" ]] || printf '%s\n' "$errors"
  if [[ "$blocker" == pending ]]; then
    printf '%s\n' "$(_t "rollback shows its plan and restores the home as it was before that change; run setup again afterwards." \
      "rollback muestra su plan y deja el home como estaba antes de ese cambio; después vuelva a ejecutar setup.")"
    choices=(rollback "$(_t "Undo the unfinished change (its plan first)" "Deshacer el cambio sin cerrar (primero su plan)")")
  else
    printf '%s\n' "$(_t "Fix what the error says and run setup again to migrate it, or continue without migrating." \
      "Corrija lo que indica el error y vuelva a ejecutar setup para migrarla, o siga sin migrar.")"
  fi
  wizard_select choice cancel "$(_t "What do you want to do?" "¿Qué deseas hacer?")" \
    "${choices[@]}" \
    continue "$(_t "Continue to the questions without migrating (its links stay)" "Seguir con las preguntas sin migrar (sus enlaces se conservan)")" \
    cancel "$(_t "Exit without changes" "Salir sin cambios")"
  case "$choice" in
    continue) return 0 ;;
    cancel)
      info "$(_t "Setup cancelled; nothing was changed." "Configuración cancelada; no se modificó nada.")"
      WIZARD_ENDED=1
      ;;
    rollback) _wizard_end_with _wizard_rollback ;;
  esac
}

# Before the questions: when the target has links of another install, shows
# what was found and asks to migrate it now (the switch logic), continue to
# the questions without migrating, or cancel (the default, also at the end of
# input). When it is there but cannot be prepared, or a change was left
# unfinished, says why instead (_wizard_explain_blocker). Sets WIZARD_ENDED
# when setup ends here instead of asking the questions; exits with the
# migration's status when it failed.
wizard_offer_migration() {
  local summary choice blocker status=0

  set +e
  summary=$( ( set -e; _wizard_migration_summary ) 3>&1 >/dev/null 2>&1 )
  status=$?
  set -e
  if (( status != 0 )); then
    blocker=$( (_wizard_prepare_blocker) )
    [[ -z "$blocker" ]] || _wizard_explain_blocker "$blocker"
    return 0
  fi
  [[ -n "$summary" ]] || return 0
  printf '%s\n' "$summary"
  wizard_select choice cancel "$(_t "What do you want to do with it?" "¿Qué deseas hacer con ella?")" \
    migrate "$(_t "Migrate it to this checkout, keeping its selection (reversible)" "Migrarla a este checkout conservando su selección (reversible)")" \
    continue "$(_t "Continue to the questions without migrating (its links stay)" "Seguir con las preguntas sin migrar (sus enlaces se conservan)")" \
    cancel "$(_t "Exit without changes" "Salir sin cambios")"
  case "$choice" in
    continue) return 0 ;;
    cancel)
      info "$(_t "Setup cancelled; nothing was changed." "Configuración cancelada; no se modificó nada.")"
      WIZARD_ENDED=1
      return 0
      ;;
  esac
  _wizard_end_with _wizard_migrate
}

run_interactive_wizard() {
  local profile_choice final_choice index mode overlay_text component retiring
  local profile_default=desktop extras_title
  local -a wm_names=() wm_descriptions=() picked=() components=() defaults=()
  local -a recorded_wms=() recorded_extras=() recorded_components_list=()
  local -A recorded=()
  local wm_dir

  wizard_detect_language
  setup_colors
  printf '%b%s%b %s\n' "${C_BOLD}${C_MAUVE}" "dotfiles setup" "$C_RESET" \
    "$(prettify_path "$REPO_ROOT") -> $(prettify_path "$TARGET_DIR")"
  # Never in a || list: errexit must stay on inside the migration.
  wizard_offer_migration
  (( WIZARD_ENDED == 0 )) || return 0

  # A target set up before starts from its current selection.
  if read_receipt dotfiles recorded; then
    [[ "${recorded[PROFILE]:-}" == desktop || -n "${recorded[WMS]:-}" ]] || profile_default=server
    read -r -a recorded_wms <<< "${recorded[WMS]:-}"
    read -r -a recorded_extras <<< "${recorded[LAYERS]:-} ${recorded[FEATURES]:-}"
    recorded_components recorded_components_list
    recorded_extras+=("${recorded_components_list[@]}")
  fi

  # 1. Profile.
  wizard_select profile_choice "$profile_default" "$(_t "Choose a profile" "Elige un perfil")" \
    server "$(_t "Terminal only: shell, Git and CLI tools (VPS, headless)" "Solo terminal: shell, Git y herramientas CLI (VPS, sin pantalla)")" \
    desktop "$(_t "Server plus the graphical session (theme, fonts, audio, portals)" "Servidor más la sesión gráfica (tema, fuentes, audio, portales)")"
  if [[ "$profile_choice" == server ]]; then
    PROFILE=cli
  else
    PROFILE=desktop
  fi

  # 2. Window managers, only on desktop.
  WMS=()
  if [[ "$PROFILE" == desktop ]]; then
    for wm_dir in "$LAYERS_DIR"/wm/*/; do
      [[ -f "$wm_dir/layer.conf" ]] || continue
      wm_dir=${wm_dir%/}
      wm_names+=("${wm_dir##*/}")
      wm_descriptions+=("$(wizard_layer_description "$wm_dir" description)")
    done
    if (( ${#wm_names[@]} > 0 )); then
      defaults=()
      for index in "${!wm_names[@]}"; do
        ! array_contains recorded_wms "${wm_names[index]}" || defaults+=("$index")
      done
      wizard_multiselect picked "$(_t "Window managers (none, one or several)" "Gestores de ventanas (ninguno, uno o varios)")" \
        wm_names wm_descriptions defaults
      for index in "${picked[@]}"; do
        WMS+=("${wm_names[index]}")
      done
    fi
  fi
  WM=${WMS[0]:-}

  # 3. Overlay, before the extras so they can offer its features.
  wizard_choose_overlay

  # 4. Extras that fit the profile, WMs and overlay.
  wizard_collect_extras
  picked=()
  if (( ${#WIZARD_EXTRA_NAMES[@]} > 0 )); then
    defaults=()
    for index in "${!WIZARD_EXTRA_NAMES[@]}"; do
      ! array_contains recorded_extras "${WIZARD_EXTRA_NAMES[index]}" || defaults+=("$index")
    done
    extras_title=$(_t "Extras (optional, none selected by default)" "Extras (opcionales, ninguno marcado por defecto)")
    (( ${#defaults[@]} == 0 )) || \
      extras_title=$(_t "Extras (optional, the current selection is marked)" "Extras (opcionales, la selección actual está marcada)")
    wizard_multiselect picked "$extras_title" WIZARD_EXTRA_NAMES WIZARD_EXTRA_DESCRIPTIONS defaults
  fi
  FEATURES=() OPTIONAL_LAYERS=()
  for index in "${picked[@]}"; do
    case "${WIZARD_EXTRA_KINDS[index]}" in
      layer) OPTIONAL_LAYERS+=("${WIZARD_EXTRA_NAMES[index]}") ;;
      feature) FEATURES+=("${WIZARD_EXTRA_NAMES[index]}") ;;
      component) components+=("${WIZARD_EXTRA_NAMES[index]}") ;;
    esac
  done

  # Recorded components left unchecked are unlinked by the bootstrap.
  RETIRED_COMPONENTS=()
  for component in "${recorded_components_list[@]}"; do
    array_contains components "$component" || RETIRED_COMPONENTS+=("$component")
  done

  case "$MODE_SELECTION" in
    stow) mode=$(_t "links only (no packages)" "solo enlaces (sin paquetes)") ;;
    packages) mode=$(_t "packages only" "solo paquetes") ;;
    *) mode=$(_t "packages and links" "paquetes y enlaces") ;;
  esac
  overlay_text=$(_t "none" "ninguno")
  [[ -z "$OVERLAY_PATH" ]] || overlay_text=$(prettify_path "$OVERLAY_PATH")
  [[ -z "$WIZARD_OVERLAY_URL" ]] || overlay_text="$WIZARD_OVERLAY_URL ($(_t "cloned on apply" "se clona al aplicar"))"
  local -a extras=("${OPTIONAL_LAYERS[@]}" "${FEATURES[@]}" "${components[@]}")
  wizard_heading "Plan"
  if [[ "$PROFILE" == cli ]]; then
    wizard_plan_line "$(_t "Profile:" "Perfil:")" "$profile_choice (cli)"
  else
    wizard_plan_line "$(_t "Profile:" "Perfil:")" "$profile_choice"
  fi
  [[ "$PROFILE" != desktop ]] || wizard_plan_line "WMs:" "${WMS[*]:-$(_t "none" "ninguno")}"
  wizard_plan_line "Extras:" "${extras[*]:-$(_t "none" "ninguno")}"
  wizard_plan_line "Overlay:" "$overlay_text"
  retiring=$(wizard_retire_preview)
  [[ -z "$retiring" ]] || wizard_plan_line "$(_t "Retiring:" "Se retiran:")" "$retiring"
  wizard_plan_line "$(_t "Mode:" "Modo:")" "$mode"
  wizard_plan_line "Target:" "$(prettify_path "$TARGET_DIR")"

  wizard_select final_choice cancel "$(_t "How do you want to continue?" "¿Cómo deseas continuar?")" \
    apply "$(_t "Apply the plan now" "Aplicar el plan ahora")" \
    dry-run "$(_t "Show what would change without modifying anything" "Mostrar qué cambiaría sin modificar nada")" \
    cancel "$(_t "Exit without changes" "Salir sin cambios")"
  case "$final_choice" in
    cancel)
      info "$(_t "Setup cancelled; nothing was changed." "Configuración cancelada; no se modificó nada.")"
      return 0
      ;;
    apply)
      APPLY=1
      [[ -z "$WIZARD_OVERLAY_URL" ]] || wizard_clone_overlay
      ;;
    dry-run)
      APPLY=0
      [[ -z "$WIZARD_OVERLAY_URL" ]] || \
        info "$(_t "The dry-run plans without the overlay; it is cloned from $WIZARD_OVERLAY_URL only on apply." "El dry-run planifica sin el overlay; se clona desde $WIZARD_OVERLAY_URL solo al aplicar.")"
      ;;
  esac

  COMMAND="bootstrap"
  resolve_wm_layers
  bootstrap_with_optional_components
  # Recorded components were re-applied by the bootstrap; only new ones are added.
  for component in "${components[@]}"; do
    array_contains recorded_components_list "$component" || wizard_add_component "$component" "$APPLY"
  done
  info "$(_t "Optional system layer (Ly, Limine, DNS-over-TLS, needs sudo): run 'dotfiles system' when you want it." "Capa de sistema opcional (Ly, Limine, DNS-over-TLS, requiere sudo): ejecute 'dotfiles system' cuando la quiera.")"
}

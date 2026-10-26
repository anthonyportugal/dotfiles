#!/usr/bin/env bash
# lib/links.sh - GNU Stow linking, collision preflight and orphan pruning.
#
# Reads REPO_ROOT, STOW_DIR, TARGET_DIR, STOW_PACKAGES, PRUNE_SEARCH_DIRS and
# PRUNE_ROOT_LINKS; fills LINK_OK and the LINK_* issue arrays. Requires
# lib/colors.sh and lib/core.sh.
#
# shellcheck shell=bash

# Callers override these with their own link locations, relative to TARGET_DIR.
[[ -v PRUNE_SEARCH_DIRS ]] || PRUNE_SEARCH_DIRS=()
[[ -v PRUNE_ROOT_LINKS ]] || PRUNE_ROOT_LINKS=()

is_repo_symlink() {
  local target_link=$1
  [[ -L "$target_link" ]] || return 1

  local dest
  dest=$(realpath -m -- "$target_link" 2>/dev/null || true)
  local repo_canon stow_canon dots_canon
  repo_canon=$(realpath -m -- "$REPO_ROOT" 2>/dev/null || true)
  stow_canon=$(realpath -m -- "$STOW_DIR" 2>/dev/null || true)
  dots_canon=$(realpath -m -- "$TARGET_DIR/.dotfiles" 2>/dev/null || true)

  if [[ -n "$repo_canon" && ( "$dest" == "$repo_canon/"* || "$dest" == "$repo_canon" ) ]]; then
    return 0
  fi
  if [[ -n "$stow_canon" && ( "$dest" == "$stow_canon/"* || "$dest" == "$stow_canon" ) ]]; then
    return 0
  fi
  if [[ -n "$dots_canon" && "$dest" == "$dots_canon/"* ]]; then
    return 0
  fi
  return 1
}

prune_dangling_dotfiles_links() {
  local apply=${1:-0}
  local repo_canon stow_canon dots_canon
  repo_canon=$(realpath -m -- "$REPO_ROOT" 2>/dev/null || true)
  stow_canon=$(realpath -m -- "$STOW_DIR" 2>/dev/null || true)
  dots_canon=$(realpath -m -- "$TARGET_DIR/.dotfiles" 2>/dev/null || true)

  # Each caller declares where its links live, relative to TARGET_DIR.
  local -a search_dirs=()
  local dir relative_entry
  for relative_entry in "${PRUNE_SEARCH_DIRS[@]}"; do
    dir="$TARGET_DIR/$relative_entry"
    [[ -d "$dir" ]] && search_dirs+=("$dir")
  done

  local root_candidate
  for relative_entry in "${PRUNE_ROOT_LINKS[@]}"; do
    root_candidate="$TARGET_DIR/$relative_entry"
    if [[ -L "$root_candidate" && ! -e "$root_candidate" ]]; then
      local dest
      dest=$(realpath -m -- "$root_candidate" 2>/dev/null || true)
      if [[ -n "$dest" && ( "$dest" == "$repo_canon/"* || "$dest" == "$repo_canon" || \
            "$dest" == "$stow_canon/"* || "$dest" == "$stow_canon" || \
            "$dest" == "$dots_canon/"* ) ]]; then
        if (( apply == 1 )); then
          info "Eliminando enlace huérfano: $root_candidate"
          rm -f -- "$root_candidate"
        else
          warn "Enlace huérfano detectado: $root_candidate"
        fi
      fi
    fi
  done

  (( ${#search_dirs[@]} > 0 )) || return 0

  while IFS= read -r -d '' dead_link; do
    local dest
    dest=$(realpath -m -- "$dead_link" 2>/dev/null || true)
    if [[ -n "$dest" && ( "$dest" == "$repo_canon/"* || "$dest" == "$repo_canon" || \
          "$dest" == "$stow_canon/"* || "$dest" == "$stow_canon" || \
          "$dest" == "$dots_canon/"* ) ]]; then
      if (( apply == 1 )); then
        info "Eliminando enlace huérfano: $dead_link"
        rm -f -- "$dead_link"
      else
        warn "Enlace huérfano detectado: $dead_link"
      fi
    fi
  done < <(find "${search_dirs[@]}" -xtype l -print0 2>/dev/null || true)
}

inspect_links() {
  local package_name package_dir source_path relative_path target_path
  local canonical_source canonical_target existing_source link_value
  local package_entries relative_parent parent_component current_parent parent_state
  local -a parent_components=()
  declare -A target_owners=()
  declare -A parent_states=()

  LINK_OK=0
  LINK_MISSING=()
  LINK_CONFLICTS=()
  LINK_DUPLICATES=()
  LINK_REPLACE=()

  for package_name in "${STOW_PACKAGES[@]}"; do
    package_dir="$STOW_DIR/$package_name"
    package_entries=0
    while IFS= read -r -d '' source_path; do
      ((package_entries += 1))
      relative_path=${source_path#"$package_dir"/}
      target_path="$TARGET_DIR/$relative_path"

      if [[ -v "target_owners[$target_path]" ]]; then
        existing_source=${target_owners[$target_path]}
        LINK_DUPLICATES+=("$target_path <- $existing_source y $source_path")
        continue
      fi
      target_owners["$target_path"]=$source_path

      relative_parent=${relative_path%/*}
      if [[ "$relative_parent" != "$relative_path" ]]; then
        IFS='/' read -r -a parent_components <<< "$relative_parent"
        current_parent=$TARGET_DIR
        for parent_component in "${parent_components[@]}"; do
          [[ -n "$parent_component" ]] || continue
          current_parent="$current_parent/$parent_component"
          if [[ -v "parent_states[$current_parent]" ]]; then
            parent_state=${parent_states[$current_parent]}
            [[ "$parent_state" == "ok" ]] && continue
            break
          fi

          if [[ -L "$current_parent" ]]; then
            link_value=$(readlink -- "$current_parent" || true)
            LINK_CONFLICTS+=("$current_parent (directorio padre es symlink a $link_value)")
            parent_states["$current_parent"]="blocked"
            break
          elif [[ -e "$current_parent" && ! -d "$current_parent" ]]; then
            LINK_CONFLICTS+=("$current_parent (ruta padre existe y no es directorio)")
            parent_states["$current_parent"]="blocked"
            break
          elif [[ -d "$current_parent" ]]; then
            parent_states["$current_parent"]="ok"
          else
            parent_states["$current_parent"]="missing"
            break
          fi
        done
      fi

      if [[ -L "$target_path" ]]; then
        canonical_source=$(realpath -m -- "$source_path")
        canonical_target=$(realpath -m -- "$target_path")
        if [[ "$canonical_source" == "$canonical_target" ]]; then
          link_value=$(readlink -- "$target_path" || true)
          if [[ "$link_value" == /* ]]; then
            LINK_REPLACE+=("$target_path")
          else
            ((LINK_OK += 1))
          fi
        elif is_repo_symlink "$target_path"; then
          LINK_REPLACE+=("$target_path")
        else
          link_value=$(readlink -- "$target_path" || true)
          LINK_CONFLICTS+=("$target_path (symlink a $link_value)")
        fi
      elif [[ -e "$target_path" ]]; then
        LINK_CONFLICTS+=("$target_path (ya existe y no es el enlace esperado)")
      else
        LINK_MISSING+=("$target_path")
      fi
    done < <(find "$package_dir" -mindepth 1 \( -type f -o -type l \) -print0)

    (( package_entries > 0 )) || \
      LINK_CONFLICTS+=("$package_dir (paquete Stow vacío)")
  done
}

print_link_issues() {
  local issue

  for issue in "${LINK_DUPLICATES[@]}"; do
    error "ownership duplicado: $issue"
  done
  for issue in "${LINK_CONFLICTS[@]}"; do
    error "colisión: $issue"
  done
}

ensure_no_link_collisions() {
  inspect_links
  print_link_issues
  if (( ${#LINK_DUPLICATES[@]} > 0 || ${#LINK_CONFLICTS[@]} > 0 )); then
    return 1
  fi
  local replace_msg=""
  (( ${#LINK_REPLACE[@]} > 0 )) && replace_msg=", ${#LINK_REPLACE[@]} por actualizar"
  info "Preflight Stow: $LINK_OK enlaces correctos, ${#LINK_MISSING[@]} por crear$replace_msg, 0 colisiones"
  return 0
}

run_stow() {
  local operation=$1
  local simulate=$2
  local -a stow_command=(
    stow
    "--dir=$STOW_DIR"
    "--target=$TARGET_DIR"
    --no-folding
  )

  if [[ "$operation" == "delete" ]]; then
    stow_command+=(--delete)
  fi
  if [[ "$simulate" == 1 ]]; then
    stow_command+=(--simulate --verbose=1)
  else
    stow_command+=(--verbose=1)
  fi
  stow_command+=("${STOW_PACKAGES[@]}")

  format_command "${stow_command[@]}"
  "${stow_command[@]}"
}

validate_links_installed() {
  inspect_links
  print_link_issues
  if (( ${#LINK_DUPLICATES[@]} > 0 || ${#LINK_CONFLICTS[@]} > 0 || ${#LINK_MISSING[@]} > 0 )); then
    local missing_path
    for missing_path in "${LINK_MISSING[@]}"; do
      error "enlace ausente: $missing_path"
    done
    return 1
  fi
  info "Enlaces validados: $LINK_OK correctos"
  return 0
}

validate_links_unlinked() {
  inspect_links
  if (( LINK_OK > 0 )); then
    error "quedaron $LINK_OK enlaces que todavía apuntan al stow directory"
    return 1
  fi
  info "Unlink validado: no quedan enlaces administrados para el perfil"
  return 0
}

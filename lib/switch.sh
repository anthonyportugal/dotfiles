#!/usr/bin/env bash
# lib/switch.sh - Reversible changes to a target home: transactions and
# `dotfiles switch`.
#
# A transaction snapshots, before anything changes, every tracked path of the
# target and each of its parents (absent, directory, regular file copied into
# the transaction, or symlink with its value) plus the whole state directory
# ~/.local/state/dotfiles except its transactions/. txn_rollback puts back
# exactly that snapshot: it removes what appeared at a tracked path, restores
# the old links, files and directories, the state directory, and removes the
# directories the change created. A later rollback (mode keep) never deletes
# what may be the user's: files and directories found where the snapshot had
# something else are set aside under transactions/displaced-<time>, and only
# the state entries the snapshot holds or the change created are replaced;
# state others wrote since stays. A rollback never reads or writes through a
# parent directory that is a symlink now: the parent is put back first. The
# snapshot lives in ~/.local/state/dotfiles/transactions/<name>.pending while
# the change runs; its manifest is written last, so a pending one without a
# manifest changed nothing and is discarded.
#
# `dotfiles switch DIR` makes the checkout at DIR the active one for the
# target: it detects the current install (the pre-monorepo ecosystem under
# ~/.dotfiles or another monorepo checkout), translates its selection, checks
# collisions with the new checkout's own dry-run, and only then unlinks the
# old links and applies the new selection through DIR's bootstrap, inside a
# transaction kept as transactions/switch-last for `switch --rollback`.
#
# Reads TARGET_DIR, REPO_ROOT, PROGRAM_NAME, BASE_LAYERS and WM_NAME_PATTERN.
# Requires lib/colors.sh, lib/core.sh, lib/receipts.sh, lib/layers.sh and
# lib/components.sh.
#
# shellcheck shell=bash

TXN_DIR=""
declare -a TXN_PATHS=() TXN_TREES=() TXN_CHECKOUTS=()

txn_root() {
  printf '%s/transactions' "$(receipt_dir)"
}

# Adds target-relative paths $@ to the next snapshot.
txn_track() {
  local rel
  for rel in "$@"; do
    [[ -n "$rel" && "$rel" != /* && "$rel" != *$'\t'* && "$rel" != *$'\n'* ]] || \
      die "ruta no soportada en la transacción: $rel"
    TXN_PATHS+=("$rel")
  done
}

# Tracks every file or link of every Stow package under each directory $@
# (a layer's home/ or a package directory itself when it holds no packages).
txn_track_packages() {
  local dir package path
  for dir in "$@"; do
    [[ -d "$dir" ]] || continue
    for package in "$dir"/*/; do
      package=${package%/}
      while IFS= read -r -d '' path; do
        txn_track "${path#"$package"/}"
      done < <(find "$package" -mindepth 1 \( -type f -o -type l \) -print0)
    done
  done
}

# Tracks a directory that, when absent before, is removed whole on rollback
# (a component checkout the change clones).
txn_track_tree() {
  txn_track "$1"
  TXN_TREES+=("$1")
}

# What the engine and the layer hooks write outside the Stow packages: the
# dotfiles command link, the generated mimeapps.list, the Yazi flavor link of
# the theme engine and the bat cache the cli post-link builds.
txn_track_engine_outputs() {
  txn_track .local/bin/dotfiles .config/mimeapps.list .config/yazi/flavors/theme.yazi
  txn_track_tree .cache/bat
}

# Prints the first transaction left unfinished. One without a manifest was
# stopped before it changed anything (the manifest is written last, whole),
# so it is discarded with a warning instead of blocking later changes; with
# $1 = 0 (a dry-run) it is only reported.
txn_pending() {
  local discard=${1:-1} pending
  for pending in "$(txn_root)"/*.pending; do
    [[ -e "$pending" || -L "$pending" ]] || continue
    if [[ -d "$pending" && ! -L "$pending" && ! -e "$pending/manifest" ]]; then
      if (( discard == 1 )); then
        # One that cannot be removed is still unfinished: callers stop on it.
        rm -rf -- "$pending" || { printf '%s\n' "$pending"; return 0; }
        warn "se descartó $pending: un cambio interrumpido antes de modificar nada (sin manifiesto)"
      else
        warn "se descartará $pending con --apply: un cambio interrumpido antes de modificar nada (sin manifiesto)"
      fi
      continue
    fi
    printf '%s\n' "$pending"
    return 0
  done
  return 1
}

# Starts transaction $1; stops when an earlier one was left unfinished.
txn_begin() {
  local pending
  if pending=$(txn_pending); then
    die "quedó un cambio sin cerrar en $pending; reviértalo con '$PROGRAM_NAME switch --rollback --apply' antes de continuar"
  fi
  TXN_DIR="$(txn_root)/$1.pending"
  TXN_PATHS=()
  TXN_TREES=()
}

# Writes the snapshot of the tracked paths and the state directory; header
# lines $@ (key=value) describe the change.
txn_snapshot() {
  local state_dir state_rel rel parent path type value line
  local -A seen=() trees=()
  local -a nodes=() lines=()

  state_dir=$(receipt_dir)
  state_rel=${state_dir#"$TARGET_DIR"/}
  for rel in "${TXN_TREES[@]}"; do
    trees["$rel"]=1
  done
  for rel in "${TXN_PATHS[@]}" "$state_rel"; do
    parent=$rel
    while [[ ! -v "seen[$parent]" ]]; do
      seen["$parent"]=1
      nodes+=("$parent")
      [[ "$parent" == */* ]] || break
      parent=${parent%/*}
    done
  done

  # Recorded before the transaction directory exists, so its own parents
  # count as absent when they were.
  for rel in "${nodes[@]}"; do
    path="$TARGET_DIR/$rel"
    value=""
    if [[ -L "$path" ]]; then
      type="link"
      value=$(readlink -- "$path")
      [[ "$value" != *$'\t'* && "$value" != *$'\n'* ]] || die "enlace no soportado en la transacción: $path"
    elif [[ -d "$path" ]]; then
      type=dir
    elif [[ -f "$path" ]]; then
      type="file"
    elif [[ -e "$path" ]]; then
      die "tipo de archivo no soportado en la transacción: $path"
    elif [[ -v "trees[$rel]" ]]; then
      type=absent-tree
    else
      type=absent
    fi
    lines+=("$type"$'\t'"$rel"$'\t'"$value")
  done

  mkdir -p -- "$TXN_DIR/files"
  for line in "${lines[@]}"; do
    [[ "$line" == file$'\t'* ]] || continue
    rel=${line#file$'\t'}
    rel=${rel%$'\t'*}
    mkdir -p -- "$TXN_DIR/files/$(dirname -- "$rel")"
    cp -a -- "$TARGET_DIR/$rel" "$TXN_DIR/files/$rel"
  done
  if [[ -d "$state_dir" && ! -L "$state_dir" ]]; then
    tar -C "$state_dir" --exclude=./transactions -cf "$TXN_DIR/state.tar" .
  fi
  {
    printf '#created=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf '#%s\n' "$@"
    printf '%s\n' "${lines[@]}" | LC_ALL=C sort -t $'\t' -k2,2
  } > "$TXN_DIR/manifest.tmp"
  mv -T -- "$TXN_DIR/manifest.tmp" "$TXN_DIR/manifest"
}

# Removes the node at $1 for a rollback in mode $2: a regular file is moved
# under the displaced directory $3 in mode keep (it may be the user's).
_txn_remove() {
  local path=$1 mode=$2 displaced=$3 rel
  if [[ "$mode" == keep && -f "$path" && ! -L "$path" ]]; then
    rel=${path#"$TARGET_DIR"/}
    mkdir -p -- "$displaced/$(dirname -- "$rel")" && mv -- "$path" "$displaced/$rel" || return 1
    warn "se apartó $path en $displaced/$rel"
    return 0
  fi
  rm -f -- "$path"
}

# Succeeds when link $1 resolves into one of the checkouts in TXN_CHECKOUTS.
_txn_checkout_link() {
  local resolved checkout
  resolved=$(realpath -m -- "$1")
  for checkout in "${TXN_CHECKOUTS[@]}"; do
    [[ -n "$checkout" && "$resolved" == "$checkout"/* ]] && return 0
  done
  return 1
}

# Removes directory $1, which the snapshot did not hold as a directory, for a
# rollback in mode $2. In mode keep its content may be the user's: links into
# a checkout go, anything else is set aside under the displaced directory $3,
# and the directories go once empty. In mode discard the change just created
# it, so it goes whole.
_txn_remove_dir() {
  local path=$1 mode=$2 displaced=$3 entry rel moved=0
  if [[ "$mode" != keep ]]; then
    rm -rf -- "$path"
    return
  fi
  while IFS= read -r -d '' entry; do
    if [[ -L "$entry" ]] && _txn_checkout_link "$entry"; then
      rm -f -- "$entry" || return 1
    elif [[ -d "$entry" && ! -L "$entry" ]]; then
      rmdir -- "$entry" || return 1
    else
      rel=${entry#"$TARGET_DIR"/}
      mkdir -p -- "$displaced/$(dirname -- "$rel")" && mv -- "$entry" "$displaced/$rel" || return 1
      moved=1
    fi
  done < <(find "$path" -mindepth 1 -depth -print0)
  rmdir -- "$path" || return 1
  (( moved == 0 )) || warn "se apartó el contenido de $path en $displaced/${path#"$TARGET_DIR"/}"
}

# Prints the shallowest parent of target-relative path $1 that is a symlink
# now but not the very link the snapshot recorded there (same value); a
# rollback never reads or writes through one. A parent that was already that
# link before the change (state or cache on another disk) is used as is.
# Reads txn_rollback's recorded_types and recorded_values.
_txn_linked_parent() {
  local parent=$1 linked=""
  while [[ "$parent" == */* ]]; do
    parent=${parent%/*}
    [[ -L "$TARGET_DIR/$parent" ]] || continue
    if [[ "${recorded_types[$parent]:-}" == link && \
          "$(readlink -- "$TARGET_DIR/$parent")" == "${recorded_values[$parent]:-}" ]]; then
      continue
    fi
    linked=$parent
  done
  [[ -n "$linked" ]] || return 1
  printf '%s\n' "$linked"
}

# Prints the top-level entries of the state snapshot in transaction $1.
_txn_state_entries() {
  [[ -f "$1/state.tar" ]] || return 0
  tar -tf "$1/state.tar" | sed -e 's|^\./||' -e 's|/.*||' | grep -v '^$' | sort -u
}

# Puts the state snapshot of transaction $1 back into $3. In mode discard
# everything else goes (the change just ran). In mode keep only entries the
# snapshot holds or the change created are replaced, and their current
# copies are set aside under $4; anything else written since stays.
_txn_restore_state() {
  local dir=$1 mode=$2 state_dir=$3 displaced=$4 entry
  local -A owned=()

  if [[ "$mode" == discard ]]; then
    find "$state_dir" -mindepth 1 -maxdepth 1 ! -name transactions -exec rm -rf -- {} + || return 1
  else
    while IFS= read -r entry; do owned[$entry]=1; done < <(_txn_state_entries "$dir")
    if [[ -f "$dir/state-created" ]]; then
      while IFS= read -r entry; do [[ -z "$entry" ]] || owned[$entry]=1; done < "$dir/state-created"
    fi
    for entry in "${!owned[@]}"; do
      [[ -e "$state_dir/$entry" || -L "$state_dir/$entry" ]] || continue
      mkdir -p -- "$displaced/${state_dir#"$TARGET_DIR"/}" || return 1
      mv -- "$state_dir/$entry" "$displaced/${state_dir#"$TARGET_DIR"/}/$entry" || return 1
    done
  fi
  [[ ! -f "$dir/state.tar" ]] || tar -C "$state_dir" -xf "$dir/state.tar" || return 1
}

# Restores the snapshot of transaction directory $1. Mode $2 is discard (the
# change just failed: what appeared is removed) or keep (a later rollback:
# regular files that appeared are set aside, never deleted). Removes the
# transaction directory when everything was restored.
txn_rollback() {
  local dir=$1 mode=$2 failed=0 index type rel value path state_dir displaced linked
  local -a types=() rels=() values=()
  local -A recorded_types=() recorded_values=()

  [[ -f "$dir/manifest" ]] || { error "no existe el manifiesto $dir/manifest"; return 1; }
  TXN_CHECKOUTS=("${REPO_ROOT:-}")
  while IFS=$'\t' read -r type rel value; do
    case "$type" in
      '#to='*|'#from='*) TXN_CHECKOUTS+=("${type#*=}") ;;
    esac
    [[ -n "$type" && "$type" != \#* ]] || continue
    types+=("$type") rels+=("$rel") values+=("${value:-}")
    recorded_types["$rel"]=$type
    recorded_values["$rel"]=${value:-}
  done < "$dir/manifest"
  displaced="$(txn_root)/displaced-$(date -u +%Y%m%dT%H%M%SZ)"

  # Deepest first: whatever is not what the snapshot recorded goes. A path
  # under a parent that is a symlink now is left alone: the parent comes
  # later and is put back as recorded, so nothing is touched through it.
  for (( index = ${#rels[@]} - 1; index >= 0; index-- )); do
    type=${types[index]} rel=${rels[index]} value=${values[index]}
    path="$TARGET_DIR/$rel"
    ! _txn_linked_parent "$rel" >/dev/null || continue
    case "$type" in
      absent|absent-tree)
        if [[ -L "$path" || ( -e "$path" && ! -d "$path" ) ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        elif [[ "$type" == absent-tree && -d "$path" ]]; then
          _txn_remove_dir "$path" "$mode" "$displaced" || failed=1
        fi
        ;;
      link|file)
        if [[ "$type" == link && -L "$path" && "$(readlink -- "$path")" == "$value" ]]; then
          :
        elif [[ "$type" == file && -f "$path" && ! -L "$path" ]] && cmp -s -- "$dir/files/$rel" "$path"; then
          :
        elif [[ -L "$path" || -f "$path" ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        elif [[ -d "$path" ]]; then
          _txn_remove_dir "$path" "$mode" "$displaced" || failed=1
          [[ -e "$path" ]] || warn "se reemplazó el directorio $path por lo que había antes del cambio ($type)"
        fi
        ;;
      dir)
        if [[ -L "$path" || ( -e "$path" && ! -d "$path" ) ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        fi
        ;;
    esac
  done

  # Shallowest first: directories, links and files come back. Under a parent
  # that is a link the snapshot recorded, the content comes with the link;
  # under any other link nothing is written and the rollback fails.
  for index in "${!rels[@]}"; do
    type=${types[index]} rel=${rels[index]} value=${values[index]}
    path="$TARGET_DIR/$rel"
    if linked=$(_txn_linked_parent "$rel"); then
      [[ "${recorded_types[$linked]:-}" == link ]] && continue
      error "no se restaura $path: $TARGET_DIR/$linked es un enlace que el cambio no tenía"
      failed=1
      continue
    fi
    case "$type" in
      dir) [[ -d "$path" ]] || mkdir -- "$path" || failed=1 ;;
      link) [[ -L "$path" ]] || ln -sT -- "$value" "$path" || failed=1 ;;
      file) [[ -e "$path" || -L "$path" ]] || cp -a -T -- "$dir/files/$rel" "$path" || failed=1 ;;
    esac
  done

  state_dir=$(receipt_dir)
  if _txn_linked_parent "${state_dir#"$TARGET_DIR"/}" >/dev/null; then
    error "no se restaura el estado: un directorio padre de $state_dir es un enlace"
    failed=1
  elif [[ -d "$state_dir" && ! -L "$state_dir" ]]; then
    _txn_restore_state "$dir" "$mode" "$state_dir" "$displaced" || failed=1
  fi

  if (( failed == 1 )); then
    error "la reversión quedó incompleta; el manifiesto se conserva en $dir"
    return 1
  fi
  rm -rf -- "$dir"
  rmdir -- "$(txn_root)" 2>/dev/null || true

  # Directories the change created go last, once empty.
  for (( index = ${#rels[@]} - 1; index >= 0; index-- )); do
    [[ "${types[index]}" == absent* ]] || continue
    path="$TARGET_DIR/${rels[index]}"
    [[ -d "$path" && ! -L "$path" ]] || continue
    ! _txn_linked_parent "${rels[index]}" >/dev/null || continue
    rmdir -- "$path" 2>/dev/null || warn "se conserva $path: no estaba antes del cambio y no quedó vacío"
  done
  return 0
}

# Records in transaction $1 the top-level state entries the change created,
# so a later rollback replaces them but keeps what others wrote since.
_txn_record_created_state() {
  local dir=$1 state_dir entry
  local -A before=()
  state_dir=$(receipt_dir)
  [[ -d "$state_dir" ]] || return 0
  while IFS= read -r entry; do before[$entry]=1; done < <(_txn_state_entries "$dir")
  : > "$dir/state-created"
  for entry in "$state_dir"/* "$state_dir"/.[!.]*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    entry=${entry##*/}
    [[ "$entry" == transactions || -n "${before[$entry]:-}" ]] || printf '%s\n' "$entry" >> "$dir/state-created"
  done
}

# Closes the pending transaction: kept as $1 (for a later rollback) or removed.
txn_commit() {
  local keep=${1-}
  if [[ -n "$keep" ]]; then
    _txn_record_created_state "$TXN_DIR"
    rm -rf -- "$(txn_root)/${keep:?}"
    mv -T -- "$TXN_DIR" "$(txn_root)/$keep"
  else
    rm -rf -- "$TXN_DIR"
    rmdir -- "$(txn_root)" 2>/dev/null || true
  fi
  TXN_DIR=""
}

# ---------------------------------------------------------------------------
# dotfiles switch

SW_NEW="" SW_OLD="" SW_KIND="" SW_PROFILE="core" SW_OVERLAY="" SW_OVERLAY_SOURCE=""
SW_THEME="" SW_THEME_FROM="" SW_CARRY_MIMEAPPS=0 SW_ALREADY_ACTIVE=0
declare -a SW_ROOTS=() SW_LINKS=() SW_WMS=() SW_LAYERS=() SW_FEATURES=()
declare -a SW_NEW_COMPONENTS=() SW_DROP_RECEIPTS=() SW_NOT_MIGRATED=() SW_ARGS=()
declare -a SW_NEW_OPTIONAL=() SW_NEW_FEATURES=()

# Legacy walls links the old base installer created outside Stow.
SW_LEGACY_EXTRA_LINKS=(.local/bin/walls .local/share/wallpapers Pictures/Wallpapers)

# True when link $1 (absolute) resolves into one of the directories in array $2.
_sw_link_into() {
  local dest root
  local -n _sw_roots_ref=$2
  dest=$(realpath -m -- "$1")
  for root in "${_sw_roots_ref[@]}"; do
    [[ "$dest" == "$root" || "$dest" == "$root/"* ]] && return 0
  done
  return 1
}

# Fills SW_LINKS with every candidate path in array $1 (or one of its parents)
# that is a symlink resolving into one of the roots in SW_ROOTS.
_sw_collect_links() {
  local -n _sw_candidates_ref=$1
  local rel prefix part
  local -A found=()
  local -a parts=()

  SW_LINKS=()
  for rel in "${_sw_candidates_ref[@]}"; do
    IFS=/ read -r -a parts <<< "$rel"
    prefix=""
    for part in "${parts[@]}"; do
      prefix=${prefix:+$prefix/}$part
      if [[ -L "$TARGET_DIR/$prefix" ]]; then
        if [[ ! -v "found[$prefix]" ]] && _sw_link_into "$TARGET_DIR/$prefix" SW_ROOTS; then
          found["$prefix"]=1
          SW_LINKS+=("$prefix")
        fi
        break
      fi
      [[ -d "$TARGET_DIR/$prefix" ]] || break
    done
  done
}

# Appends to array $2 the target-relative path of every file of every Stow
# package under directory $1.
_sw_package_paths() {
  local package path
  local -n _sw_paths_ref=$2
  [[ -d "$1" ]] || return 0
  for package in "$1"/*/; do
    package=${package%/}
    while IFS= read -r -d '' path; do
      _sw_paths_ref+=("${path#"$package"/}")
    done < <(find "$package" -mindepth 1 \( -type f -o -type l \) -print0)
  done
}

# Reads the opt-in layers and features of the new checkout (and overlay).
_sw_read_new_layers() {
  local layer_dir name feature
  local -A conf=()
  local -a declared=()

  SW_NEW_OPTIONAL=() SW_NEW_FEATURES=()
  for layer_dir in "$SW_NEW/layers"/*/ ${SW_OVERLAY:+"$SW_OVERLAY/layers"/*/}; do
    layer_dir=${layer_dir%/}
    name=${layer_dir##*/}
    [[ "$name" != wm && -f "$layer_dir/layer.conf" ]] || continue
    read_layer_conf "$layer_dir" conf
    [[ "$layer_dir" != "$SW_NEW/layers/$name" ]] || array_contains BASE_LAYERS "$name" || SW_NEW_OPTIONAL+=("$name")
    read -r -a declared <<< "${conf[features]:-}"
    for feature in "${declared[@]}"; do
      SW_NEW_FEATURES+=("$feature")
    done
  done
}

# Picks the overlay of the new selection: --overlay ($1), the recorded one
# ($3), then, when $4 is 1, a sibling checkout of the new one (DIR-private or
# dotfiles-private next to it). --no-overlay ($2) picks none.
_sw_resolve_overlay() {
  local explicit=$1 no_overlay=$2 recorded=$3 sibling=${4:-1} candidate
  SW_OVERLAY="" SW_OVERLAY_SOURCE=""
  if (( no_overlay == 1 )); then
    SW_OVERLAY_SOURCE="--no-overlay"
    return 0
  fi
  if [[ -n "$explicit" ]]; then
    SW_OVERLAY=$(realpath -m -- "$explicit") SW_OVERLAY_SOURCE="--overlay"
  elif [[ -n "$recorded" && -d "$recorded/layers" ]]; then
    SW_OVERLAY=$(realpath -m -- "$recorded") SW_OVERLAY_SOURCE="recibo de selección"
  elif (( sibling == 1 )); then
    for candidate in "$SW_NEW-private" "${SW_NEW%/*}/dotfiles-private"; do
      [[ -d "$candidate/layers" ]] || continue
      SW_OVERLAY=$(realpath -m -- "$candidate") SW_OVERLAY_SOURCE="checkout hermano"
      break
    done
  fi
  [[ -z "$SW_OVERLAY" || -d "$SW_OVERLAY/layers" ]] || \
    die "el overlay no contiene layers/: $SW_OVERLAY"
}

# Prints where the current install of TARGET_DIR lives: --from $1, the
# dotfiles command link, or the legacy ~/.dotfiles ecosystem; fails when
# none of them is there.
switch_install_root() {
  local from=$1 dest cli="$TARGET_DIR/.local/bin/dotfiles"

  if [[ -n "$from" ]]; then
    realpath -m -- "$from"
    return 0
  fi
  if [[ -L "$cli" ]]; then
    dest=$(realpath -m -- "$cli")
    if [[ "$dest" == */bin/dotfiles ]]; then
      printf '%s\n' "${dest%/bin/dotfiles}"
      return 0
    fi
  fi
  [[ -d "$TARGET_DIR/.dotfiles/base/home" ]] || return 1
  printf '%s\n' "$TARGET_DIR/.dotfiles"
}

# Locates the current install (switch_install_root) and its kind.
_sw_detect() {
  local from=$1 root

  root=$(switch_install_root "$from") || \
    die "no se detectó la instalación actual en $TARGET_DIR (ni $TARGET_DIR/.local/bin/dotfiles ni $TARGET_DIR/.dotfiles/base); indíquela con --from RUTA"

  if [[ -d "$root/layers" ]]; then
    SW_KIND=monorepo SW_OLD=$root
  elif [[ "${root##*/}" == base && -d "$root/home" ]]; then
    SW_KIND=legacy SW_OLD=${root%/*}
  elif [[ -d "$root/base/home" ]]; then
    SW_KIND=legacy SW_OLD=$root
  else
    die "$root no es un checkout de dotfiles reconocido (ni layers/ ni base/home/)"
  fi
}

# Translates the selection of a monorepo checkout from its selection receipt.
_sw_translate_monorepo() {
  local overlay_arg=$1 no_overlay=$2 entry old_overlay
  local -A recorded=()
  local -a entries=() candidates=()
  local -A saved_components=()

  read_receipt dotfiles recorded || \
    die "no hay recibo de selección en $(receipt_dir); aplique primero el checkout actual con '$PROGRAM_NAME bootstrap --apply'"
  case "${recorded[PROFILE]:-}" in
    core|cli|desktop) SW_PROFILE=${recorded[PROFILE]} ;;
    *) SW_PROFILE=core; SW_NOT_MIGRATED+=("perfil '${recorded[PROFILE]:-}' (se usa core)") ;;
  esac
  old_overlay=${recorded[OVERLAY]:-}
  [[ -z "$old_overlay" ]] || old_overlay=$(realpath -m -- "$old_overlay")
  # A selection recorded without an overlay keeps none unless one is asked for.
  _sw_resolve_overlay "$overlay_arg" "$no_overlay" "$old_overlay" "$([[ -n "$old_overlay" ]] && echo 1 || echo 0)"
  [[ -n "$SW_OVERLAY$SW_OVERLAY_SOURCE" ]] || SW_OVERLAY_SOURCE="recibo de selección"
  _sw_read_new_layers

  read -r -a entries <<< "${recorded[WMS]:-}"
  for entry in "${entries[@]}"; do
    if [[ "$entry" =~ $WM_NAME_PATTERN && -f "$SW_NEW/layers/wm/$entry/layer.conf" ]]; then
      append_unique SW_WMS "$entry"
    else
      SW_NOT_MIGRATED+=("WM $entry (no existe layers/wm/$entry en el checkout nuevo)")
    fi
  done
  read -r -a entries <<< "${recorded[LAYERS]:-}"
  for entry in "${entries[@]}"; do
    if array_contains SW_NEW_OPTIONAL "$entry"; then
      append_unique SW_LAYERS "$entry"
    else
      SW_NOT_MIGRATED+=("capa $entry (el checkout nuevo no la tiene)")
    fi
  done
  read -r -a entries <<< "${recorded[FEATURES]:-}"
  for entry in "${entries[@]}"; do
    if array_contains SW_NEW_FEATURES "$entry"; then
      append_unique SW_FEATURES "$entry"
    else
      SW_NOT_MIGRATED+=("feature $entry (ninguna capa del checkout nuevo ni del overlay la declara)")
    fi
  done
  if read_receipt components saved_components; then
    read -r -a entries <<< "${saved_components[COMPONENTS]:-}"
    for entry in "${entries[@]}"; do
      [[ -n "${COMPONENT_URLS[$entry]:-}" ]] || SW_NOT_MIGRATED+=("componente $entry (no está en components.conf del checkout nuevo)")
    done
  fi

  SW_ROOTS=("$SW_OLD")
  if [[ -n "$old_overlay" && "$old_overlay" != "$SW_OVERLAY" ]]; then
    SW_ROOTS+=("$old_overlay")
    _sw_package_paths_layers "$old_overlay/layers" candidates
  fi
  _sw_package_paths_layers "$SW_OLD/layers" candidates
  candidates+=(.local/bin/dotfiles .config/mimeapps.list)
  _sw_collect_links candidates
}

# Appends the package paths of every layer under layers root $1 (and its wm/).
_sw_package_paths_layers() {
  local layer_dir
  for layer_dir in "$1"/*/ "$1"/wm/*/; do
    [[ -f "$layer_dir/layer.conf" ]] || continue
    _sw_package_paths "${layer_dir%/}/home" "$2"
  done
}

# Translates the pre-monorepo ecosystem under SW_OLD: base packages to a
# profile, wm/<x> to WM layers, private to the overlay, walls to a component
# and the per-WM theme to the shared theme state.
_sw_translate_legacy() {
  local overlay_arg=$1 no_overlay=$2
  local root rel dest name wm rank highest=-1 base_layer token theme_root current_wm id
  local -a all_roots=() candidates=() tokens=() theme_wms=()
  local -A private=() roots_used=() base_packages=()

  for root in "$SW_OLD/base" "$SW_OLD/private" "$SW_OLD/walls" "$SW_OLD"/wm/*; do
    [[ -d "$root" ]] || continue
    all_roots+=("$(realpath -m -- "$root")")
    _sw_package_paths "$root/home" candidates
  done
  candidates+=(.local/bin/dotfiles .config/mimeapps.list "${SW_LEGACY_EXTRA_LINKS[@]}")
  for name in "${COMPONENT_NAMES[@]}"; do
    for token in ${COMPONENT_LINKS[$name]}; do
      candidates+=("${token#*=}")
    done
  done

  # Which old repository each link belongs to.
  SW_ROOTS=("${all_roots[@]}")
  _sw_collect_links candidates
  for rel in "${SW_LINKS[@]}"; do
    dest=$(realpath -m -- "$TARGET_DIR/$rel")
    for root in "${all_roots[@]}"; do
      [[ "$dest" == "$root" || "$dest" == "$root/"* ]] || continue
      roots_used["$root"]=1
      if [[ "$root" == */base && "$dest" == "$root/home/"* ]]; then
        name=${dest#"$root/home/"}
        base_packages["${name%%/*}"]=1
      fi
      break
    done
  done

  local -a replaced=()
  local base_root
  base_root=$(realpath -m -- "$SW_OLD/base")
  replaced+=("$base_root")

  # base: each linked package raises the profile to the base layer owning it.
  for name in "${!base_packages[@]}"; do
    rank=-1
    for base_layer in "${!BASE_LAYERS[@]}"; do
      [[ -d "$SW_NEW/layers/${BASE_LAYERS[base_layer]}/home/$name" ]] && rank=$base_layer
    done
    if (( rank < 0 )); then
      SW_NOT_MIGRATED+=("paquete base $name (sin equivalente en el checkout nuevo)")
    elif (( rank > highest )); then
      highest=$rank
    fi
  done

  # wm/<x>: linked or with a receipt.
  for root in "$SW_OLD"/wm/*; do
    [[ -d "$root" ]] || continue
    wm=${root##*/}
    root=$(realpath -m -- "$root")
    [[ -v "roots_used[$root]" ]] || { [[ "$wm" =~ $WM_NAME_PATTERN && -f "$(receipt_path "$wm")" ]]; } || continue
    if [[ "$wm" =~ $WM_NAME_PATTERN && -f "$SW_NEW/layers/wm/$wm/layer.conf" ]]; then
      append_unique SW_WMS "$wm"
      replaced+=("$root")
    else
      SW_NOT_MIGRATED+=("WM $wm (no existe layers/wm/$wm; sus enlaces se conservan)")
    fi
  done
  (( ${#SW_WMS[@]} == 0 )) || highest=2
  (( highest < 0 )) || SW_PROFILE=${BASE_LAYERS[highest]}

  # private: the overlay of the new selection.
  root=$(realpath -m -- "$SW_OLD/private")
  if [[ -v "roots_used[$root]" ]] || read_receipt private private; then
    read_receipt private private || true
    _sw_resolve_overlay "$overlay_arg" "$no_overlay" ""
    if [[ -z "$SW_OVERLAY" && $no_overlay -eq 1 ]]; then
      SW_NOT_MIGRATED+=("private (--no-overlay; sus enlaces se conservan)")
    elif [[ -z "$SW_OVERLAY" ]]; then
      SW_NOT_MIGRATED+=("private (no se encontró el overlay; indíquelo con --overlay RUTA; sus enlaces se conservan)")
    else
      replaced+=("$root")
      [[ ! -f "$(receipt_path private)" ]] || SW_DROP_RECEIPTS+=(private)
      _sw_read_new_layers
      case "${private[PROFILE]:-core}" in
        core) ;;
        development)
          if array_contains SW_NEW_OPTIONAL dev; then
            append_unique SW_LAYERS dev
          else
            SW_NOT_MIGRATED+=("perfil privado development (el checkout nuevo no tiene la capa dev)")
          fi
          ;;
        *) SW_NOT_MIGRATED+=("perfil privado ${private[PROFILE]}") ;;
      esac
      read -r -a tokens <<< "${private[WORK]:-}"
      for token in "${tokens[@]}"; do
        if array_contains SW_NEW_FEATURES "work-$token"; then
          append_unique SW_FEATURES "work-$token"
        else
          SW_NOT_MIGRATED+=("componente laboral $token (el overlay no declara la feature work-$token)")
        fi
      done
    fi
  elif [[ -n "$overlay_arg" || $no_overlay -eq 1 ]]; then
    # No old private install: an overlay applies only when asked for.
    _sw_resolve_overlay "$overlay_arg" "$no_overlay" ""
  fi

  # walls: the component of components.conf.
  root=$(realpath -m -- "$SW_OLD/walls")
  if [[ -v "roots_used[$root]" ]]; then
    if [[ -n "${COMPONENT_URLS[walls]:-}" ]]; then
      replaced+=("$root")
      SW_NEW_COMPONENTS+=(walls)
    else
      SW_NOT_MIGRATED+=("walls (components.conf del checkout nuevo no lo declara; sus enlaces se conservan)")
    fi
  fi

  [[ ! -d "$SW_OLD/agent-harness" ]] || SW_NOT_MIGRATED+=("agent-harness (proyecto independiente; sus enlaces se conservan)")
  [[ ! -d "$SW_OLD/system" ]] || SW_NOT_MIGRATED+=("system (capa root: aplíquela con '$PROGRAM_NAME system setup')")

  # Only the links of the replaced repositories go.
  SW_ROOTS=("${replaced[@]}")
  candidates=("${SW_LINKS[@]}")
  _sw_collect_links candidates

  # Theme: the WM the shared current link points to, then the selected WMs.
  theme_root="$TARGET_DIR/.local/state/dotfiles/theme"
  if [[ -L "$theme_root/current" && "$(readlink -- "$theme_root/current")" =~ ^\.\./\.\./([a-z0-9_-]+)/theme/current$ ]]; then
    current_wm=${BASH_REMATCH[1]}
    theme_wms+=("$current_wm")
  fi
  for wm in "${SW_WMS[@]}"; do
    append_unique theme_wms "$wm"
  done
  for wm in "${theme_wms[@]}"; do
    [[ -r "$TARGET_DIR/.local/state/$wm/theme/selected" ]] || continue
    id=$(trim_line "$(<"$TARGET_DIR/.local/state/$wm/theme/selected")")
    if [[ -z "$SW_THEME" ]]; then
      if [[ -f "$theme_root/selected" ]]; then
        SW_NOT_MIGRATED+=("tema $id de $wm (ya hay un tema elegido: $(<"$theme_root/selected"))")
        SW_THEME=-
      elif [[ "$id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && -f "$SW_NEW/themes/palettes/$id.conf" ]]; then
        SW_THEME=$id SW_THEME_FROM=$wm
      else
        SW_NOT_MIGRATED+=("tema $id de $wm (no existe themes/palettes/$id.conf)")
        SW_THEME=-
      fi
    elif [[ "$SW_THEME" != - && "$id" != "$SW_THEME" ]]; then
      SW_NOT_MIGRATED+=("tema $id de $wm (un solo tema para todos los WMs: $SW_THEME)")
    fi
  done
  [[ "$SW_THEME" != - ]] || SW_THEME=""
}

# The new checkout's bootstrap arguments for the translated selection.
_sw_build_args() {
  local with_packages=$1 entry
  SW_ARGS=(bootstrap --target "$TARGET_DIR" --profile "$SW_PROFILE")
  for entry in "${SW_WMS[@]}"; do SW_ARGS+=(--wm "$entry"); done
  for entry in "${SW_LAYERS[@]}"; do SW_ARGS+=(--layer "$entry"); done
  for entry in "${SW_FEATURES[@]}"; do SW_ARGS+=(--feature "$entry"); done
  if [[ -n "$SW_OVERLAY" ]]; then
    SW_ARGS+=(--overlay "$SW_OVERLAY")
  else
    SW_ARGS+=(--no-overlay)
  fi
  (( with_packages == 1 )) || SW_ARGS+=(--stow-only)
}

# Prints the plan of the prepared switch; mode $1 (apply or dry-run) is left
# out when empty (the wizard asks for it after the plan).
_sw_print_plan() {
  local mode=$1 item
  info "Plan del cambio de checkout"
  [[ -z "$mode" ]] || printf '  %-24s %s\n' 'Modo:' "$mode"
  printf '  %-24s %s\n' 'Target:' "$TARGET_DIR"
  if [[ "$SW_KIND" == legacy ]]; then
    printf '  %-24s %s\n' 'Instalación actual:' "$SW_OLD (ecosistema anterior)"
  else
    printf '  %-24s %s\n' 'Instalación actual:' "$SW_OLD"
  fi
  printf '  %-24s %s\n' 'Checkout nuevo:' "$SW_NEW"
  printf '  %-24s %s\n' 'Perfil:' "$SW_PROFILE"
  print_array "WMs" SW_WMS
  print_array "Capas opcionales" SW_LAYERS
  print_array "Features" SW_FEATURES
  if [[ -n "$SW_OVERLAY" ]]; then
    printf '  %-24s %s (%s)\n' 'Overlay:' "$SW_OVERLAY" "$SW_OVERLAY_SOURCE"
  else
    printf '  %-24s %s\n' 'Overlay:' "ninguno${SW_OVERLAY_SOURCE:+ ($SW_OVERLAY_SOURCE)}"
  fi
  (( ${#SW_NEW_COMPONENTS[@]} == 0 )) || print_array "Componentes nuevos" SW_NEW_COMPONENTS
  [[ -z "$SW_THEME" ]] || printf '  %-24s %s (de %s)\n' 'Tema:' "$SW_THEME" "$SW_THEME_FROM"
  (( SW_CARRY_MIMEAPPS == 0 )) || \
    printf '  %-24s %s\n' 'mimeapps.list:' 'se conservan sus entradas antes de retirar el enlace'
  (( ${#SW_DROP_RECEIPTS[@]} == 0 )) || print_array "Recibos migrados" SW_DROP_RECEIPTS
  printf '  %-24s %s\n' 'Enlaces a reemplazar:' "${#SW_LINKS[@]}"
  for item in "${SW_NOT_MIGRATED[@]}"; do
    printf '  %-24s %s\n' 'No migrado:' "$item"
  done
}

# Stops, before anything changes, when the new selection would collide with
# a real file or a foreign link: the new checkout's own dry-run, with the
# links of the replaced checkouts counted as replaceable.
_sw_preflight() {
  local name token path roots output status=0
  local -a dsts=()

  for name in "${SW_NEW_COMPONENTS[@]}"; do
    read -r -a dsts <<< "${COMPONENT_LINKS[$name]}"
    for token in "${dsts[@]}"; do
      path="$TARGET_DIR/${token#*=}"
      [[ -e "$path" || -L "$path" ]] || continue
      if [[ ! -L "$path" ]] || ! _sw_link_into "$path" SW_ROOTS; then
        error "colisión: $path (ya existe y no es un enlace del checkout anterior)"
        status=1
      fi
    done
  done

  printf -v roots '%s:' "${SW_ROOTS[@]}"
  info "Preflight del checkout nuevo (dry-run de su bootstrap)"
  output=$(DOTFILES_STRICT_LINKS=1 DOTFILES_REPLACEABLE_ROOTS=${roots%:} "$SW_NEW/bin/dotfiles" "${SW_ARGS[@]}" 2>&1) || {
    printf '%s\n' "$output" >&2
    status=1
  }
  (( status == 0 )) || die "switch abortado por colisiones o un preflight fallido; no se modificó nada"
  info "Preflight del checkout nuevo: sin colisiones"
}

# Every change of the switch, run inside the transaction.
_sw_execute() {
  local rel path source tmp name
  local -a components=()

  for rel in "${SW_LINKS[@]}"; do
    path="$TARGET_DIR/$rel"
    [[ -L "$path" ]] || continue
    if [[ "$rel" == .config/mimeapps.list ]] && source=$(realpath -e -- "$path" 2>/dev/null) && [[ -f "$source" ]]; then
      # Apps wrote their associations through the old link: they stay as a
      # real file that the desktop layer merges with its defaults.
      tmp="$path.switch.$$"
      cp -- "$source" "$tmp"
      mv -f -- "$tmp" "$path"
      info "mimeapps.list conservado como archivo: $path"
    else
      rm -f -- "$path"
    fi
  done
  info "Enlaces del checkout anterior retirados: ${#SW_LINKS[@]}"

  if [[ -n "$SW_THEME" ]]; then
    mkdir -p -- "$(receipt_dir)/theme"
    printf '%s\n' "$SW_THEME" > "$(receipt_dir)/theme/selected"
    info "Tema elegido migrado: $SW_THEME"
  fi
  if (( ${#SW_NEW_COMPONENTS[@]} > 0 )); then
    recorded_components components
    for name in "${SW_NEW_COMPONENTS[@]}"; do
      append_unique components "$name"
    done
    write_receipt components COMPONENTS="${components[*]}"
  fi
  for name in "${SW_DROP_RECEIPTS[@]}"; do
    rm -f -- "$(receipt_path "$name")"
  done
  # The new checkout records its own selection; a recorded one is not retired
  # against it (its links are already gone).
  rm -f -- "$(receipt_path dotfiles)"

  info "Aplicando la selección con el checkout nuevo"
  "$SW_NEW/bin/dotfiles" "${SW_ARGS[@]}" --apply
}

_sw_apply() {
  local status=0 layer_dir name token dir

  txn_begin switch
  txn_track "${SW_LINKS[@]}"
  txn_track_engine_outputs
  for layer_dir in "$SW_NEW/layers"/*/ "$SW_NEW/layers"/wm/*/ ${SW_OVERLAY:+"$SW_OVERLAY/layers"/*/}; do
    if [[ -f "$layer_dir/layer.conf" ]]; then
      txn_track_packages "${layer_dir%/}/home"
    fi
  done
  for name in "${COMPONENT_NAMES[@]}"; do
    dir=$(component_dir "$name")
    txn_track_tree "${dir#"$TARGET_DIR"/}"
    for token in ${COMPONENT_LINKS[$name]}; do
      txn_track "${token#*=}"
    done
  done
  txn_snapshot kind=switch "from=$SW_OLD" "to=$SW_NEW" "links=${#SW_LINKS[@]}"
  info "Manifiesto de reversión: $TXN_DIR/manifest (${#SW_LINKS[@]} enlaces reemplazados)"

  set +e
  ( set -e; _sw_execute )
  status=$?
  set -e
  if (( status != 0 )); then
    error "el cambio de checkout falló; restaurando el estado anterior"
    txn_rollback "$TXN_DIR" discard || \
      die "el cambio falló y la reversión quedó incompleta; reintente con '$PROGRAM_NAME switch --rollback --apply'"
    die "el cambio de checkout falló; se restauró el estado anterior del target (ver los errores de arriba)"
  fi
  txn_commit switch-last
  success "Checkout activo: $SW_NEW. Para deshacerlo: $PROGRAM_NAME switch --rollback --apply"
}

# Prints the transaction a rollback with apply mode $1 restores: a change left
# unfinished, otherwise the last switch. Stops when there is none.
switch_rollback_dir() {
  local apply=$1 dir=""
  dir=$(txn_pending "$apply") || dir="$(txn_root)/switch-last"
  [[ -f "$dir/manifest" ]] || die "no hay ningún cambio que revertir en $TARGET_DIR"
  printf '%s\n' "$dir"
}

# Prints the plan of the rollback of transaction $1 in mode $2 (no mode line
# when empty).
switch_print_rollback_plan() {
  local dir=$1 mode=$2 header
  info "Plan de la reversión"
  [[ -z "$mode" ]] || printf '  %-24s %s\n' 'Modo:' "$mode"
  printf '  %-24s %s\n' 'Target:' "$TARGET_DIR" 'Manifiesto:' "$dir/manifest"
  while IFS= read -r header; do
    [[ "$header" == \#* ]] || continue
    header=${header#\#}
    printf '  %-24s %s\n' "${header%%=*}:" "${header#*=}"
  done < "$dir/manifest"
}

# Restores the target from transaction $1.
switch_rollback_apply() {
  txn_rollback "$1" keep || die "la reversión quedó incompleta; revise los errores y reintente"
  success "Se restauró el estado anterior al cambio"
}

# Restores the last switch (or a change left unfinished) with apply mode $1.
_sw_rollback() {
  local apply=$1 dir
  dir=$(switch_rollback_dir "$apply") || exit 1
  switch_print_rollback_plan "$dir" "$( (( apply == 1 )) && echo apply || echo dry-run)"
  if (( apply == 0 )); then
    info "Dry-run: nada cambió; use --apply para revertir"
    return 0
  fi
  switch_rollback_apply "$dir"
}

# Detects the current install of TARGET_DIR (realpath) and translates its
# selection for checkout $1: --from $2, --overlay $3, --no-overlay $4 (0|1),
# --with-packages $5 (0|1), apply mode $6 (0|1). Fills SW_* and SW_ARGS, or
# sets SW_ALREADY_ACTIVE when $1 is the active checkout already. Stops (die)
# when $1 is not a checkout, nothing is detected or a change is unfinished.
# Shared by `dotfiles switch` and the setup wizard's migration offer.
switch_prepare() {
  local new=$1 from=$2 overlay_arg=$3 no_overlay=$4 with_packages=$5 apply=$6

  SW_ALREADY_ACTIVE=0
  SW_NEW=$(realpath -m -- "$new")
  [[ -d "$SW_NEW/layers" && -x "$SW_NEW/bin/dotfiles" ]] || \
    die "$SW_NEW no es un checkout de dotfiles (faltan layers/ o bin/dotfiles)"
  grep -q DOTFILES_REPLACEABLE_ROOTS "$SW_NEW/lib/links.sh" 2>/dev/null || \
    die "el checkout $SW_NEW es anterior a 'switch'; actualícelo antes de cambiar a él"
  switch_check_pending "$apply"

  # The new checkout's components.conf decides which components exist (both
  # are read by load_components).
  # shellcheck disable=SC2034
  COMPONENTS_FILE=${DOTFILES_COMPONENTS_FILE:-$SW_NEW/components.conf}
  # shellcheck disable=SC2034
  COMPONENTS_LOADED=0
  load_components

  _sw_detect "$from"
  if [[ "$SW_KIND" == monorepo && "$(realpath -m -- "$SW_OLD")" == "$SW_NEW" ]]; then
    SW_ALREADY_ACTIVE=1
    return 0
  fi
  if [[ "$SW_KIND" == monorepo ]]; then
    _sw_translate_monorepo "$overlay_arg" "$no_overlay"
  else
    _sw_translate_legacy "$overlay_arg" "$no_overlay"
  fi
  [[ ! -L "$TARGET_DIR/.config/mimeapps.list" ]] || ! array_contains SW_LINKS .config/mimeapps.list || SW_CARRY_MIMEAPPS=1
  _sw_build_args "$with_packages"
}

# Stops when a change was left unfinished; with apply mode $1 = 1 one that
# was stopped before its manifest is discarded first (txn_pending).
switch_check_pending() {
  local pending
  if pending=$(txn_pending "$1"); then
    die "quedó un cambio sin cerrar en $pending; reviértalo con '$PROGRAM_NAME switch --rollback --apply' antes de continuar"
  fi
}

# Checks the prepared switch for collisions and, with apply mode $1 = 1,
# runs it inside its transaction. A dry-run ends with the hint to pass
# --apply unless $2 = 0 (setup gives its own).
switch_run() {
  _sw_preflight
  if (( $1 == 0 )); then
    (( ${2:-1} == 0 )) || info "Dry-run: nada cambió; use --apply para cambiar de checkout"
    return 0
  fi
  _sw_apply
}

cmd_switch() {
  local new="" apply=0 rollback=0 with_packages=0 from="" overlay_arg="" no_overlay=0

  while (( $# > 0 )); do
    case "$1" in
      --apply) apply=1; shift ;;
      --rollback) rollback=1; shift ;;
      --with-packages) with_packages=1; shift ;;
      --no-overlay) no_overlay=1; shift ;;
      --target|--from|--overlay)
        require_option_value "$1" "${2-}"
        case "$1" in
          --target) TARGET_DIR=$2 ;;
          --from) from=$2 ;;
          --overlay) overlay_arg=$2 ;;
        esac
        shift 2
        ;;
      --target=*|--from=*|--overlay=*)
        require_option_value "${1%%=*}" "${1#*=}"
        case "$1" in
          --target=*) TARGET_DIR=${1#*=} ;;
          --from=*) from=${1#*=} ;;
          --overlay=*) overlay_arg=${1#*=} ;;
        esac
        shift
        ;;
      -h|--help) usage; exit 0 ;;
      -*) usage_error "opción desconocida para switch: $1" ;;
      *)
        [[ -z "$new" ]] || usage_error "switch acepta una sola ruta: $1"
        new=$1
        shift
        ;;
    esac
  done
  [[ -z "$overlay_arg" || $no_overlay -eq 0 ]] || usage_error "--overlay y --no-overlay son mutuamente excluyentes"

  command_exists realpath || die "falta el comando requerido: realpath"
  TARGET_DIR=$(realpath -m -- "$TARGET_DIR")
  [[ -d "$TARGET_DIR" ]] || die "el target no es un directorio existente: $TARGET_DIR"

  if (( rollback == 1 )); then
    [[ -z "$new$from$overlay_arg" && $no_overlay -eq 0 && $with_packages -eq 0 ]] || \
      usage_error "--rollback solo acepta --target y --apply"
    _sw_rollback "$apply"
    return 0
  fi

  [[ -n "$new" ]] || usage_error "switch necesita la ruta del checkout nuevo"
  switch_prepare "$new" "$from" "$overlay_arg" "$no_overlay" "$with_packages" "$apply"
  if (( SW_ALREADY_ACTIVE == 1 )); then
    info "$SW_NEW ya es el checkout activo de $TARGET_DIR; no hay nada que cambiar"
    return 0
  fi

  if (( apply == 1 )); then
    _sw_print_plan apply
  else
    _sw_print_plan dry-run
  fi
  switch_run "$apply"
}

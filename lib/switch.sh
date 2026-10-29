#!/usr/bin/env bash
# lib/switch.sh - Reversible changes to a target home: transactions.
#
# A transaction snapshots, before anything changes, every tracked path of the
# target and each of its parents (absent, directory, regular file copied into
# the transaction, or symlink with its value) plus the whole state directory
# ~/.local/state/dotfiles except its transactions/. txn_rollback puts back
# exactly that snapshot: it removes what appeared at a tracked path, restores
# the old links, files and directories, the state directory, and removes the
# directories the change created. The snapshot lives in
# ~/.local/state/dotfiles/transactions/<name>.pending while the change runs.
#
# Reads TARGET_DIR and PROGRAM_NAME. Requires lib/colors.sh, lib/core.sh and
# lib/receipts.sh.
#
# shellcheck shell=bash

TXN_DIR=""
declare -a TXN_PATHS=() TXN_TREES=()

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

# Starts transaction $1; stops when an earlier one was left unfinished.
txn_begin() {
  local pending
  for pending in "$(txn_root)"/*.pending; do
    [[ -e "$pending" ]] || continue
    die "quedó un cambio sin cerrar en $pending; reviértalo con '$PROGRAM_NAME switch --rollback --apply' antes de continuar"
  done
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
  } > "$TXN_DIR/manifest"
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

# Restores the snapshot of transaction directory $1. Mode $2 is discard (the
# change just failed: what appeared is removed) or keep (a later rollback:
# regular files that appeared are set aside, never deleted). Removes the
# transaction directory when everything was restored.
txn_rollback() {
  local dir=$1 mode=$2 failed=0 index type rel value path state_dir displaced
  local -a types=() rels=() values=()

  [[ -f "$dir/manifest" ]] || { error "no existe el manifiesto $dir/manifest"; return 1; }
  while IFS=$'\t' read -r type rel value; do
    [[ -n "$type" && "$type" != \#* ]] || continue
    types+=("$type") rels+=("$rel") values+=("${value:-}")
  done < "$dir/manifest"
  displaced="$(txn_root)/displaced-$(date -u +%Y%m%dT%H%M%SZ)"

  # Deepest first: whatever is not what the snapshot recorded goes.
  for (( index = ${#rels[@]} - 1; index >= 0; index-- )); do
    type=${types[index]} rel=${rels[index]} value=${values[index]}
    path="$TARGET_DIR/$rel"
    case "$type" in
      absent|absent-tree)
        if [[ -L "$path" || ( -e "$path" && ! -d "$path" ) ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        elif [[ "$type" == absent-tree && -d "$path" ]]; then
          rm -rf -- "$path" || failed=1
        fi
        ;;
      link)
        if [[ -L "$path" && "$(readlink -- "$path")" == "$value" ]]; then
          :
        elif [[ -L "$path" || -f "$path" ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        elif [[ -d "$path" ]]; then
          rmdir -- "$path" || failed=1
        fi
        ;;
      file)
        if [[ -f "$path" && ! -L "$path" ]] && cmp -s -- "$dir/files/$rel" "$path"; then
          :
        elif [[ -L "$path" || -f "$path" ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        elif [[ -d "$path" ]]; then
          rmdir -- "$path" || failed=1
        fi
        ;;
      dir)
        if [[ -L "$path" || ( -e "$path" && ! -d "$path" ) ]]; then
          _txn_remove "$path" "$mode" "$displaced" || failed=1
        fi
        ;;
    esac
  done

  # Shallowest first: directories, links and files come back.
  for index in "${!rels[@]}"; do
    type=${types[index]} rel=${rels[index]} value=${values[index]}
    path="$TARGET_DIR/$rel"
    case "$type" in
      dir) [[ -d "$path" ]] || mkdir -- "$path" || failed=1 ;;
      link) [[ -L "$path" ]] || ln -s -- "$value" "$path" || failed=1 ;;
      file) [[ -e "$path" || -L "$path" ]] || cp -a -- "$dir/files/$rel" "$path" || failed=1 ;;
    esac
  done

  state_dir=$(receipt_dir)
  if [[ -d "$state_dir" && ! -L "$state_dir" ]]; then
    find "$state_dir" -mindepth 1 -maxdepth 1 ! -name transactions -exec rm -rf -- {} + || failed=1
    if [[ -f "$dir/state.tar" ]]; then
      tar -C "$state_dir" -xf "$dir/state.tar" || failed=1
    fi
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
    rmdir -- "$path" 2>/dev/null || warn "se conserva $path: no estaba antes del cambio y no quedó vacío"
  done
  return 0
}

# Closes the pending transaction: kept as $1 (for a later rollback) or removed.
txn_commit() {
  local keep=${1-}
  if [[ -n "$keep" ]]; then
    rm -rf -- "$(txn_root)/${keep:?}"
    mv -T -- "$TXN_DIR" "$(txn_root)/$keep"
  else
    rm -rf -- "$TXN_DIR"
    rmdir -- "$(txn_root)" 2>/dev/null || true
  fi
  TXN_DIR=""
}

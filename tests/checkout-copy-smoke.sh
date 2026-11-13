#!/usr/bin/env bash
# copy_checkout: a copy of the checkout is a repository of its own, so tests
# that commit in it never reach the source repository, even from a worktree
# (whose .git is a file pointing at the shared repository).

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
TEST_ROOT=''

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEST_ROOT" && "$TEST_ROOT" == /tmp/checkout-copy-smoke.* ]] || return 0
  find "$TEST_ROOT" -mindepth 1 -delete
  find "$TEST_ROOT" -depth -type d -empty -delete
}
trap cleanup EXIT

# shellcheck source=SCRIPTDIR/lib/checkout-copy.sh
source "$SCRIPT_DIR/lib/checkout-copy.sh"

TEST_ROOT=$(mktemp -d /tmp/checkout-copy-smoke.XXXXXX)
git_t() {
  git -c user.name=t -c user.email=t@t "$@"
}

# A repository with a worktree, an excluded directory and uncommitted work.
SOURCE="$TEST_ROOT/source"
WORKTREE="$TEST_ROOT/worktree"
git init -q -b main "$SOURCE"
printf 'one\n' > "$SOURCE/tracked.txt"
git -C "$SOURCE" add -A
git_t -C "$SOURCE" commit -qm base
git -C "$SOURCE" worktree add -q -b feature "$WORKTREE"
printf 'private/\n' >> "$(git -C "$SOURCE" rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$WORKTREE/private"
printf 'secret\n' > "$WORKTREE/private/notes.md"
printf 'two\n' >> "$WORKTREE/tracked.txt"
printf 'new\n' > "$WORKTREE/untracked.txt"

refs_before=$(git -C "$SOURCE" for-each-ref --format='%(refname) %(objectname)')
worktree_status=$(git -C "$WORKTREE" status --porcelain)

for source_tree in "$SOURCE" "$WORKTREE"; do
  COPY="$TEST_ROOT/copy-${source_tree##*/}"
  copy_checkout "$source_tree" "$COPY"

  # 1. The copy has its own git directory and a first commit holding the
  # working tree as it was, uncommitted changes included.
  [[ -d "$COPY/.git" ]] || fail "la copia de $source_tree no tiene un .git propio"
  [[ $(git -C "$COPY" rev-parse --git-common-dir) == .git ]] || \
    fail "la copia de $source_tree comparte el repositorio"
  git -C "$COPY" rev-parse -q --verify HEAD >/dev/null || fail 'la copia no tiene commit'
  [[ -z $(git -C "$COPY" status --porcelain) ]] || fail 'la copia quedó con cambios'
  diff -q "$source_tree/tracked.txt" "$COPY/tracked.txt" >/dev/null || \
    fail 'la copia no conserva el árbol de trabajo'

  # 2. What the source excludes stays out of the copy's commits.
  if git -C "$COPY" ls-files --error-unmatch private/notes.md >/dev/null 2>&1; then
    fail 'la copia versionó un archivo excluido'
  fi

  # 3. Branches and commits made in the copy stay in the copy.
  git -C "$COPY" switch -qC upstream
  printf 'change\n' >> "$COPY/tracked.txt"
  git_t -C "$COPY" commit -qam wip --no-verify
done

[[ $(git -C "$SOURCE" for-each-ref --format='%(refname) %(objectname)') == "$refs_before" ]] || \
  fail 'los commits de la copia llegaron al repositorio original'
[[ $(git -C "$WORKTREE" branch --show-current) == feature ]] || \
  fail 'el worktree cambió de rama'
[[ $(git -C "$WORKTREE" status --porcelain) == "$worktree_status" ]] || \
  fail 'el worktree cambió su estado'

printf 'OK: checkout-copy-smoke\n'

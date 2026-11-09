#!/usr/bin/env bash
# Shared fixture for the tests that commit in a copy of this checkout
# (system-smoke.sh, components-smoke.sh, overlay-smoke.sh).
#
# shellcheck shell=bash

# copy_checkout <source> <destination>: copies the working tree of <source>,
# uncommitted changes included, into a new repository with one commit. The
# copy never shares a git directory with <source>: a worktree's .git is a
# file pointing at the shared repository, so copying it would send the
# test's branches and commits to the real repository. What <source> excludes
# through .git/info/exclude stays out of the copy's commit.
copy_checkout() {
  local source=$1 destination=$2 exclude

  mkdir -p -- "$destination"
  tar -C "$source" --exclude=./.git -cf - . | tar -C "$destination" -xf -
  git -C "$destination" init -q
  exclude=$(git -C "$source" rev-parse --path-format=absolute --git-path info/exclude)
  if [[ -f "$exclude" ]]; then
    cp -- "$exclude" "$destination/.git/info/exclude"
  fi
  git -C "$destination" add -A
  git -C "$destination" -c user.name=t -c user.email=t@t \
    commit -qm base --allow-empty --no-verify
}

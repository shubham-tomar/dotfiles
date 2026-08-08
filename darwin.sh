#!/usr/bin/env bash
#
# nix-darwin helper. Lives in the dotfiles repo and operates on it.
#
#   ./darwin.sh build     validate the config without activating (no sudo)
#   ./darwin.sh switch    build and activate
#   ./darwin.sh update    update flake inputs, then build
#   ./darwin.sh rollback  list generations so you can pick an older one
#
# Host defaults to `scutil --get LocalHostName`; override with DARWIN_HOST.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${DARWIN_HOST:-$(scutil --get LocalHostName)}"
FLAKE="${REPO}#${HOST}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

# Flakes only see git-tracked files. A new file under darwin/ that was never
# `git add`ed is invisible to evaluation and fails with a confusing error, so
# stage the nix-relevant paths on every run.
stage() {
  # Everything in this repo is dotfiles, so stage the whole tree rather than an
  # explicit list — a newly added file would otherwise stay invisible.
  # .gitignore keeps build artifacts (result symlinks) out.
  git -C "$REPO" add -A 2>/dev/null || true
  if ! git -C "$REPO" diff --quiet --cached; then
    info "staged changes (still uncommitted)"
  fi
}

# A host with no matching darwinConfigurations entry otherwise fails with an
# opaque "flake does not provide attribute" error. Fail early and say what's
# actually available.
assert_host() {
  local hosts
  hosts="$(nix eval --raw "${REPO}#darwinConfigurations" \
    --apply 'cfgs: builtins.concatStringsSep " " (builtins.attrNames cfgs)' \
    2>/dev/null || true)"
  [ -z "$hosts" ] && return 0  # eval broke for some other reason; let nix report it
  case " $hosts " in
    *" $HOST "*) return 0 ;;
  esac
  die "no config for host '$HOST'
    available: $hosts
    Either add it to darwinConfigurations in flake.nix, or reuse one with
    DARWIN_HOST=<name> $0 ${1:-build}"
}

# darwin-rebuild only exists on PATH after the first successful switch, so fall
# back to running it straight from the flake while bootstrapping.
rebuild() {
  local action="$1"; shift
  if command -v darwin-rebuild >/dev/null 2>&1; then
    case "$action" in
      switch) sudo darwin-rebuild switch --flake "$FLAKE" "$@" ;;
      *)      darwin-rebuild "$action" --flake "$FLAKE" "$@" ;;
    esac
  else
    warn "darwin-rebuild not on PATH — bootstrapping from the flake"
    case "$action" in
      switch) sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake "$FLAKE" "$@" ;;
      *)      nix run nix-darwin/master#darwin-rebuild -- "$action" --flake "$FLAKE" "$@" ;;
    esac
  fi
}

cmd_build() {
  stage
  assert_host build
  info "building $FLAKE"
  rebuild build "$@"
  info "config is valid"
}

cmd_switch() {
  stage
  assert_host switch
  info "building $FLAKE"
  rebuild build "$@"
  info "activating"
  rebuild switch "$@"
  info "done — commit when you're happy:"
  printf '    git -C %s commit -m "..."\n' "$REPO"
}

cmd_update() {
  info "updating flake inputs"
  nix flake update --flake "$REPO"
  stage
  info "rebuilding against updated inputs"
  rebuild build
  info "inputs updated and config still builds — run '$0 switch' to apply"
}

cmd_rollback() {
  command -v darwin-rebuild >/dev/null 2>&1 || die "darwin-rebuild not installed yet"
  darwin-rebuild --list-generations
  printf '\nActivate an older one with:\n    sudo darwin-rebuild switch --switch-generation <N>\n'
}

case "${1:-build}" in
  build)    shift || true; cmd_build "$@" ;;
  switch)   shift || true; cmd_switch "$@" ;;
  update)   shift || true; cmd_update "$@" ;;
  rollback) shift || true; cmd_rollback "$@" ;;
  -h|--help|help)
    sed -n '3,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown command '${1}' — try: build | switch | update | rollback" ;;
esac

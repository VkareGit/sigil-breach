#!/usr/bin/env bash
# StyLua over the active code, as scripts/win/FORMAT.ps1.
# Usage: scripts/linux/FORMAT.sh [--check] [paths...]
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
formatter=$(stylua_path)
arguments=(--config-path "$SIGIL_ROOT/.stylua.toml" --verify --color Never)
if [ "${1:-}" = --check ]; then
  arguments+=(--check --output-format Summary)
  shift
fi
if [ "$#" -eq 0 ]; then
  set -- game/src game/qa game/tests game/main.lua game/conf.lua tools/check
fi
arguments+=(--)
for item in "$@"; do
  case "$item" in
    /*) resolved=$item ;;
    *) resolved="$SIGIL_ROOT/$item" ;;
  esac
  [ -e "$resolved" ] || die "Formatting target does not exist: $resolved"
  arguments+=("$resolved")
done
# Only the selected source tree is traversed; packages, backups and work are left out.
cd -- "$SIGIL_ROOT"
exec "$formatter" "${arguments[@]}"

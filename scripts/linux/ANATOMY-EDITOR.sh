#!/usr/bin/env bash
# The anatomy region editor: an annotation over its painted frames, edited with the mouse and
# keys; S saves anatomy/<id>.lua in the external work directory.
# Usage: scripts/linux/ANATOMY-EDITOR.sh <annotation id> [atlas id]
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
[ "$#" -ge 1 ] || die 'Usage: ANATOMY-EDITOR.sh <annotation id> [atlas id]'
mapfile -t prefix < <(display_prefix)
runtime=$(love_path)
exec "${prefix[@]}" "$runtime" "$SIGIL_ROOT/tools/art/anatomy_editor" "$SIGIL_GAME" "$@"

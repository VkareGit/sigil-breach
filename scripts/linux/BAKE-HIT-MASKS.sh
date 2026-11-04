#!/usr/bin/env bash
# Rebuilds the hit masks from the art, as scripts/win/BAKE-HIT-MASKS.ps1.
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
enter_qa_session
baked="$SIGIL_QA/hit-masks.lua"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
sleep 1
run_isolated bake-hit-masks 300 "$SIGIL_QA" -- "$SIGIL_GAME" --bake-hit-masks
newer_than "$baked" "$marker"
# Under the same lock: another run may not replace the result between the check and the copy.
cp -- "$baked" "$SIGIL_GAME/src/content/art/hit_masks.lua"
"$SIGIL_ROOT/scripts/linux/FORMAT.sh" game/src/content/art/hit_masks.lua \
  || die 'Baked masks failed formatting validation.'
echo 'Masks rebuilt from existing art. Run TEST.sh before release.'

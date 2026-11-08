#!/usr/bin/env bash
# Re-measures an atlas sheet from its images (feet, sizes), or writes the sheet of a new atlas
# from a spec file, and installs it in its creature's package, game/src/content/creatures/<atlas>/
# sheet.lua (PLAN F4). A new atlas also needs its line in content/art/sheets/index.lua.
# As scripts/win/EXPORT-SHEET.ps1.
# Usage: scripts/linux/EXPORT-SHEET.sh <atlas>   or   scripts/linux/EXPORT-SHEET.sh --spec <file>
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
id=''
spec=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --spec)
      spec=$(realpath -- "$2")
      shift
      ;;
    *) id=$1 ;;
  esac
  shift
done
if [ -n "$spec" ]; then
  id=$(first_id "$spec")
  [ -n "$id" ] || die 'The spec names no id.'
  flag="--sheet-spec=$spec"
elif [ -n "$id" ]; then
  flag="--sheet-export=$id"
else
  die 'Give an atlas id or --spec <file>.'
fi
enter_qa_session
written="$SIGIL_QA/sheet-$id.lua"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
sleep 1
run_isolated "sheet-$id" 300 "$SIGIL_QA" -- "$SIGIL_GAME" "$flag"
newer_than "$written" "$marker"
mkdir -p -- "$SIGIL_GAME/src/content/creatures/$id"
destination="$SIGIL_GAME/src/content/creatures/$id/sheet.lua"
cp -- "$written" "$destination"
"$SIGIL_ROOT/scripts/linux/FORMAT.sh" "game/src/content/creatures/$id/sheet.lua" \
  || die 'The sheet failed formatting validation.'
cat -- "$SIGIL_QA/sheet-$id.stdout.txt"
echo "Sheet installed: $destination. Check its anchors, then BAKE-HIT-MASKS.sh."

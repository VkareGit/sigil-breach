#!/usr/bin/env bash
# Exports an annotation as data, or generates one from part layers (a legend file). --install
# copies it into game/src/content/art/anatomy/ (list it in content/art/anatomy/index.lua),
# then bake the masks. As scripts/win/EXPORT-ANATOMY.ps1.
# Usage: scripts/linux/EXPORT-ANATOMY.sh <id> [--install]
#        scripts/linux/EXPORT-ANATOMY.sh --legend <file> [--install]
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
id=''
legend=''
install=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --legend)
      legend=$(realpath -- "$2")
      shift
      ;;
    --install) install=1 ;;
    *) id=$1 ;;
  esac
  shift
done
if [ -n "$legend" ]; then
  id=$(first_id "$legend")
  [ -n "$id" ] || die 'The legend names no id.'
  flag="--anatomy-layers=$legend"
elif [ -n "$id" ]; then
  flag="--anatomy-export=$id"
else
  die 'Give an annotation id or --legend <file>.'
fi
enter_qa_session
written="$SIGIL_QA/anatomy-$id.lua"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
sleep 1
status=0
(run_isolated "anatomy-$id" 300 "$SIGIL_QA" -- "$SIGIL_GAME" "$flag") || status=$?
newer_than "$written" "$marker"
cat -- "$SIGIL_QA/anatomy-$id.stdout.txt"
[ "$status" -eq 0 ] || die "The annotation has problems; see $SIGIL_QA/anatomy-$id.stdout.txt"
if [ -n "$install" ]; then
  destination="$SIGIL_GAME/src/content/art/anatomy/$id.lua"
  cp -- "$written" "$destination"
  "$SIGIL_ROOT/scripts/linux/FORMAT.sh" "game/src/content/art/anatomy/$id.lua" \
    || die 'The annotation failed formatting validation.'
  echo "Annotation installed: $destination"
else
  echo "Annotation written: $written"
fi

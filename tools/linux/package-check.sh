#!/usr/bin/env bash
# A small fixture through the packaging rule, before a real build, as tools/win/package-check.ps1.
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
mkdir -p "$SIGIL_QA"
fixture=$(mktemp -d "$SIGIL_QA/package-check-XXXXXX")
trap 'rm -rf -- "$fixture"' EXIT
package="$SIGIL_ROOT/tools/linux/package.py"
game="$fixture/game"
mkdir -p "$game/src" "$game/assets/art" "$game/qa" "$game/tests"
for file in main.lua conf.lua src/example.lua assets/art/example.png assets/art/masks.lua \
  assets/art/provenance.json qa/private.lua tests/private.lua INSTRUKCJA.txt; do
  echo fixture > "$game/$file"
done
print=$(printf 'a%.0s' {1..64})
python3 -I "$package" love "$game" "$print" "$fixture/game.love"
python3 -I "$package" legal "$game" "$fixture/legal"
listed=$(python3 -I "$package" list "$fixture/game.love")
expected='assets/art/example.png
assets/art/masks.lua
build-fingerprint.txt
conf.lua
main.lua
src/example.lua'
[ "$listed" = "$expected" ] || die "Player archive holds the wrong files: $listed"
[ -f "$fixture/legal/assets/art/provenance.json" ] || die 'Art documents did not travel.'
if python3 -I "$package" love "$game" notahash "$fixture/bad.love" 2> /dev/null; then
  die 'An invalid fingerprint was accepted.'
fi
echo 'PACKAGE CHECK: 3 checks passed.'

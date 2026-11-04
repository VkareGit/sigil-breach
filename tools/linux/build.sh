#!/usr/bin/env bash
# The Linux packages, the counterpart of tools/win/build.ps1: only through
# scripts/linux/BUILD.sh --package, after a full test run of this same source.
#   outputs/<name>-Player-Linux     game.love, LOVE AppImage, run.sh, manual, legal documents
#   outputs/<name>-Developer-Linux  the source workspace with its pinned Linux tools
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
[ "${SIGIL_QA_HELD:-}" = "$SIGIL_QA" ] || die 'Run the release through scripts/linux/BUILD.sh.'
player_root=$(assert_child "$SIGIL_OUTPUTS/$SIGIL_NAME-Player-Linux" "$SIGIL_OUTPUTS")
developer_root=$(assert_child "$SIGIL_OUTPUTS/$SIGIL_NAME-Developer-Linux" "$SIGIL_OUTPUTS")
mkdir -p "$SIGIL_OUTPUTS"
stage=$(mktemp -d "$SIGIL_OUTPUTS/.$SIGIL_NAME-build-XXXXXX")
# A failed build removes its own unfinished stage instead of leaving it in outputs.
trap 'rm -rf -- "$stage"' EXIT
history="$SIGIL_ROOT/docs/HISTORIA.md"
for section in "ZMIANY-$SIGIL_VERSION.txt" "ODBIOR-$SIGIL_VERSION.txt"; do
  grep -Eq "^$section"$'\r?$' "$history" || die "Missing version section $section in docs/HISTORIA.md"
done
[ -f "$SIGIL_GAME/INSTRUKCJA.txt" ] || die 'Missing source file: INSTRUKCJA.txt'
[ ! -e "$SIGIL_GAME/build-fingerprint.txt" ] \
  || die 'Generated build-fingerprint.txt must not live in the development game tree.'
appimage="$SIGIL_ROOT/toolchain/love-11.5-linux/love-11.5-x86_64.AppImage"
[ -f "$appimage" ] || die 'Missing bundled LOVE 11.5 AppImage.'
audit="$SIGIL_QA/ui-layout-audit.txt"
[ -f "$SIGIL_QA/render-results.txt" ] || die 'Missing current render report; run --showcase first.'
[ -f "$audit" ] || die 'Missing measured frame-interior audit.'
grep -Eq '[0-9]+ interior checks, 0 issues' "$audit" && ! grep -Eq '\b[1-9][0-9]* issues\b' "$audit" \
  || die 'The final UI showcase must report zero frame-interior/collision issues before packaging.'
fingerprint=$(source_fingerprint)
# Evidence of this very source, or no package.
python3 -I - "$SIGIL_QA" "$fingerprint" architecture source-selftest source-input-test \
  source-showcase << 'PY'
import json, os, sys
qa, fingerprint, *names = sys.argv[1:]
for name in names:
    evidence = json.load(open(os.path.join(qa, name + '.evidence.json')))
    if evidence['sourceFingerprint'] != fingerprint or not evidence['sourceStable']:
        sys.exit(f'Evidence of {name} belongs to another source; run the tests again.')
    if evidence['exitCode'] != 0:
        sys.exit(f'Evidence of {name} is a failed run.')
PY
echo "BUILD $SIGIL_VERSION: source, documents, runtime and source render evidence."

player="$stage/player"
mkdir -p "$player"
python3 -I "$SIGIL_ROOT/tools/linux/package.py" love "$SIGIL_GAME" "$fingerprint" "$player/game.love"
python3 -I "$SIGIL_ROOT/tools/linux/package.py" legal "$SIGIL_GAME" "$player/legal"
cp -- "$appimage" "$player/"
chmod +x "$player/$(basename "$appimage")"
cp -- "$SIGIL_GAME/INSTRUKCJA.txt" "$player/"
cp -- "$SIGIL_ROOT/toolchain/love-11.5-win64/license.txt" "$player/LOVE-LICENSE.txt"
cat > "$player/run.sh" << 'RUN'
#!/bin/sh
# SIGIL: BREACH. Double-click or run from a terminal.
cd -- "$(dirname -- "$0")" || exit 1
# Unpacked, the AppImage does not need libfuse2.
APPIMAGE_EXTRACT_AND_RUN=1 NO_CLEANUP=1
export APPIMAGE_EXTRACT_AND_RUN NO_CLEANUP
exec ./love-11.5-x86_64.AppImage game.love "$@"
RUN
chmod +x "$player/run.sh"

developer="$stage/developer"
# Explicit list: what git tracks there, so private settings, work and old deliveries stay out.
(cd -- "$SIGIL_ROOT" && git ls-files -z -- game tools/check tools/art tools/linux scripts/linux \
  docs toolchain/love-11.5-linux toolchain/stylua/stylua toolchain/stylua/LICENSE.md \
  toolchain/stylua/PROVENANCE-LINUX.txt START-HERE.txt .stylua.toml .gitattributes \
  | tar --null -T - -cf -) | tar -xf - -C "$(mkdir -p "$developer" && echo "$developer")"

for tree in "$player" "$developer"; do
  (cd -- "$tree" && find . -type f ! -name SHA256SUMS -printf '%P\n' | LC_ALL=C sort \
    | xargs -d '\n' sha256sum > SHA256SUMS)
  {
    echo "$SIGIL_TITLE - Linux build."
    echo "Built UTC: $(date -u +%FT%TZ)"
    echo "Game tree SHA256: $fingerprint"
    echo 'Next: tools/linux/verify.sh runs the packages and writes the final archives.'
  } > "$tree/BUDOWA-PACZKI.txt"
done
[ "$(source_fingerprint)" = "$fingerprint" ] || die 'The game tree changed during packaging.'

# A rebuild keeps the previous delivery as the one rollback generation.
mkdir -p "$SIGIL_QA/rollback"
for pair in "$player:$player_root:player-linux" "$developer:$developer_root:developer-linux"; do
  IFS=: read -r from to back <<< "$pair"
  if [ -e "$to" ]; then
    rm -rf -- "${SIGIL_QA:?}/rollback/$back"
    mv -- "$to" "$SIGIL_QA/rollback/$back"
  fi
  mv -- "$from" "$to"
done
echo "BUILD complete: $player_root"
echo "Developer workspace: $developer_root"

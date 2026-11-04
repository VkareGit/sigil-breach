#!/usr/bin/env bash
# Runs what tools/linux/build.sh made and writes the final archives, as tools/win/verify.ps1:
# hashes, what the player archive may hold, the player starting by itself, and the Architecture
# gate inside the developer workspace.
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
player="$SIGIL_OUTPUTS/$SIGIL_NAME-Player-Linux"
developer="$SIGIL_OUTPUTS/$SIGIL_NAME-Developer-Linux"
[ -d "$player" ] && [ -d "$developer" ] || die 'No build to verify; run build.sh first.'
for tree in "$player" "$developer"; do
  (cd -- "$tree" && sha256sum --quiet -c SHA256SUMS) || die "SHA-256 mismatch in $tree"
done
listed=$(python3 -I "$SIGIL_ROOT/tools/linux/package.py" list "$player/game.love")
! grep -Eq '^(qa|tests|docs)/' <<< "$listed" || die 'The player holds QA, tests or documents.'
for name in main.lua conf.lua build-fingerprint.txt; do
  grep -qx "$name" <<< "$listed" || die "The player archive misses $name."
done
fingerprint=$(source_fingerprint)
stamped=$(python3 -I -c "import sys, zipfile; print(zipfile.ZipFile(sys.argv[1]).read('build-fingerprint.txt').decode().strip())" "$player/game.love")
[ "$stamped" = "$fingerprint" ] || die 'The player holds another source.'

# The player runs from its own folder with an empty save directory. It must still be running
# when the timer ends (exit 124) and leave no error log.
data=$(mktemp -d)
trap 'rm -rf -- "$data"' EXIT
mapfile -t prefix < <(display_prefix)
code=0
XDG_DATA_HOME=$data timeout --kill-after=10 20 "${prefix[@]}" "$player/run.sh" \
  > "$data/stdout.txt" 2>&1 || code=$?
[ "$code" -eq 124 ] || die "The player stopped by itself (exit $code); see $data/stdout.txt"
[ -z "$(find "$data" -name sigil-error.log)" ] || die 'The player wrote an error log.'
echo 'Player started and ran for 20 s.'

(cd -- "$developer" && SIGIL_QA_HELD='' SIGIL_LOVE=$(love_path) scripts/linux/TEST.sh Architecture)
rm -rf -- "${developer:?}/work"
for tree in "$player" "$developer"; do
  archive="$tree.tar.gz"
  rm -f -- "$archive"
  tar -czf "$archive" -C "$SIGIL_OUTPUTS" "$(basename "$tree")"
  echo "Verified: $archive"
done

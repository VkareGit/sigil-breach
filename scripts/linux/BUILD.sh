#!/usr/bin/env bash
# Tests the source, which is all a run of the game needs. --package also builds and verifies
# the Linux packages: only when a release is wanted. As scripts/win/BUILD.ps1.
# Usage: scripts/linux/BUILD.sh [--package]
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
package=''
[ "${1:-}" != --package ] || package=1
cd -- "$SIGIL_ROOT"
# One lock for the whole run: tests, packaging and verification share the same outputs.
enter_qa_session
[ -z "$package" ] || "$SIGIL_ROOT/tools/linux/package-check.sh"
# The showcase walks every painted hall: it outgrew the default limit.
"$SIGIL_ROOT/scripts/linux/TEST.sh" All --timeout 1800
if [ -n "$package" ]; then
  "$SIGIL_ROOT/tools/linux/build.sh"
  "$SIGIL_ROOT/tools/linux/verify.sh"
fi

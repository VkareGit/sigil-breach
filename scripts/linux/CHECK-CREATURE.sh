#!/usr/bin/env bash
# One check of a demon: every element the game needs of it, each OK or MISSING with what is
# wrong. As scripts/win/CHECK-CREATURE.ps1. Usage: scripts/linux/CHECK-CREATURE.sh <id>
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
[ "$#" -eq 1 ] || die 'Usage: CHECK-CREATURE.sh <id>'
id=$1
enter_qa_session
report="$SIGIL_QA/creature-$id.txt"
marker=$(mktemp)
trap 'rm -f "$marker"' EXIT
sleep 1
status=0
(run_isolated "check-creature-$id" 300 "$SIGIL_QA" -- "$SIGIL_GAME" "--check-creature=$id") || status=$?
newer_than "$report" "$marker"
cat -- "$report"
exit "$status"

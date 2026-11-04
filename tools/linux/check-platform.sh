#!/usr/bin/env bash
# Cheap regressions for the portability gate, as tools/win/check-platform.ps1; no game or
# player saves are touched.
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
mkdir -p "$SIGIL_QA"
fixture=$(mktemp -d "$SIGIL_QA/platform-XXXXXX")
trap 'rm -rf -- "$fixture"' EXIT
paths="$SIGIL_ROOT/tools/linux/check-paths.sh"
checks=0
mkdir -p "$fixture/src" "$fixture/assets/art" "$fixture/tests/fixtures"
: > "$fixture/src/Example.lua"
: > "$fixture/assets/art/Example.png"
: > "$fixture/tests/fixtures/Example.save"
for literal in src.example Assets/art/Example.png assets/art/example.png \
  tests/fixtures/example.save example.png; do
  printf "return '%s'" "$literal" > "$fixture/main.lua"
  if "$paths" "$fixture" "$fixture/case.txt" > /dev/null; then
    die "Case checker accepted $literal"
  fi
  grep -q '^CASE:' "$fixture/case.txt" || die "Case checker gave no reason for $literal"
  checks=$((checks + 1))
done
printf "return 'src.Example', 'assets/art/Example.png', 'tests/fixtures/Example.save'" \
  > "$fixture/main.lua"
"$paths" "$fixture" "$fixture/case.txt" > /dev/null || die 'Case checker refused correct paths.'
checks=$((checks + 1))
if (assert_child "$fixture-outside/file" "$fixture") > /dev/null 2>&1; then
  die 'Sibling path accepted as a child.'
fi
checks=$((checks + 1))
if (assert_child "$(printf '%s' "$fixture" | tr '[:lower:]' '[:upper:]')/file" "$fixture") \
  > /dev/null 2>&1; then
  die 'Child check ignored path case.'
fi
checks=$((checks + 1))
echo "PLATFORM: $checks checks passed."

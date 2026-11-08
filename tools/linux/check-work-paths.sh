#!/usr/bin/env bash
# Output routing and cleanup regressions run without graphics or player saves.
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
fixture=$(mktemp -d /tmp/sigil-work-paths-XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/probe" "$fixture/a/clone" "$fixture/b/clone"
ln -s "$SIGIL_ROOT" "$fixture/linked-checkout"
cat > "$fixture/probe/conf.lua" << 'LUA'
function love.conf(t)
  t.window = false
  t.modules.graphics = false
  t.modules.audio = false
  t.modules.physics = false
  t.modules.joystick = false
end
LUA
cat > "$fixture/probe/main.lua" << 'LUA'
function love.load(args)
  package.path = args[1] .. '/game/?.lua;' .. args[1] .. '/game/?/init.lua;' .. package.path
  local Workspace = require('src.app.workspace')
  local actualProject = args[3]
  love.filesystem.getSourceBaseDirectory = function() return actualProject end
  local ok, problem = xpcall(function()
    local work = Workspace.directory()
    assert(work == args[2], 'Lua and bash disagree: ' .. work .. ' vs ' .. args[2])
    local a, b = Workspace.directory(args[4]), Workspace.directory(args[5])
    assert(a ~= b, 'Clones with identical names share output')
    assert(Workspace.directory(args[6]) == work, 'A symlink changes the checkout identity')
    local explicit = os.getenv('SIGIL_UI_QA_DIR')
    local expected = explicit or work .. '/qa-direct'
    assert(require('src.app.release').output() == expected, 'Release output differs')
    assert(require('qa.output').directory() == expected, 'Manual reports differ')
    local q = require('qa.runtime').new({'--suite=app'})
    assert(q.output == expected, 'QA runtime differs')
    local file = assert(io.open(require('qa.output').path('probe.txt'), 'w'))
    file:write('isolated output'); file:close()
  end, debug.traceback)
  if not ok then print(problem) end
  love.event.quit(ok and 0 or 1)
end
LUA
# The fixture has spaces and non-ASCII text to exercise native file handling.
export SIGIL_TRIES_DIR="$fixture/tries with spaces-ąć"
unset SIGIL_UI_QA_DIR SIGIL_QA_HELD
source "$SIGIL_ROOT/tools/linux/project.sh"
case "$SIGIL_QA" in "$SIGIL_TRIES_DIR"/*/work/qa) ;; *) die 'QA stayed inside the checkout.' ;; esac
mkdir -p "$SIGIL_WORK/qa-direct" "$SIGIL_QA/rollback" "$SIGIL_QA/obsolete"
: > "$SIGIL_WORK/qa-direct/keep"
: > "$SIGIL_QA/rollback/keep"
: > "$SIGIL_QA/obsolete/remove"
: > "$SIGIL_TRIES_DIR/unrelated"
if (clean_qa_session) > /dev/null 2>&1; then die 'Cleanup accepted an unlocked directory.'; fi
enter_qa_session
clean_qa_session
[ ! -e "$SIGIL_QA/obsolete" ] || die 'Stale QA survived cleanup.'
for kept in "$SIGIL_WORK/qa-direct/keep" "$SIGIL_QA/rollback/keep" \
  "$SIGIL_QA/.qa-session.lock" "$SIGIL_TRIES_DIR/unrelated"; do
  [ -f "$kept" ] || die "Cleanup removed $kept"
done
if (SIGIL_QA="$SIGIL_TRIES_DIR"; SIGIL_QA_HELD=$SIGIL_QA; clean_qa_session) \
  > /dev/null 2>&1; then die 'Cleanup accepted the shared tries root.'; fi
runtime=$(love_path)
for route in default explicit; do
  if [ "$route" = explicit ]; then export SIGIL_UI_QA_DIR="$fixture/explicit reports"; fi
  "$runtime" "$fixture/probe" "$SIGIL_ROOT" "$SIGIL_WORK" "$SIGIL_ROOT" \
    "$fixture/a/clone" "$fixture/b/clone" "$fixture/linked-checkout" \
    > "$fixture/$route.stdout" 2> "$fixture/$route.stderr" \
    || { cat "$fixture/$route.stdout"; die "Output route failed: $route"; }
done
[ -f "$SIGIL_WORK/qa-direct/probe.txt" ] || die 'Manual report missing.'
[ -f "$fixture/explicit reports/probe.txt" ] || die 'Explicit report missing.'
if (SIGIL_TRIES_DIR=relative source "$SIGIL_ROOT/tools/linux/project.sh") > /dev/null 2>&1; then
  die 'Relative tries root was accepted.'
fi
echo 'WORK PATHS: default/manual/explicit routes, clone isolation, symlinks and safe cleanup passed.'

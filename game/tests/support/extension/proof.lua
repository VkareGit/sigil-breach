-- Proofs of plan v12: content added only through public registries, removed
-- again after its test. A proof that needs the inside of a module means its
-- contract is not ready (plan v12, in git history).
local Extension = {}
-- Runs fn with the registered things undone afterwards, also when it fails.
function Extension.with(undo, fn)
  local results = { xpcall(fn, debug.traceback) }
  for i = #undo, 1, -1 do
    undo[i]()
  end
  assert(results[1], results[2])
  return unpack(results, 2)
end
return Extension

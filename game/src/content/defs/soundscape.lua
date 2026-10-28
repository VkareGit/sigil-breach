-- Authoring contract. No native audio is loaded by content validation.
local finite = require('src.core.mathx').finite
local S = {}
local function number(value, name, minimum)
  assert(finite(value) and value >= minimum, name .. ' is outside its finite range')
end
local function mix(value)
  assert(type(value) == 'table', 'soundscape needs a layer mix')
  for id, gain in pairs(value) do
    assert(type(id) == 'string' and #id > 0, 'soundscape layer needs an id')
    number(gain, 'soundscape gain', 0)
    assert(gain <= 1, 'soundscape gain exceeds one')
  end
end
function S.check(scene, width, depth)
  if not scene then
    return
  end
  for _, name in ipairs({ 'base', 'summoning', 'duel', 'pressure', 'aftermath' }) do
    mix(scene[name])
  end
  number(scene.aftermathHold, 'aftermath hold', 0)
  number(scene.aftermathFade, 'aftermath fade', 0.01)
  local ids = {}
  for _, r in ipairs(scene.regions or {}) do
    assert(type(r.id) == 'string' and not ids[r.id], 'duplicate/missing soundscape region id')
    ids[r.id] = true
    number(r.x1, 'region x1', 0.5)
    number(r.z1, 'region z1', 0.5)
    number(r.x2, 'region x2', r.x1)
    number(r.z2, 'region z2', r.z1)
    assert(r.x2 <= width + 0.5 and r.z2 <= depth + 0.5, 'soundscape region outside map')
    number(r.fade, 'region fade', 0.01)
    mix(r.mix)
  end
  for _, s in ipairs(scene.sources or {}) do
    assert(type(s.voice) == 'string' and #s.voice > 0, 'ambient source needs a voice')
    number(s.x, 'ambient x', 0.5)
    number(s.z, 'ambient z', 0.5)
    assert(s.x <= width + 0.5 and s.z <= depth + 0.5, 'ambient source outside map')
    number(s.volume, 'ambient volume', 0)
    assert(s.volume <= 1, 'ambient volume exceeds one')
    number(s.interval, 'ambient interval', 1)
    number(s.offset, 'ambient offset', 0)
    number(s.reach, 'ambient reach', 0.1)
  end
end
return S

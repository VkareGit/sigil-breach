-- Pose templates of the sheet tool (plan v11 E1): the two painted layouts
-- 0.33 knew, as data a new sheet starts from (EXPORT-SHEET.ps1 -Spec with
-- template = 'extended' | 'compact', or its own poses). The game never
-- reads a layout: each sheet names its poses (content/art/poses.lua).
local T = {}
-- 6 columns x 4 rows: walk 1-6, wind-up 7-9, strike 10-11, recovery 12,
-- pain 13, collapse 14-18, the back walk 19-24.
T.extended = {
  walk = { clock = 'stride', frames = { 1, 2, 3, 4, 5, 6 }, rate = 4.2 },
  walkRear = { clock = 'stride', frames = { 19, 20, 21, 22, 23, 24 }, rate = 4.2 },
  watchRear = { frames = { 19 } },
  windup = { clock = 'action', frames = { 7, 8, 9 }, bounds = { 0.22, 0.6 } },
  strike = { clock = 'action', frames = { 10, 11 }, bounds = { 0.5 } },
  recover = { frames = { 12 } },
  pain = { frames = { 13 } },
  painHeavy = { clock = 'seconds', frames = { 14, 13 }, bounds = { 0.12 } },
  knockdown = { clock = 'seconds', frames = { 14, 15 }, bounds = { 0.06 }, ends = 0.12 },
  rise = { clock = 'countdown', frames = { 16, 15, 14 }, bounds = { -0.15, -0.07 } },
  collapse = { clock = 'seconds', frames = { 14, 15, 16, 17, 18 }, step = 0.11 },
}
-- 4 columns x 4 rows: walk 1-4, wind-up 5-6, strike 7, recovery 8, pain 9,
-- collapse 10-12, the back walk 13-16.
T.compact = {
  walk = { clock = 'stride', frames = { 1, 2, 3, 4 }, rate = 3.4 },
  walkRear = { clock = 'stride', frames = { 13, 14, 15, 16 }, rate = 3.4 },
  watchRear = { frames = { 13 } },
  windup = { clock = 'action', frames = { 5, 6 }, bounds = { 0.42 } },
  strike = { frames = { 7 } },
  recover = { frames = { 8 } },
  pain = { frames = { 9 } },
  painHeavy = { clock = 'seconds', frames = { 10, 9 }, bounds = { 0.12 } },
  knockdown = { clock = 'seconds', frames = { 10 }, ends = 0.08 },
  rise = { clock = 'countdown', frames = { 11, 10 }, bounds = { -0.12 } },
  collapse = { clock = 'seconds', frames = { 10, 11, 12 }, step = 0.14 },
}
-- A copy of a template (a sheet adds its own poses to it).
function T.copy(name)
  local out = {}
  for pose, entry in pairs(assert(T[name], 'unknown pose template ' .. tostring(name))) do
    local copy = {}
    for k, v in pairs(entry) do
      copy[k] = type(v) == 'table' and { unpack(v) } or v
    end
    out[pose] = copy
  end
  return out
end
return T

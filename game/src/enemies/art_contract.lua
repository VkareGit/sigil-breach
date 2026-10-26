-- Composition-time references: content stays independent of its samplers and
-- renderer. Used by startup/QA, never for a per-frame scan of every creature.
local Art = require('src.content.enemy_art')
local Sequences = require('src.content.ability_art')
local Anatomy = require('src.content.art.anatomy_regions')
local Masks = require('src.content.art.hit_masks')
local Sources = require('src.content.art.sources')
local AbilityPose = require('src.enemies.ability_pose')
local Atlases = require('src.content.art.atlases')
local Contract = {}

function Contract.sequenceProblems(id)
  local out, entry = {}, Sequences.entries[id]
  local function bad(message)
    out[#out + 1] = 'ability artwork ' .. tostring(id) .. ': ' .. message
  end
  if not entry then
    bad('unknown sequence')
    return out
  end
  if not Sources[entry.path] then
    bad('unknown atlas dimensions ' .. tostring(entry.path))
  end
  if type(AbilityPose.samplers[entry.sampler]) ~= 'function' then
    bad('missing sampler ' .. tostring(entry.sampler))
  end
  local ok, anatomy = pcall(function()
    return Anatomy.abilities[id]
  end)
  if not ok or type(anatomy) ~= 'table' or type(anatomy.frames) ~= 'table' then
    bad('missing anatomy ' .. tostring(entry.anatomy))
    anatomy = nil
  elseif #anatomy.frames ~= #entry.frames then
    bad('anatomy/frame count differs')
  end
  local masks = Masks.abilities[id]
  if type(masks) ~= 'table' or #masks ~= #entry.frames then
    bad('missing baked masks or mask/frame count differs')
  end
  for index, frame in ipairs(entry.frames) do
    if not (frame.rect and frame.head and frame.torso and frame.width and frame.height) then
      bad('incomplete placement frame ' .. index)
    end
    local annotated = anatomy and anatomy.frames[index]
    if annotated then
      for _, problem in ipairs(Anatomy.problems(annotated, id .. '/' .. index)) do
        bad(problem)
      end
    end
  end
  return out
end

function Contract.problems(def)
  local out, look = {}, def.appearance or {}
  local function bad(message)
    out[#out + 1] = 'creature ' .. tostring(def.id) .. ': ' .. message
  end
  local atlas = look.atlas or def.kind or def.id
  local layout = Art.layouts[atlas]
  if not Art.entries[atlas] or not layout then
    bad('unknown atlas ' .. tostring(atlas))
  end
  if look.hit ~= 'volumes' then
    local regions = look.regions or atlas
    local annotation = Anatomy.layouts[regions]
    if not annotation or (layout and #annotation.frames ~= #layout.frames) then
      bad('unknown/incomplete anatomy ' .. tostring(regions))
    end
    if not Masks.layouts[atlas] or (layout and #Masks.layouts[atlas] ~= #layout.frames) then
      bad('unknown/incomplete baked atlas masks ' .. tostring(atlas))
    end
  end
  local actions, checked = {}, {}
  for _, action in ipairs(def.attacks or {}) do
    actions[action.id] = true
  end
  local function sequence(id)
    if checked[id] then
      return
    end
    checked[id] = true
    for _, problem in ipairs(Contract.sequenceProblems(id)) do
      bad(problem)
    end
  end
  for action, id in pairs(look.art or {}) do
    -- False explicitly removes inherited artwork (the armored thrall).
    if id ~= false then
      if not actions[action] then
        bad('art names unknown attack ' .. tostring(action))
      end
      sequence(id)
    end
  end
  if look.evadeArt then
    if not (def.move and def.move.evade) then
      bad('evade artwork needs an evade movement')
    end
    sequence(look.evadeArt)
  end
  -- An attack's own strike pose (strike.<attack id>) names one of its attacks.
  for name in pairs(Atlases.poses[look.atlas or def.kind] or {}) do
    local action = name:match('^strike%.(.+)$')
    if action and not actions[action] then
      bad('strike pose ' .. name .. ' names no attack of it')
    end
  end
  return out
end
function Contract.validate(def)
  local problems = Contract.problems(def)
  assert(#problems == 0, table.concat(problems, '\n'))
  return def
end
function Contract.validateAll()
  for _, def in require('src.content.enemies').each() do
    Contract.validate(def)
  end
  for id in Sequences.each() do
    local problems = Contract.sequenceProblems(id)
    assert(#problems == 0, table.concat(problems, '\n'))
  end
  return true
end
return Contract

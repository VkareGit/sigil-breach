-- Cross references checked before native voices are built. Data schemas
-- validate numbers; this boundary ensures every named stem/voice exists.
local Archetypes = require('src.content.enemies')
local Maps = require('src.content.maps.index')
local Recipes = require('src.audio.recipes')
local Score = require('src.audio.score')
local CreatureAudio = require('src.content.creature_audio')
local C = {}
function C.scene(scene)
  if not scene then
    return
  end
  local layers = {}
  for _, layer in ipairs(Score.layers) do
    layers[layer.id] = true
  end
  local function mix(value)
    for id in pairs(value) do
      assert(layers[id], 'unknown soundscape stem ' .. id)
    end
  end
  for _, key in ipairs({ 'base', 'summoning', 'duel', 'pressure', 'aftermath' }) do
    mix(scene[key])
  end
  for _, region in ipairs(scene.regions or {}) do
    mix(region.mix)
  end
  for _, source in ipairs(scene.sources or {}) do
    assert(Recipes[source.voice], 'unknown ambient voice ' .. source.voice)
  end
end
function C.validate()
  local function voices(profile)
    for key, value in pairs(profile) do
      if type(value) == 'table' then
        voices(value)
      elseif type(value) == 'string' then
        assert(Recipes[value], 'unknown creature audio voice ' .. value)
      elseif key ~= 'sustain' or type(value) ~= 'boolean' then
        error('invalid creature audio profile field ' .. key)
      end
    end
  end
  for id, profile in pairs(CreatureAudio) do
    local def = assert(Archetypes.get(id), 'unknown creature audio owner ' .. id)
    local sections =
      { body = true, actions = true, projectile = true, projectiles = true, fields = true }
    for section in pairs(profile) do
      assert(sections[section], id .. ': unknown creature audio section ' .. section)
    end
    local actions = {}
    for _, action in ipairs(def.attacks) do
      actions[action.id] = true
    end
    for action in pairs(profile.actions or {}) do
      assert(actions[action], id .. ': unknown creature audio action ' .. action)
    end
    voices(profile)
  end
  for name, recipe in pairs(Recipes) do
    assert(
      not recipe.mixGroup or require('src.content.audio_mix').groups[recipe.mixGroup],
      name .. ': unknown mix group'
    )
    assert(
      not recipe.path or love.filesystem.getInfo(recipe.path, 'file'),
      name .. ': missing recording'
    )
    local paths = { [recipe.path or ''] = true }
    for _, path in ipairs(recipe.variants or {}) do
      assert(recipe.path and not paths[path], name .. ': variants need distinct recordings')
      assert(love.filesystem.getInfo(path, 'file'), name .. ': missing variant ' .. path)
      paths[path] = true
    end
    for _, voice in pairs(recipe.presence or {}) do
      assert(Recipes[voice], name .. ': unknown body context ' .. voice)
    end
    for _, field in ipairs({ 'gain', 'falloff', 'minPriority' }) do
      local value = recipe[field]
      assert(
        value == nil
          or (type(value) == 'number' and value == value and value >= 0 and value < math.huge),
        name .. ': invalid ' .. field
      )
    end
  end
  for _, map in Maps:each() do
    C.scene(map.decor and map.decor.soundscape)
  end
  for id, def in Archetypes.each() do
    for _, name in pairs(def.sounds) do
      assert(Recipes[name], id .. ': unknown voice ' .. name)
    end
    for _, attack in ipairs(def.attacks) do
      for _, key in ipairs({
        'sound',
        'windupSound',
        'windupVoice',
        'releaseVoice',
        'landingSound',
        'impactSound',
      }) do
        local name = attack[key]
        assert(
          not name or Recipes[name],
          id .. '/' .. attack.id .. ': unknown voice ' .. tostring(name)
        )
      end
    end
  end
end
return C

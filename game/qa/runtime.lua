-- Application adapter for developer modes. Production callbacks do not need
-- to repeat versioned flag lists or know which historical test file runs.
local Release = require('src.app.release')
local Q = {}
Q.__index = Q
local function normalize(flag)
  if type(flag) ~= 'string' then
    return flag
  end
  for _, mode in ipairs({ 'showcase', 'ui-audit', 'benchmark', 'detail-test', 'detail-review' }) do
    local prefix = '--' .. mode .. '-v'
    if flag:sub(1, #prefix) == prefix and flag:sub(#prefix + 1):match('^%d+$') then
      return '--' .. mode
    end
  end
  return flag
end
local captures = {
  ['--selftest'] = true,
  ['--input-test'] = true,
  ['--showcase'] = true,
  ['--ui-audit'] = true,
  ['--benchmark'] = true,
  ['--screenshot'] = true,
  ['--detail-test'] = true,
  ['--detail-review'] = true,
  ['--firing-review'] = true,
  ['--summoning-review'] = true,
  ['--hit-review'] = true,
  ['--hit-timing'] = true,
  ['--population'] = true,
  ['--bake-hit-masks'] = true,
  ['--core-measure'] = true,
  ['--step-study'] = true,
  ['--mask-formats'] = true,
  ['--pigment-review'] = true,
  ['--ritual-review'] = true,
  ['--hall-review'] = true,
  ['--hall-walk'] = true,
  ['--hall-ruin'] = true,
  ['--souls-review'] = true,
  ['--audio-export'] = true,
  ['--movement-review'] = true,
  ['--qa-smoke'] = true,
  ['--startup-check'] = true,
  ['--startup-fixture'] = true,
  ['--resource-plateau'] = true,
  ['--v11-reference'] = true,
  ['--view-measure'] = true,
}
-- The creature pipeline tools (plan v10 V7), each --name=value: an atlas id,
-- an annotation id, a spec or legend file, a creature id.
local tools = {
  ['--sheet-export'] = true,
  ['--sheet-spec'] = true,
  ['--anatomy-export'] = true,
  ['--anatomy-layers'] = true,
  ['--check-creature'] = true,
}
function Q.captureFlag(flag)
  return type(flag) == 'string'
    and (
      not not captures[normalize(flag)]
      or flag:match('^%-%-suite=') ~= nil
      or tools[flag:match('^(%-%-[%w-]+)=') or ''] == true
    )
end
function Q.new(arguments)
  local q = setmetatable({ flags = {}, values = {}, capture = false, isolated = false }, Q)
  for _, flag in pairs(arguments or {}) do
    if type(flag) == 'string' then
      flag = normalize(flag)
      q.flags[flag] = true
      -- --suite=<id>: one registered test suite (tests/suite.lua), for work on it.
      q.suite = q.suite or flag:match('^%-%-suite=(.+)$')
      local name, value = flag:match('^(%-%-[%w-]+)=(.+)$')
      if name and tools[name] then
        q.values[name] = value
      end
      q.capture = q.capture or Q.captureFlag(flag)
    end
  end
  q.isolated = q.capture or q:has('--ui-test')
  if q:has('--qa-smoke') then
    local selected = 0
    for _, entry in ipairs(require('qa.tooling').catalog) do
      selected = selected + (q:has(entry.flag) and 1 or 0)
    end
    assert(selected == 1, '--qa-smoke requires exactly one registered diagnostic tool')
  end
  q.output = os.getenv('SIGIL_UI_QA_DIR') or Release.qaOutput
  return q
end
function Q:has(flag)
  return not not self.flags[normalize(flag)]
end
function Q:prepare()
  if self.isolated then
    love.filesystem.setIdentity(Release.qaIdentity .. (self:has('--input-test') and '-input' or ''))
  end
  if self.capture then
    love.mouse.setRelativeMode(false)
    local relative = false
    love.mouse.setRelativeMode = function(enabled)
      relative = not not enabled
    end
    love.mouse.getRelativeMode = function()
      return relative
    end
    love.audio.setVolume(0)
  end
end
function Q:runEarly()
  if self:has('--startup-check') then
    require('qa.startup_check').run(self.output)
    love.event.quit(0)
    return true
  end
  if self:has('--bake-hit-masks') then
    local count = require('qa.bake_hit_masks').run(self.output .. '/hit-masks.lua')
    print('Baked ' .. count .. ' painted frames; source images unchanged.')
    love.event.quit(0)
    return true
  end
  if next(self.values) then
    -- The creature pipeline tools write into the QA output; the scripts
    -- (EXPORT-SHEET.ps1, EXPORT-ANATOMY.ps1, CHECK-CREATURE.ps1) install them.
    local missing = require('qa.art.pipeline').run(self.values, self.output)
    love.event.quit(missing > 0 and 1 or 0)
    return true
  end
  if self:has('--audio-export') then
    -- The score and every sound effect as WAV files (qa/audio_export.lua).
    require('qa.audio_export').run(self:has('--qa-smoke'))
    love.event.quit(0)
    return true
  end
  if not self:has('--benchmark') then
    return false
  end
  require('qa.benchmark').run(self.output, self:has('--qa-smoke'))
  love.event.quit(0)
  return true
end
function Q:run(G, renderer, getGame, settings, getLoading)
  if self.suite then
    require('tests.suite').run(G, renderer, getGame, self.output, self.suite, getLoading)
  elseif self:has('--detail-test') then
    require('tests.suite').run(G, renderer, getGame, self.output, 'details')
  elseif self:has('--detail-review') then
    require('qa.reviews.detail_review').run(self.output, G, renderer)
  elseif self:has('--firing-review') then
    require('qa.reviews.firing_review').run(self.output, G, renderer)
  elseif self:has('--summoning-review') then
    require('qa.reviews.summoning_review').run(self.output, G, renderer)
  elseif self:has('--hit-review') then
    -- Plan v7 H0: hit volumes against what is drawn (qa/reviews/hit_truth.lua).
    require('qa.reviews.hit_truth').run(self.output, G, renderer)
  elseif self:has('--hit-timing') then
    local truth = require('qa.hit_truth').new(renderer)
    require('qa.reviews.hit_timing').run(G, truth, self.output)
    truth:release()
  elseif self:has('--pigment-review') then
    require('qa.reviews.creature_pigment').run(G, renderer, self.output)
  elseif self:has('--ritual-review') then
    require('qa.reviews.ritual_art').run(G, renderer, self.output)
  elseif self:has('--hall-review') or self:has('--hall-walk') then
    require('qa.reviews.chapel_hall').run(G, renderer, self.output, self:has('--hall-walk'))
  elseif self:has('--souls-review') then
    require('qa.reviews.souls_moves').run(G, renderer, self.output)
  elseif self:has('--hall-ruin') then
    require('qa.reviews.hall_ruin').run(G, renderer, self.output)
  elseif self:has('--movement-review') then
    -- The knight's moves as the painted world shows them.
    require('qa.reviews.movement_marks_review').run(G, renderer, self.output)
  elseif self:has('--mask-formats') then
    -- Mask storage formats measured (qa/mask_formats.lua).
    require('qa.mask_formats').run(self.output)
  elseif self:has('--resource-plateau') then
    require('qa.resource_plateau').run(G, renderer, getGame(), settings, self.output)
  elseif self:has('--step-study') then
    -- Frame-rate and physics-step sensitivity (qa/step_study.lua).
    require('qa.step_study').run(G, self.output, self:has('--qa-smoke'))
  elseif self:has('--view-measure') then
    require('qa.view_measure').run(G, renderer, settings, self.output)
  elseif self:has('--v11-reference') then
    -- The 0.33 references of plan v11 E0 (qa/v11_reference.lua).
    require('qa.v11_reference').run(G, self.output)
  elseif self:has('--core-measure') then
    -- Core costs before/after a change (qa/core_measure.lua).
    require('qa.core_measure').run(G, self.output, self:has('--qa-smoke'))
  elseif self:has('--population') then
    -- Balance tuning (plan v5): the human-model populations alone.
    require('qa.scenarios.playtest').population(G)
  elseif self:has('--selftest') then
    require('tests.suite').run(G, renderer, getGame, self.output, nil, getLoading)
  elseif self:has('--input-test') then
    require('tests.input').run(getGame, settings, self.output .. '/input-results.txt', getLoading)
  elseif self:has('--ui-audit') then
    for _, line in ipairs(require('tests.cases.bitmap_ui').run(G, renderer) or {}) do
      print(line)
    end
  elseif self:has('--showcase') then
    require('qa.showcase').run(G, renderer)
  else
    return false
  end
  love.event.quit(0)
  return true
end
return Q

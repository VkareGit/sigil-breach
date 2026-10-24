-- Player entry point. Developer diagnostics are optional files, never required
-- by the shipped game. The same facade also supports a small installed-package
-- health check without shipping the development test runner.
local Release = require('src.app.release')
local R = {}
R.__index = R
local function developer()
  if love.filesystem.getInfo('qa/runtime.lua', 'file') then
    return require('qa.runtime')
  end
end
function R.captureFlag(flag)
  if flag == '--package-smoke' then
    return true
  end
  local diagnostics = developer()
  return diagnostics and diagnostics.captureFlag(flag) or false
end
function R.new(arguments)
  local flags = {}
  for _, flag in pairs(arguments or {}) do
    if type(flag) == 'string' then
      flags[flag] = true
    end
  end
  if not flags['--package-smoke'] then
    local diagnostics = developer()
    if diagnostics then
      return diagnostics.new(arguments)
    end
  end
  local smoke = not not flags['--package-smoke']
  return setmetatable({
    flags = flags,
    capture = smoke,
    isolated = smoke,
    output = os.getenv('SIGIL_UI_QA_DIR'),
  }, R)
end
function R:has(flag)
  return not not self.flags[flag]
end
function R:prepare()
  if self.isolated then
    love.filesystem.setIdentity(Release.qaIdentity .. '-package')
    love.mouse.setRelativeMode(false)
    love.mouse.setRelativeMode = function() end
    love.audio.setVolume(0)
  end
end
function R:runEarly()
  return false
end
function R:run(Game, renderer, getGame, settings)
  if not self:has('--package-smoke') then
    return false
  end
  require('src.app.package_smoke').run(Game, renderer, getGame, settings, self.output)
  love.event.quit(0)
  return true
end
return R

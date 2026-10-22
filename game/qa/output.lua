-- All developer reports belong to the selected run, not a historical release.
local Release = require('src.app.release')
local Output = {}

function Output.directory()
  return os.getenv('SIGIL_UI_QA_DIR') or Release.qaOutput
end

function Output.path(name)
  return Output.directory() .. '/' .. name
end

return Output

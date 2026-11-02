-- All developer reports belong to the selected run, not a historical release.
local Release = require('src.app.release')
local Output = {}

function Output.directory()
  return os.getenv('SIGIL_UI_QA_DIR') or Release.handOutput
end

function Output.path(name)
  return Output.directory() .. '/' .. name
end

-- The run that asked for a report (tools/project.ps1 names each one), so a
-- gate tells its own report from a stale one or one a parallel run wrote,
-- by identity rather than by file clocks.
function Output.receipt()
  return 'QA run: ' .. (os.getenv('SIGIL_QA_RUN') or 'direct invocation')
end

return Output

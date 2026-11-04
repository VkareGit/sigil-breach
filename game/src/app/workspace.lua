-- Linux developer output belongs outside the checkout. The scripts use the
-- same canonical project path and SHA-256 digest to separate independent clones.
local ffi = require('ffi')
local Workspace = {}
if ffi.os == 'Linux' then
  ffi.cdef('char *realpath(const char *path, char *resolved); void free(void *pointer);')
end

function Workspace.directory(project)
  project = project or love.filesystem.getSourceBaseDirectory()
  if ffi.os ~= 'Linux' then
    return project .. '/work'
  end
  local resolved = ffi.C.realpath(project, nil)
  assert(resolved ~= nil, 'Cannot resolve project directory: ' .. project)
  project = ffi.string(resolved)
  ffi.C.free(resolved)
  local tries = os.getenv('SIGIL_TRIES_DIR')
  if not tries or tries == '' then
    tries = love.filesystem.getUserDirectory():gsub('/+$', '') .. '/Work/tries'
  end
  assert(tries:sub(1, 1) == '/', 'SIGIL_TRIES_DIR must be an absolute path')
  local digest = love.data.encode('string', 'hex', love.data.hash('sha256', project))
  return tries:gsub('/+$', '') .. '/sigil-breach-' .. digest .. '/work'
end

return Workspace

-- QA exports use native paths outside the LÖVE save sandbox. Create parents
-- through the OS API, without sending directory names through cmd.exe or sh.
local ffi = require('ffi')
local Directory = {}
local create
if ffi.os == 'Windows' then
  ffi.cdef([[
    int __stdcall CreateDirectoryW(const unsigned short *path, void *security);
    unsigned long __stdcall GetFileAttributesW(const unsigned short *path);
    unsigned long __stdcall GetLastError(void);
    int __stdcall MultiByteToWideChar(unsigned int page, unsigned long flags,
      const char *source, int bytes, unsigned short *target, int length);
  ]])
  local kernel = ffi.load('kernel32')
  create = function(path)
    path = path:gsub('/', '\\')
    local size = kernel.MultiByteToWideChar(65001, 8, path, -1, nil, 0)
    assert(size > 0, 'Invalid UTF-8 directory: ' .. path)
    local wide = ffi.new('unsigned short[?]', size)
    assert(kernel.MultiByteToWideChar(65001, 8, path, -1, wide, size) > 0)
    if kernel.CreateDirectoryW(wide, nil) ~= 0 then
      return true
    end
    local err = tonumber(kernel.GetLastError())
    local attributes = tonumber(kernel.GetFileAttributesW(wide))
    return attributes ~= 4294967295 and math.floor(attributes / 16) % 2 == 1, err
  end
else
  ffi.cdef('int mkdir(const char *path, unsigned int mode);')
  create = function(path)
    if ffi.C.mkdir(path, 493) == 0 then
      return true
    end
    local err = ffi.errno()
    -- EEXIST alone also accepts a regular file. The trailing /. requires a directory.
    if err == 17 and ffi.C.mkdir(path .. '/.', 493) ~= 0 and ffi.errno() == 17 then
      return true
    end
    return false, err
  end
end

function Directory.ensure(path)
  assert(type(path) == 'string' and path ~= '' and not path:find('%z'), 'Invalid QA directory')
  if ffi.os == 'Windows' then
    path = path:gsub('\\', '/')
  end
  if path ~= '/' and not path:match('^%a:/$') then
    path = path:gsub('/+$', '')
  end
  local ok, err = create(path)
  if ok then
    return path
  end
  local parent = path:match('^(.*)/[^/]+$')
  if parent == '' then
    parent = '/'
  end
  if parent and parent ~= path then
    Directory.ensure(parent)
    ok, err = create(path)
  end
  assert(ok, 'Cannot create QA directory ' .. path .. ' (OS error ' .. tostring(err) .. ')')
  return path
end
return Directory

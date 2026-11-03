-- Exercise native QA directories without graphics or a shell, on both hosts.
return function(root, output)
  local file = assert(io.open(root .. '/qa/directory.lua', 'rb'))
  local text = file:read('*a')
  file:close()
  local Directory = assert(loadstring(text, '@qa/directory.lua'))()
  local path = output .. "/directory-test/nested space/quote' & $ percent%/leaf"
  Directory.ensure(path)
  Directory.ensure(path)
  file = assert(io.open(path .. '/proof.txt', 'wb'))
  file:write('native directory creation')
  file:close()
  assert(not pcall(Directory.ensure, path .. '/proof.txt/child'))
  assert(not pcall(Directory.ensure, ''))
  assert(not pcall(Directory.ensure, 'nul\0name'))
  return 'DIRECTORY: 5 checks passed (parents, repeat, file, empty, NUL).'
end

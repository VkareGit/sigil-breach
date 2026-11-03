-- The sound loader constructs filenames from registry fields, so no complete
-- path appears in a string literal. Check all combinations without decoding WAVs.
local function compare(paths, expected)
  local exact, folded, problems = {}, {}, {}
  for _, path in ipairs(paths) do
    exact[path], folded[path:lower()] = true, path
  end
  for _, path in ipairs(expected) do
    if not exact[path] then
      problems[#problems + 1] = path .. ' (on disk: ' .. (folded[path:lower()] or 'missing') .. ')'
    end
  end
  return problems
end
return function(root, manifest)
  assert(#compare({ 'assets/sounds/judge/B1-1.wav' }, { 'assets/sounds/judge/b1-1.wav' }) == 1)
  assert(#compare({ 'assets/sounds/judge/B1-1.wav' }, { 'assets/sounds/judge/B1-1.wav' }) == 0)
  local file = assert(io.open(root .. '/src/content/sound_sets.lua', 'rb'))
  local text = file:read('*a')
  file:close()
  local sounds = assert(loadstring(text, '@src/content/sound_sets.lua'))()
  local expected, paths = {}, {}
  for _, prefix in pairs(sounds.prefix) do
    for _, cue in pairs(sounds.cues) do
      for take = 1, sounds.takes do
        expected[#expected + 1] = sounds.root .. cue.event .. '/' .. prefix .. '-' .. take .. '.wav'
      end
    end
  end
  file = assert(io.open(manifest, 'rb'))
  for line in file:lines() do
    paths[#paths + 1] = line:gsub('\r$', '')
  end
  file:close()
  return compare(paths, expected), #expected
end

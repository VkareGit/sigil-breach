-- The profile's best classic score. The simulation consumes a named scalar
-- input, so recording/replay never depends on a later change of this file.
local Execution = require('src.storage.execution')
local finite = require('src.core.mathx').finite
local Score = { file = 'best-score-v03.txt' }
function Score.read(g)
  return Execution.read(g, 'classic.bestScore', function()
    local score = tonumber((love.filesystem.read(Score.file)))
    return finite(score) and math.max(0, score) or 0
  end)
end
function Score.write(g, value)
  if not Execution.canWrite(g) then
    return false, 'profile writes are disabled'
  end
  return love.filesystem.write(Score.file, tostring(value))
end
return Score

-- Original procedural score. Two seamless, aligned layers: breath/choir and ritual drums.
local S = { intensity = 0, music = 0.65 }
function S.init(A)
  local rate, n = 22050, 22050 * 8
  local choir = love.sound.newSoundData(n, rate, 16, 1)
  local drums = love.sound.newSoundData(n, rate, 16, 1)
  local rng = love.math.newRandomGenerator(911)
  local low = 0
  for i = 0, n - 1 do
    local t = i / rate
    low = low * 0.97 + (rng:random() * 2 - 1) * 0.03
    local breath = math.sin(math.pi * t / 8) ^ 2
    local voice = math.sin(2 * math.pi * 110 * t) * 0.040
      + math.sin(2 * math.pi * 164.875 * t) * 0.022
      + math.sin(2 * math.pi * 220.125 * t) * 0.012
    choir:setSample(i, (voice + low * 0.045) * breath)
    local beat = t % 0.5
    local hit = math.exp(-beat * 27)
    local slow = t % 2
    local kick = math.sin(2 * math.pi * (52 * slow + 1.5 * (1 - math.exp(-slow * 30))))
      * math.exp(-slow * 10)
      * 0.30
    local metal = math.sin(2 * math.pi * 330 * t) * math.exp(-beat * 45) * 0.07
    drums:setSample(i, math.max(-0.9, math.min(0.9, kick + low * hit * 0.7 + metal)))
  end
  S.choir = love.audio.newSource(choir, 'static')
  S.drums = love.audio.newSource(drums, 'static')
  for _, s in ipairs({ S.choir, S.drums }) do
    s:setLooping(true)
    s:setVolume(0)
    s:play()
  end
end
function S.update(A, dt, g)
  local target = g.state == 'playing' and not g.map and math.min(1, (g.threat or 0) / 3) or 0.05
  S.intensity = S.intensity
    + (target - S.intensity) * math.min(1, dt * (target > S.intensity and 1.6 or 0.5))
  if S.choir then
    S.choir:setVolume(S.music * (0.45 - S.intensity * 0.15))
    S.drums:setVolume(S.music * S.intensity * 0.64)
  end
  if A.ambient then
    A.ambient:setVolume(S.music * 0.55)
  end
end
return S

-- Short-lived visual objects. These never calculate hits or gameplay damage.
-- Keep pre-combat (shells/trails) and post-combat (particles) timing separate:
-- effects emitted during a shot must age exactly as they did before extraction.
local Audio = require('src.audio.audio')
local Trails = require('src.feedback.shot_trails')
local Presentation = require('src.session.presentation')
local Transients = {}

function Transients.burst(g, x, y, z, color, count, force)
  for _ = 1, count do
    local angle = love.math.random() * math.pi * 2
    local speed = love.math.random() * (force or 2)
    g.view.particles[#g.view.particles + 1] = {
      x = x,
      y = y,
      z = z,
      vx = math.sin(angle) * speed,
      vy = love.math.random() * 2,
      vz = math.cos(angle) * speed,
      life = 0.4 + love.math.random() * 0.5,
      color = color,
      size = 0.4 + love.math.random() * 0.6,
    }
  end
  while #g.view.particles > 240 do
    table.remove(g.view.particles, 1)
  end
end

function Transients.beforeCombat(g, dt)
  local numbers = g.view.damageNumbers
  if numbers then
    for i = #numbers, 1, -1 do
      local number = numbers[i]
      number.age = number.age + dt
      if number.age >= 0.7 then
        table.remove(numbers, i)
      end
    end
  end
  Trails.update(g, dt)

  for i = #g.view.shells, 1, -1 do
    local shell = g.view.shells[i]
    shell.life = shell.life - dt
    shell.x = shell.x + shell.vx * dt
    shell.y = shell.y + shell.vy * dt
    shell.vy = shell.vy + 520 * dt
    shell.angle = shell.angle + dt * (shell.bounced and 3 or 8)
    if shell.y >= 90 and shell.vy > 0 then
      shell.y = 90
      if not shell.bounced then
        shell.bounced = true
        shell.vy = -shell.vy * 0.24
        shell.vx = shell.vx * 0.65
        Audio.play('shell', 0.12)
      else
        shell.vy = 0
        shell.vx = shell.vx * math.exp(-dt * 12)
      end
    end
    if shell.life <= 0 then
      table.remove(g.view.shells, i)
    end
  end
end

function Transients.afterCombat(g, dt)
  for i = #g.view.particles, 1, -1 do
    local particle = g.view.particles[i]
    particle.life = particle.life - dt
    particle.vy = particle.vy - dt * 4
    particle.x = particle.x + particle.vx * dt
    particle.y = particle.y + particle.vy * dt
    particle.z = particle.z + particle.vz * dt
    if particle.life < 0 or particle.y < 0 then
      table.remove(g.view.particles, i)
    end
  end
end

-- The simulation reaches these through its presentation hooks.
Presentation.hook('burst', Transients.burst)
Presentation.hook('transientsBefore', Transients.beforeCombat)
Presentation.hook('transientsAfter', Transients.afterCombat)
return Transients

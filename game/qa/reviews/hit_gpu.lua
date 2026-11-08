-- Validate the CPU silhouette oracle against actual rasterized living poses.
-- Samples pixel centres (not a projected point rounded onto another ray),
-- including ability sheets, pose transitions, three views and interpolation.
local Field = require('src.run.test_field')
local Rules = require('src.combat.rules')
local Actions = require('src.enemies.actions')
local Catalog = require('src.render.fresco_enemies')
local Presentation = require('src.render.presentation')
local Truth = require('qa.hit_truth')
local Review = {}
local STEP = 1 / 120
local views = { { 3, 0 }, { 8, 0.4 }, { 16, -0.3 } }
local function pixelRay(renderer, x, y)
  local u = (2 * x / renderer.w - 1) * (renderer.w / renderer.h) / renderer.projection
  local v = (1 - 2 * y / renderer.h) / renderer.projection
  local f, r, up = renderer.forward, renderer.right, renderer.up
  return f[1] + r[1] * u + up[1] * v, f[2] + r[2] * u + up[2] * v, f[3] + r[3] * u + up[3] * v
end
local function compare(g, e, renderer, truth)
  local lg = love.graphics
  renderer:frameCamera(g, 1280, 720)
  lg.clear(0, 0, 0, 0, 0, 1)
  lg.setShader(renderer.spriteShader)
  renderer:cameraUniforms(renderer.spriteShader)
  lg.setDepthMode('less', true)
  renderer:enemy(g, e)
  lg.setShader()
  lg.setDepthMode()
  lg.setCanvas()
  local image = renderer.canvas:newImageData()
  local place = truth:place(g, e, {})
  local result = { points = 0, agree = 0, edge = 0, wrong = 0 }
  local tested = {}
  for row = 0, 47 do
    for col = 0, 31 do
      local sx, sy = renderer:project(Truth.world(place, (col + 0.5) / 32, (row + 0.5) / 48))
      if sx and sx >= 0 and sy >= 0 and sx < renderer.w and sy < renderer.h then
        local x, y = math.floor(sx), math.floor(sy)
        local key = y * renderer.w + x
        if not tested[key] then
          tested[key] = true
          local dx, dy, dz = pixelRay(renderer, x + 0.5, y + 0.5)
          local camera = renderer.camera
          local distance, u, v = Truth.cross(place, camera[1], camera[2], camera[3], dx, dy, dz)
          local class, edge = 'air', false
          if distance then
            class, edge = truth:classify(place, u, v)
          end
          local _, _, _, alpha = image:getPixel(x, y)
          result.points = result.points + 1
          if edge then
            result.edge = result.edge + 1
          elseif (alpha > 0.5) == (class ~= 'air') then
            result.agree = result.agree + 1
          else
            result.wrong = result.wrong + 1
          end
        end
      end
    end
  end
  image:release()
  return result
end
local function episodes(kind)
  local list = {
    { id = 'fight', seconds = 6 },
    {
      id = 'falter',
      seconds = 0.8,
      begin = function(_, e)
        Rules.guard(e, Rules.body(e).poise * 1.05)
      end,
    },
  }
  local body = Rules.body({ kind = kind })
  if (body.tier or 'common') == 'common' then
    list[#list + 1] = {
      id = 'knockdown',
      seconds = 0.8,
      begin = function(_, e)
        Rules.knockDown(e)
      end,
    }
  end
  for _, attack in ipairs(Rules.archetype({ kind = kind }).attacks) do
    list[#list + 1] = {
      id = attack.id,
      seconds = 2.5,
      begin = function(g, e)
        Actions.begin(g, e, math.sqrt((e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2), attack)
      end,
    }
  end
  return list
end
function Review.run(G, renderer, truth, output)
  local total = { points = 0, agree = 0, edge = 0, worst = 0, cases = 0 }
  local rows = { 'kind,episode,frame,view,points,agree,edge,wrong' }
  for _, kind in ipairs(Catalog.kinds) do
    for _, episode in ipairs(episodes(kind)) do
      local g = Field.new(G)
      g.ephemeral = true
      local e = Field.spawn(g, kind, 1)[1]
      Field.close(g)
      if episode.begin then
        episode.begin(g, e)
      end
      local seen = {}
      for tick = 0, math.floor(episode.seconds / STEP) do
        if e.hp <= 0 then
          break
        end
        -- The same interpolation route as Application:draw; endpoints and
        -- an intermediate pose are exercised across the sampled states.
        local sample = Presentation.sample(g, tick % 3 * 0.5)
        local drawn = sample.enemies[1]
        local place = truth:place(sample, drawn, {})
        local key = place.key .. '/' .. tostring(drawn.ai)
        if not seen[key] then
          seen[key] = true
          for vi, view in ipairs(views) do
            local p = sample.player
            local px, pz, jump, yaw, pitch = p.x, p.z, p.jump, p.yaw, p.pitch
            local nx, nz = px - drawn.x, pz - drawn.z
            local length = math.sqrt(nx * nx + nz * nz)
            p.x, p.z = drawn.x + nx / length * view[1], drawn.z + nz / length * view[1]
            p.jump = math.max(0, view[2])
            p.yaw, p.pitch = math.atan2(-nx, -nz), view[2] * 0.1
            local r = compare(sample, drawn, renderer, truth)
            p.x, p.z, p.jump, p.yaw, p.pitch = px, pz, jump, yaw, pitch
            total.cases = total.cases + 1
            total.points, total.agree, total.edge =
              total.points + r.points, total.agree + r.agree, total.edge + r.edge
            total.worst = math.max(total.worst, r.wrong)
            rows[#rows + 1] = string.format(
              '%s,%s,%s,%d,%d,%d,%d,%d',
              kind,
              episode.id,
              place.frame,
              vi,
              r.points,
              r.agree,
              r.edge,
              r.wrong
            )
          end
        end
        Presentation.capture(g)
        g:update(STEP, {})
      end
    end
  end
  local file = assert(io.open(output .. '/hit-gpu.csv', 'w'))
  file:write(table.concat(rows, '\n') .. '\n')
  file:close()
  return total
end
return Review

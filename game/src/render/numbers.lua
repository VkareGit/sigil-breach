-- Presentation of confirmed contacts. The combat system owns the value,
-- position and lifetime; this pass only places the existing painted glyphs.
-- Labels stay with visible contacts, clear the aim, and share a bounded layout.
local Numbers = require('src.ui.fonts.painted_numbers')
local MathX = require('src.core.mathx')
local Ballistics = require('src.combat.ballistics')
local N = { limit = 24, lifetime = 0.7 }
local min, max, abs, floor, sqrt = math.min, math.max, math.abs, math.floor, math.sqrt
local colors = {
  body = { 0.96, 0.92, 0.82 },
  armor = { 0.70, 0.78, 0.86 },
  head = { 1, 0.86, 0.52 },
  broke = { 1, 0.80, 0.30 },
  wound = { 1, 0.52, 0.50 },
  kill = { 1, 0.62, 0.36 },
  -- 0.20: a counter-hit glows ember red, a crippling leg hit pale ochre.
  counter = { 1, 0.42, 0.24 },
  crippled = { 0.86, 0.76, 0.52 },
}
local finite = MathX.finite
local function overlap(ax, ay, aw, ah, bx, by, bw, bh, gap)
  gap = gap or 0
  return ax < bx + bw + gap and ax + aw + gap > bx and ay < by + bh + gap and ay + ah + gap > by
end
N.overlap = overlap
-- Visibility tests the original impact, not the decorative rising label.
-- The same round pillars and wall heights that stop a bullet stop its label.
function N.visible(r, g, n)
  local cx, cy, cz = r.camera[1], r.camera[2], r.camera[3]
  local dx, dy, dz = n.x - cx, n.y - 0.15 - cy, n.z - cz
  local distance = sqrt(dx * dx + dy * dy + dz * dz)
  if distance < 0.1 then
    return false
  end
  local hit =
    Ballistics.world(g.world, cx, cy, cz, dx / distance, dy / distance, dz / distance, distance)
  return hit >= distance - 0.035
end
local function usable(n)
  return finite(n.x)
    and finite(n.y)
    and finite(n.z)
    and finite(n.value)
    and finite(n.age)
    and n.age >= 0
    and n.age < N.lifetime
    and n.value >= 0
end
function N.layout(r, g, x, y, vw, vh, measure)
  local state = r.numberLayout
  if not state then
    state = { items = {}, pool = {} }
    r.numberLayout = state
  end
  local items, pool = state.items, state.pool
  for i = #items, 1, -1 do
    items[i] = nil
  end
  if
    g.state ~= 'playing'
    or g.map
    or g.help
    or g.showDamageNumbers == false
    or not g.view.damageNumbers
  then
    return items
  end
  measure = measure or Numbers.measure
  local unit = vh / 600
  local margin = 8 * unit
  local gap = 5 * unit
  local left, right, top, bottom = x + margin, x + vw - margin, y + margin, y + vh - margin
  local aimX, aimY = x + vw * 0.5, y + vh * 0.5
  local aimHalf = 25 * unit
  local list = g.view.damageNumbers
  -- Older entries keep their place when another target is hit. No sort,
  -- per-frame random drift or mutation of the authoritative number records.
  for i = max(1, #list - N.limit + 1), #list do
    local n = list[i]
    if usable(n) and N.visible(r, g, n) then
      local px, py = r:project(n.x, n.y, n.z)
      if px and px >= 0 and px <= r.w and py >= 0 and py <= r.h then
        local t = n.age / N.lifetime
        local big = n.kill or n.head or n.wound or n.broke or n.counter
        local height = (big and 32 or 26)
          * unit
          * (1 + (n.broke and 0.24 or 0.14) * max(0, 1 - n.age * 8))
        -- tostring switches large Lua numbers to scientific notation, whose
        -- "e+" is absent from the numeral atlas. Keep the finite integer in digits.
        local text = string.format('%.0f', floor(n.value + 0.5))
        local width = measure(text, height)
        local maxWidth = min(150 * unit, vw * 0.23)
        if width > maxWidth then
          height = height * maxWidth / width
          width = maxWidth
        end
        local side = n.side and n.side < 0 and -1 or 1
        local anchorX = x + px * vw / r.w
        local anchorY = y + py * vh / r.h
        local bx =
          max(left, min(right - width, anchorX + side * (30 + t * 12) * unit - width * 0.5))
        local by = max(top, min(bottom - height, anchorY - height - (12 + t * 24) * unit))
        -- Keep the entire glyph box clear, including long multi-digit numbers.
        if
          overlap(
            bx,
            by,
            width,
            height,
            aimX - aimHalf,
            aimY - aimHalf,
            aimHalf * 2,
            aimHalf * 2,
            gap
          )
        then
          by = aimY - aimHalf - gap - height
        end
        -- Stack along the contact's own column rather than spread labels across
        -- unrelated enemies. At most 24 boxes; no unbounded search or allocations.
        local packed = false
        for _ = 1, N.limit + 1 do
          local nextY = by
          for _, placed in ipairs(items) do
            if overlap(bx, by, width, height, placed.x, placed.y, placed.w, placed.h, gap) then
              nextY = min(nextY, placed.y - gap - height)
            end
          end
          if nextY == by then
            packed = true
            break
          end
          by = nextY
          if by < top then
            break
          end
        end
        if packed and by >= top and by + height <= bottom and width <= right - left then
          local slot = #items + 1
          local item = pool[slot]
          if not item then
            item = { color = { 1, 1, 1, 1 } }
            pool[slot] = item
          end
          local kind = n.kill and 'kill'
            or (
              n.wound and 'wound'
              or (
                n.counter and 'counter'
                or (
                  n.broke and 'broke'
                  or (
                    n.crippled and 'crippled'
                    or (n.head and 'head' or (n.armor and 'armor' or 'body'))
                  )
                )
              )
            )
          local color = colors[kind]
          item.x, item.y, item.w, item.h = bx, by, width, height
          item.text, item.source, item.kind = text, n, kind
          item.color[1], item.color[2], item.color[3], item.color[4] =
            color[1], color[2], color[3], min(1, (1 - t) * 2.2)
          items[slot] = item
        end
      end
    end
  end
  return items
end
function N.draw(r, g, x, y, vw, vh)
  local items = N.layout(r, g, x, y, vw, vh)
  if #items == 0 then
    return
  end
  local lg = love.graphics
  lg.push('all')
  lg.setScissor(x, y, vw, vh)
  for _, item in ipairs(items) do
    Numbers.draw(item.text, item.x + item.w * 0.5, item.y, item.w, item.h, item.color, false)
  end
  lg.pop()
end
return N

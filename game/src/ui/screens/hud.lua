-- The classic arena HUD: health, ward, weapon, ability, boss banner, objective.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local red, blue, green = Skin.colors.red, Skin.colors.blue, Palette.green
local T = require('src.content.tuning')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local HUD = require('src.ui.hud')
local D = require('src.ui.descent')
local S = {}
function S.draw(g, s, U)
  if g.run then
    return HUD.draw(g, s, U, D)
  end
  local p = g.player
  do
    text('I / LIMBO', 28, 20, 20, gold)
    text(U.objective(g), 28, 48, 20, ivory)
    for i, seal in ipairs(g.world.seals) do
      local x = 28 + (i - 1) * 132
      c(seal.active and seal.color or muted)
      lg.setLineWidth(2)
      lg.rectangle('line', x, 87, 13, 13)
      if seal.active then
        rect(x + 3, 90, 7, 7, seal.color)
      end
      text(seal.name, x + 21, 82, 16, seal.active and muted or ivory)
    end
  end
  right('TAB  MAP   /   F1  HELP', 1252, 22, 16, muted)
  right(
    string.format('%02d:%02d', math.floor(g.elapsed / 60), math.floor(g.elapsed % 60)),
    1252,
    48,
    20,
    gold
  )
  if not g.run and (g.threat or 0) < 1 and not g.bossSpawned then
    local nearest, d = nil, 1e9
    for _, seal in ipairs(g.world.seals) do
      local ds = (seal.x - p.x) ^ 2 + (seal.z - p.z) ^ 2
      if not seal.active and ds < d then
        nearest = seal
        d = ds
      end
    end
    if nearest then
      local a = (math.atan2(nearest.x - p.x, nearest.z - p.z) - p.yaw + math.pi) % (2 * math.pi)
        - math.pi
      local x = 640 + math.max(-1, math.min(1, a)) * 120
      c(gold, 0.8)
      lg.polygon('line', x, 32, x + 6, 38, x, 44, x - 6, 38)
      text(nearest.name .. '  ' .. math.floor(math.sqrt(d)) .. ' m', x - 45, 50, 14, muted)
    end
  end
  if g.bossSpawned and not g.bossDead then
    for _, e in ipairs(g.enemies) do
      local banner = require('src.content.enemies').look(e).banner
      if banner and e.hp > 0 then
        center(e.hp < e.maxHp * 0.5 and banner.plainFury or banner.calm, 28, 20, ivory)
        bar(435, 60, 410, e.hp / e.maxHp, red)
      end
    end
  end
  local gap = 5 + g.view.recoil * 7
  local cx, cy = U.aimX or 640, U.aimY or 360
  c(
    g.view.hitmarker > 0
        and (g.view.lastKill and gold or (g.view.armorHit and blue or ((g.view.hitWeight or 0) < 0.3 and muted or red)))
      or ivory,
    0.9
  )
  lg.setLineWidth(2)
  lg.line(cx - gap - 6, cy, cx - gap, cy)
  lg.line(cx + gap, cy, cx + gap + 6, cy)
  lg.line(cx, cy - gap - 6, cx, cy - gap)
  rect(cx - 1, cy - 1, 2, 2, ivory)
  if g.view.hitmarker > 0 then
    lg.line(cx - 11, cy - 11, cx - 6, cy - 6)
    lg.line(cx + 6, cy + 6, cx + 11, cy + 11)
    lg.line(cx - 11, cy + 11, cx - 6, cy + 6)
    lg.line(cx + 6, cy - 6, cx + 11, cy - 11)
  end
  local inHand = Weapons.inHand(g)
  if inHand.fire.pellets > 1 then
    local cone = 640
      * math.tan(T.pelletSpread * require('src.content.weapons').spread(g))
      / math.tan(
        math.rad((g.view.fov or T.baseFov) + ((g.view.motion ~= false) and g.view.fovKick or 0)) / 2
      )
    c(muted, 0.45)
    lg.setLineWidth(1)
    lg.line(cx - cone, cy - 4, cx - cone, cy + 4)
    lg.line(cx + cone, cy - 4, cx + cone, cy + 4)
  end
  if g.reload > 0 then
    bar(cx - 25, cy + 29, 50, 1 - g.reload / g.reloadDuration, gold)
  end
  require('src.feedback.weight').drawMarks(g, cx, cy, 100)
  panel(24, 602, 260, 94)
  text(tostring(math.ceil(p.hp)), 42, 608, 48, p.hp < 30 and red or ivory)
  text('HEALTH', 44, 665, 16, muted)
  text(tostring(math.ceil(p.armor)), 192, 617, 28, blue)
  text('WARD', 191, 654, 14, muted)
  bar(42, 687, 148, p.hp / 100, p.hp < 30 and red or ivory)
  panel(1000, 602, 256, 94)
  text(inHand.hud.title, 1016, 610, 18, gold)
  local mag, reserve = Weapons.ammo(g)
  text(tostring(mag), 1016, 634, 42, mag == 0 and red or ivory)
  text('/ ' .. reserve .. ' ROUNDS', 1077, 650, 16, muted)
  -- A multi-round pull shows its rounds one by one (the two barrels).
  if inHand.fire.rounds > 1 then
    for i = 1, inHand.capacity do
      rect(1210 + (i - 1) * 15, 640, 9, 20, mag >= i and gold or Palette.emptyRound)
    end
  end
  if g.reload > 0 then
    right(Reload.label(g), 1250, 551, 14, gold)
  elseif mag > 0 and mag < inHand.fire.rounds then
    right(inHand.hud.partialShort, 1250, 551, 14, muted)
  end
  -- Keep the selected slot visible in the two-tab space as the arsenal grows.
  local count = Weapons.count(g)
  local first = math.max(1, math.min(g.weapon - 1, count - 1))
  for column = 0, math.min(2, count) - 1 do
    local slot = first + column
    local profile = Weapons.profile(slot, g)
    local draw = column == 0 and text or right
    draw(
      slot .. '  ' .. profile.hud.tab,
      column == 0 and 1006 or 1250,
      578,
      14,
      g.weapon == slot and ivory or muted
    )
  end
  panel(304, 643, 205, 53)
  key('Q', 317, 655)
  local ability, power = Abilities.slot(g, 1)
  text(ability and ability.tag or '', 354, 646, 16, ivory)
  local uses, capacity = power and power.uses or 0, ability and ability.capacity or 1
  text(uses .. ' / ' .. capacity, 354, 670, 16, uses > 0 and gold or muted)
  bar(318, 691, 176, uses / capacity, gold)
  panel(783, 643, 197, 53)
  key('SHIFT', 795, 655, 62)
  text('DODGE', 870, 647, 16, ivory)
  for i = 1, 2 do
    bar(872 + (i - 1) * 44, 680, 34, math.max(0, p.dash - i + 1), gold)
  end
  text(
    p.slideTimer > 0 and 'SLIDE' or 'CTRL  SLIDE',
    796,
    613,
    14,
    p.slideTimer > 0 and gold or muted
  )
  if p.slideCooldown > 0 then
    bar(796, 634, 176, 1 - p.slideCooldown / 0.85, gold)
  end
  if g.view.feedbackTimer > 0 then
    text(g.view.feedback, 29, 548, 18, gold)
  end
  if g.comboTimer > 0 and g.combo > 1 then
    text('CHAIN x' .. g.combo, 29, 520, 20, ivory)
  end
  local ctx = g:context()
  if ctx then
    panel(390, 521, 500, 42)
    center(ctx, 529, 18, gold)
  end
  if g.zoneTimer > 0 and g.elapsed > 1 then
    center(g.zone, 165, 28, ivory)
  end
  if g.view.messageTimer > 0 then
    center(g.view.message, 119, 20, ivory)
  end
  if s.hints ~= false then
    local hint = g.elapsed < 8
        and 'WASD: move   /   SHIFT: dodge   /   CTRL: slide   /   SPACE: jump'
      or nil
    if p.hp < 30 then
      hint = 'Find medkits. The Ember lets you rest between waves.'
    elseif
      g.weapon == 1
      and Weapons.count(g) > 1
      and Weapons.ammo(g) == 0
      and select(2, Weapons.ammo(g)) == 0
    then
      hint = '[2] Draw the ' .. Weapons.profile(2, g).hud.draw .. '.'
    elseif g.elapsed > 8 and g.elapsed < 14 then
      hint = 'Shotgun: close, into a crowd. Revolver: precise at range.'
    end
    if hint then
      center(hint, 201, 18, muted)
    end
  end
end
return S

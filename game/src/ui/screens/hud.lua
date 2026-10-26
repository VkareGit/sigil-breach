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
local Slots = require('src.ui.hud_slots')
local HUD = require('src.ui.hud')
local D = require('src.ui.descent')
local Pools = require('src.session.world')
local Text = require('src.content.text')
local S = {}
function S.draw(g, s, U)
  -- A mode that reports status bar data (run/modes.lua: hud) gets the fresco
  -- HUD; the classic arena, which reports none, keeps its own below.
  if require('src.run.modes').of(g).hud then
    return HUD.draw(g, s, U, D)
  end
  local p = g.player
  do
    text(Text.get('chud_title'), 28, 20, 20, gold)
    text(U.objective(g), 28, 48, 20, ivory)
    for i, seal in ipairs(g.world.seals) do
      local x = 28 + (i - 1) * 132
      c(seal.active and seal.color or muted)
      lg.setLineWidth(2)
      lg.rectangle('line', x, 87, 13, 13)
      if seal.active then
        rect(x + 3, 90, 7, 7, seal.color)
      end
      text(Text.get(seal.name), x + 21, 82, 16, seal.active and muted or ivory)
    end
  end
  right(Text.get('chud_utility'), 1252, 22, 16, muted)
  right(
    string.format('%02d:%02d', math.floor(g.elapsed / 60), math.floor(g.elapsed % 60)),
    1252,
    48,
    20,
    gold
  )
  if (g.threat or 0) < 1 and not g.bossSpawned then
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
      text(
        Text.get(
          'chud_seal_distance',
          { name = Text.get(nearest.name), distance = math.floor(math.sqrt(d)) }
        ),
        x - 45,
        50,
        14,
        muted
      )
    end
  end
  if g.bossSpawned and not g.bossDead then
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      local banner = require('src.content.enemies').look(e).banner
      if banner and e.hp > 0 then
        center(Text.get(e.hp < e.maxHp * 0.5 and banner.plainFury or banner.calm), 28, 20, ivory)
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
  text(Text.get('chud_health'), 44, 665, 16, muted)
  text(tostring(math.ceil(p.armor)), 192, 617, 28, blue)
  text(Text.get('chud_ward'), 191, 654, 14, muted)
  bar(42, 687, 148, p.hp / 100, p.hp < 30 and red or ivory)
  panel(1000, 602, 256, 94)
  text(Text.get(inHand.hud.title), 1016, 610, 18, gold)
  local mag, reserve = Weapons.ammo(g)
  text(tostring(mag), 1016, 634, 42, mag == 0 and red or ivory)
  text(Text.get('chud_rounds', { count = reserve }), 1077, 650, 16, muted)
  -- A multi-round pull shows its rounds one by one (the two barrels).
  if inHand.fire.rounds > 1 then
    for i = 1, inHand.capacity do
      rect(1210 + (i - 1) * 15, 640, 9, 20, mag >= i and gold or Palette.emptyRound)
    end
  end
  if g.reload > 0 then
    right(Reload.label(g), 1250, 551, 14, gold)
  elseif mag > 0 and mag < inHand.fire.rounds then
    right(Text.get(inHand.hud.partialShort), 1250, 551, 14, muted)
  end
  -- Keep the selected slot visible in the two-tab space as the arsenal grows.
  for column, weapon in ipairs((Slots.weapons(g, 2))) do
    local draw = column == 1 and text or right
    draw(
      Text.get('chud_tab', { slot = weapon.slot, name = Text.get(weapon.def.hud.tab) }),
      column == 1 and 1006 or 1250,
      578,
      14,
      weapon.selected and ivory or muted
    )
  end
  -- The equipment of every keyed slot (ui/hud_slots.lua): one item in full,
  -- more one row each.
  local kit = Slots.equipment(g)
  panel(304, 643, 205, 53)
  if #kit == 1 then
    local item = kit[1]
    key(Text.get('key_name', { key = item.key }), 317, 655)
    text(item.def and Text.get(item.def.tag) or '', 354, 646, 16, ivory)
    text(
      Text.get('chud_uses', { uses = item.uses, capacity = item.capacity }),
      354,
      670,
      16,
      item.uses > 0 and gold or muted
    )
    bar(318, 691, 176, item.uses / item.capacity, gold)
  else
    for row, item in ipairs(kit) do
      local y = 646 + (row - 1) * 16
      text(
        Text.get('ability_key', { key = item.key, tag = Text.get(item.def.tag) }),
        317,
        y,
        14,
        ivory
      )
      right(
        Text.get('chud_uses', { uses = item.uses, capacity = item.capacity }),
        496,
        y,
        14,
        item.uses > 0 and gold or muted
      )
    end
  end
  panel(783, 643, 197, 53)
  -- Wide enough for the painted SHIFT (62 px cut its last letter); DODGE stays.
  key(Text.get('key_dodge'), 788, 655, 78)
  text(Text.get('chud_dodge'), 870, 647, 16, ivory)
  for i = 1, 2 do
    bar(872 + (i - 1) * 44, 680, 34, math.max(0, p.dash - i + 1), gold)
  end
  text(
    Text.get(p.slideTimer > 0 and 'chud_sliding' or 'chud_slide'),
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
    text(Text.get('hud_chain', { count = g.combo }), 29, 520, 20, ivory)
  end
  local ctx = g:context()
  if ctx then
    panel(390, 521, 500, 42)
    center(ctx, 529, 18, gold)
  end
  if g.zoneTimer > 0 and g.elapsed > 1 then
    center(Text.get(g.zone), 165, 28, ivory)
  end
  if g.view.messageTimer > 0 then
    center(g.view.message, 119, 20, ivory)
  end
  if s.hints ~= false then
    local hint = g.elapsed < 8 and Text.get('chud_hint_moves') or nil
    if p.hp < 30 then
      hint = Text.get('hud_hint_hurt')
    elseif
      g.weapon == 1
      and Weapons.count(g) > 1
      and Weapons.ammo(g) == 0
      and select(2, Weapons.ammo(g)) == 0
    then
      hint = Text.get('chud_hint_draw', { weapon = Text.get(Weapons.profile(2, g).hud.draw) })
    elseif g.elapsed > 8 and g.elapsed < 14 then
      hint = Text.get('chud_hint_guns')
    end
    if hint then
      center(hint, 201, 18, muted)
    end
  end
end
return S

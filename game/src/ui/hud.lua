local H = {}
local lg = love.graphics
local Skin = require('src.ui.skin')
local T = require('src.content.tuning')
local Reload = require('src.combat.reload')
local B = require('src.combat.ballistics')
local L = require('src.ui.layout')
local Portrait = require('src.ui.portrait')
local Numbers = require('src.ui.fonts.painted_numbers')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Weight = require('src.feedback.weight')
local Rules = require('src.combat.rules')
local Palette = require('src.ui.palette')
local Modes = require('src.run.modes')
local C = Skin.colors
local U
-- Guard (poise) under a health bar: gold fills as blows accumulate toward
-- the break; after a break the strip is grey and shrinks with the lock; a
-- boss's exposed window pulses pale gold. The rule made readable.
function H.guardStrip(g, e, x, y, w)
  local guard = Rules.guardThreshold(e)
  local lock = e.staggerLock or 0
  lg.setColor(0.10, 0.07, 0.05, 0.9)
  lg.rectangle('fill', x - 1, y - 1, w + 2, 6)
  if Rules.has(e, 'exposed') then
    local pulse = 0.65 + 0.35 * math.abs(math.sin((g.time or 0) * 9))
    lg.setColor(0.98, 0.86, 0.52, pulse)
    lg.rectangle('fill', x, y, w, 4)
  elseif lock > 0 then
    local full = Rules.lockTime(e)
    lg.setColor(0.52, 0.50, 0.46, 0.85)
    lg.rectangle('fill', x, y, math.floor(w * math.min(1, lock / full)), 4)
  else
    local fill = math.min(1, (e.poise or 0) / guard)
    if fill > 0 then
      lg.setColor(0.98, 0.60, 0.14, 1)
      lg.rectangle('fill', x, y, math.max(1, math.floor(w * fill)), 4)
    end
  end
  lg.setColor(1, 1, 1)
end
local function color(c, a)
  lg.setColor(c[1], c[2], c[3], a or 1)
end
local function text(t, x, y, size, c)
  Skin.text(t, x, y, U.fonts[size or 18], c or C.ivory)
end
local function centered(t, cx, y, size, c)
  text(t, cx - U.fonts[size]:getWidth(t) / 2, y, size, c)
end
local function center(t, y, size, c)
  centered(t, 640, y, size, c)
end
local function number(t, cx, y, w, h, c)
  local x, top, width, height = Numbers.draw(t, cx, y, w, h, c)
  Skin.imageBounds('painted number ' .. t, x, top, width, height)
end
local function fitted(t, cx, y, size, w, c)
  for _, s in ipairs({ size, 22, 18, 16, 14, 12, 11 }) do
    if s <= size and U.fonts[s]:getWidth(t) <= w then
      return centered(t, cx, y, s, c)
    end
  end
  centered(t, cx, y, 11, c)
end
local function line(x1, y1, x2, y2, c, w)
  color(c)
  lg.setLineWidth(w or 2)
  lg.line(x1, y1, x2, y2)
end
local function notice(label, y, size, tint)
  local width = math.min(450, Skin.inkBounds(U.fonts[size], label).w + 28)
  Skin.panel(18, y, width, 44, 7, 10)
  Skin.zone('combat notice ' .. label, 28, y + 10, width - 20, 24)
  Skin.boxText(label, 30, y + 11, width - 24, 22, U.fonts[size], tint)
  Skin.endZone()
end
-- The status bar. What it shows of the mode (purse, glyph, echo, progress)
-- is the mode's report (run/modes.lua: hud), never its record read here.
function H.status(g, run)
  run = run or Modes.act(g, 'hud')
  local p = g.player
  require('src.ui.reliquary').status()
  Skin.lightField(0, 584, 1280, 136)
  Skin.zone('HUD ammunition', 133, 628, 105, 68)
  local mag, reserve = Weapons.ammo(g)
  fitted('AMMO', 185, 630, 14, 100, C.muted)
  number(tostring(mag), 185, 646, 98, 29, mag == 0 and C.red or C.ivory)
  local ammoCaption = g.reload > 0 and Reload.label(g) or ('RES. ' .. reserve)
  fitted(
    ammoCaption,
    185,
    678,
    14,
    100,
    g.reload > 0 and C.gold or (reserve == 0 and C.red or C.muted)
  )
  Skin.endZone()
  Skin.zone('HUD health', 271, 628, 119, 68)
  centered('HEALTH', 330, 630, 14, C.muted)
  number(math.ceil(p.hp) .. '%', 330, 648, 112, 29, p.hp < 30 and C.red or Palette.wound)
  Skin.meter(275, 686, 110, p.hp / 100, C.red, 12)
  Skin.endZone()
  Skin.zone('HUD arsenal', 421, 628, 115, 68)
  centered('ARSENAL', 478, 630, 14, C.muted)
  -- Two painted rows: scroll around the selected slot instead of silently
  -- dropping any third weapon or overflowing the fresco's lower ornament.
  local count = Weapons.count(g)
  local first = math.max(1, math.min(g.weapon - 1, count - 1))
  for row = 0, math.min(2, count) - 1 do
    local slot = first + row
    local def = Weapons.profile(slot, g)
    local tint = g.weapon == slot and C.gold or C.muted
    local label = count > 2 and (slot .. ' ' .. def.hud.tab) or def.name
    fitted(label, 478, 648 + row * 16, 12, 114, tint)
  end
  if run.glyph ~= 'none' then
    centered(run.glyph == 'choke' and 'FOCUS' or 'PIERCE', 478, 681, 12, C.gold)
  end
  Skin.endZone()
  Portrait.draw(g, 565, 584, 150)
  Skin.zone('HUD armor', 752, 628, 118, 68)
  centered('WARD', 810, 630, 14, C.muted)
  number(math.ceil(p.armor) .. '%', 810, 648, 114, 29, p.armor > 0 and C.blue or C.muted)
  Skin.meter(753, 686, 114, p.armor / 100, C.blue, 12)
  Skin.endZone()
  Skin.zone('HUD abilities', 908, 628, 113, 68)
  -- The ability on Q (the first of the loadout): its uses of its capacity.
  local ability, power = Abilities.slot(g, 1)
  local uses, capacity = power and power.uses or 0, ability and ability.capacity or 1
  text('Q ' .. (ability and ability.tag or ''), 912, 630, 12, C.gold)
  text(
    uses > 0 and (uses .. ' / ' .. capacity) or 'NONE',
    912,
    649,
    14,
    uses > 0 and C.ivory or C.red
  )
  Skin.meter(912, 667, 104, uses / capacity, C.gold, capacity)
  text('SHIFT', 912, 678, 12, C.muted)
  for i = 1, 2 do
    Skin.meter(974 + (i - 1) * 24, 683, 20, p.dash - i + 1, C.ivory, 4)
  end
  Skin.endZone()
  Skin.zone('HUD souls', 1055, 628, 100, 76)
  fitted('SOULS', 1105, 630, 14, 98, C.gold)
  local showEcho = run.echo
  number(tostring(run.wallet), 1105, 648, 98, showEcho and 22 or 25, C.gold)
  if showEcho then
    -- Seven-digit legal saves still keep their exact value. A separate short
    -- caption and proportional numeral line fit the fresco niche without
    -- shrinking an entire phrase below the smallest readable PNG font.
    centered('ECHO', 1105, 672, 11, C.blue)
    number(tostring(run.echo.amount), 1105, 688, 98, 13, C.blue)
  else
    fitted(run.progress, 1105, 680, 14, 98, C.muted)
  end
  Skin.endZone()
end
function H.draw(g, settings, ui, descentUI)
  U = ui
  local p = g.player
  local run = Modes.act(g, 'hud')
  local cx, cy = U.aimX or L.aimX, U.aimY or L.aimY
  descentUI.heading(g)
  Skin.panel(1028, 12, 236, 68, 7, 10)
  Skin.zone('utility caption field', 1038, 22, 216, 48)
  local utility = 'TAB MAP / F1 HELP'
  local utilitySize = 14
  if Skin.inkBounds(U.fonts[utilitySize], utility).w > 210 then
    utilitySize = 12
  end
  Skin.boxText(utility, 1041, 23, 210, 20, U.fonts[utilitySize], C.muted, true)
  local clock = string.format('%02d:%02d', math.floor(g.elapsed / 60), math.floor(g.elapsed % 60))
  local clockInk = Skin.inkBounds(U.fonts[18], clock)
  text(clock, 1250 - clockInk.w - clockInk.x, 48, 18, C.gold)
  Skin.endZone()
  local gap = 5 + math.min(6, g.view.recoil * 5)
  local hit = g.view.hitmarker > 0
  local reticle = hit
      and (g.view.lastKill and C.gold or (g.view.armorHit and C.blue or ((g.view.hitWeight or 0) < 0.25 and C.muted or C.red)))
    or C.ivory
  for _, v in ipairs({ { -gap - 6, 0, -gap, 0 }, { gap, 0, gap + 6, 0 }, { 0, -gap - 6, 0, -gap } }) do
    line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], Palette.ink, 4)
    line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], reticle, 2)
  end
  color(Palette.ink)
  lg.rectangle('fill', cx - 3, cy - 3, 6, 6)
  color(reticle)
  lg.rectangle('fill', cx - 1, cy - 1, 2, 2)
  if hit then
    local reach = g.view.lastKill and 15 or (8 + math.floor((g.view.hitWeight or 0) * 4))
    for _, v in ipairs({ { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
      line(
        cx + v[1] * 6,
        cy + v[2] * 6,
        cx + v[1] * reach,
        cy + v[2] * reach,
        reticle,
        g.view.lastKill and 3 or 2
      )
    end
    if g.view.armorHit and not g.view.lastKill then
      Skin.icon('armor', cx + 19, cy - 10, 18)
    end
    if (g.view.breakConfirm or 0) > 0 then
      -- Guard broken: four gold brackets snap outward around the marker.
      local r = 17 + (1 - g.view.breakConfirm / 0.22) * 7
      for _, v in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local x, y = cx + v[1] * r, cy + v[2] * r
        line(x, y, x - v[1] * 6, y, Palette.ink, 4)
        line(x, y, x, y - v[2] * 6, Palette.ink, 4)
        line(x, y, x - v[1] * 6, y, C.gold, 2)
        line(x, y, x, y - v[2] * 6, C.gold, 2)
      end
    end
    if g.view.precisionHit then
      -- A small closed diamond distinguishes precision without covering the target.
      for _, v in ipairs({
        { -4, -21, 0, -25 },
        { 0, -25, 4, -21 },
        { 4, -21, 0, -17 },
        {
          0,
          -17,
          -4,
          -21,
        },
      }) do
        line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], Palette.ink, 4)
        line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], C.gold, 2)
      end
    end
  end
  if Weapons.inHand(g).fire.pellets > 1 then
    local cone = 640
      * math.tan(T.pelletSpread * require('src.content.weapons').spread(g))
      / math.tan(
        math.rad((g.view.fov or T.baseFov) + (g.view.motion ~= false and g.view.fovKick or 0)) / 2
      )
    for _, side in ipairs({ -1, 1 }) do
      line(cx + side * cone, cy - 3, cx + side * cone, cy + 3, Palette.inkSoft, 3)
      line(cx + side * cone, cy - 3, cx + side * cone, cy + 3, C.muted, 1)
    end
  end
  -- Incoming blows and near misses: arcs pointing at the source, sized by
  -- the blow's impact and damage, coloured by damage type (src/feedback/weight.lua).
  Weight.drawMarks(g, cx, cy, 92)
  if g.bossSpawned and not g.bossDead then
    for _, e in ipairs(g.enemies) do
      local banner = require('src.content.enemies').look(e).banner
      if banner and e.hp > 0 then
        local exposed = Rules.has(e, 'exposed')
        local name = exposed and banner.exposed
          or (e.hp < e.maxHp * 0.5 and banner.fury or banner.calm)
        Skin.panel(426, 16, 428, 64, 2, 10)
        Skin.zone('boss field', 438, 27, 402, 43)
        Skin.icon('skull', 440, 28, 36)
        Skin.boxText(name, 483, 28, 345, 26, U.fonts[20], exposed and C.gold or C.ivory, true)
        Skin.meter(483, 62, 345, e.hp / e.maxHp, C.red, 32)
        H.guardStrip(g, e, 483, 71, 345)
        Skin.endZone()
      end
    end
  elseif run.fighting then
    local target = B.trace(g, p.yaw, p.pitch, 25)
    if target and target.hp > 0 then
      local shield = (target.armorRating or 0) > 0
      Skin.panel(503, 20, 274, 60, 2, 10)
      Skin.zone('target field', 514, 30, 252, 40)
      local name = target.displayName or 'Demon'
      local width = shield and 208 or 240
      local size = 16
      while size > 12 and Skin.inkBounds(U.fonts[size], name).w > width do
        size = size - 2
      end
      Skin.boxText(name, shield and 552 or 520, 31, width, 22, U.fonts[size], C.ivory)
      if shield then
        Skin.icon('armor', 515, 32, 22)
      end
      Skin.meter(520, 62, 240, target.hp / target.maxHp, C.red, 24)
      H.guardStrip(g, target, 520, 71, 240)
      Skin.endZone()
    end
  end
  H.status(g, run)
  local mag, reserve = Weapons.ammo(g)
  -- The action is captioned in AMMO. A central reload placard covered the
  -- actual breech, cylinder and hands exactly when their animation mattered.
  local def = Weapons.inHand(g)
  if g.reload <= 0 and (mag == 0 or mag < def.fire.rounds) then
    local empty = mag + reserve == 0
    local other = Weapons.nextSlot(g)
    local otherMag, otherReserve = Weapons.ammo(g, other)
    local notice = empty
        and ((otherMag + otherReserve > 0) and ('NO AMMO / [' .. other .. ']') or 'NO AMMO')
      or (mag == 0 and '[R] RELOAD' or def.hud.partial)
    Skin.zone('ammunition notice', 515, 540, 250, 32)
    Skin.panel(502, 530, 276, 52, 2, 10)
    Skin.boxText(notice, 516, 542, 248, 28, U.fonts[16], empty and C.red or C.ivory, true)
    Skin.endZone()
  end
  if g.view.feedbackTimer > 0 then
    notice(g.view.feedback, 486, 16, C.gold)
  end
  if g.comboTimer > 0 and g.combo > 1 then
    notice('CHAIN x' .. g.combo, 438, 16, C.ivory)
  end
  local ctx = g:context()
  if ctx then
    local size = 16
    while size > 12 and Skin.inkBounds(U.fonts[size], ctx).w > 430 do
      size = size - 2
    end
    Skin.panel(18, 535, 460, 48, 2, 9)
    Skin.zone('interaction field', 32, 545, 432, 28)
    Skin.boxText(ctx, 33, 546, 430, 26, U.fonts[size], C.gold, true)
    Skin.endZone()
  end
  if g.view.messageTimer > 0 then
    local width = math.min(1180, U.fonts[16]:getWidth(g.view.message) + 40)
    Skin.panel(640 - width / 2, 91, width, 46, 2, 10)
    Skin.zone('message field', 652 - width / 2, 101, width - 24, 26)
    Skin.boxText(g.view.message, 652 - width / 2, 102, width - 24, 24, U.fonts[16], C.ivory, true)
    Skin.endZone()
  end
  if settings.hints ~= false then
    local hint = g.elapsed < 8 and 'WASD move / SHIFT dodge / CTRL slide / SPACE jump' or nil
    if p.hp < 30 then
      hint = 'Find medkits. The Ember lets you rest between waves.'
    end
    if hint then
      local width = math.min(1040, Skin.inkBounds(U.fonts[16], hint).w + 32)
      local left = 640 - width / 2
      Skin.panel(left, 139, width, 46, 2, 10)
      Skin.zone('movement hint', left + 12, 149, width - 24, 26)
      Skin.boxText(hint, left + 16, 150, width - 32, 24, U.fonts[16], C.ivory, true)
      Skin.endZone()
    end
  end
end
return H

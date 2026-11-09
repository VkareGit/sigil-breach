local Sigils = require('src.combat.sigils')
local Archetypes = require('src.content.enemies')
local Shop = require('src.content.shop')
local Reliquary = require('src.ui.reliquary')
local Characters = require('src.content.characters')
local Context = require('src.session.context')
local H = {}
local lg = love.graphics
local Skin = require('src.ui.skin')
local Tuning = require('src.content.tuning')
local Reload = require('src.combat.reload')
local Ballistics = require('src.combat.ballistics')
local Attributes = require('src.combat.attributes')
local Chain = require('src.combat.chain')
local Honours = require('src.content.chain')
local Layout = require('src.ui.layout')
local Portrait = require('src.ui.portrait')
local PaintedNumbers = require('src.ui.fonts.painted_numbers')
local Weapons = require('src.content.weapons')
local Loadout = require('src.combat.loadout')
local Slots = require('src.ui.hud_slots')
local Weight = require('src.feedback.weight')
local Lessons = require('src.feedback.lessons')
local Rules = require('src.combat.rules')
local CombatResources = require('src.combat.resources')
local Palette = require('src.ui.palette')
local HudLook = require('src.content.hud_look')
local K = HudLook
-- The gun not in hand (0.43, D04): the same ink, faded, so the one in hand reads first.
local quietInk = { Palette.muted[1], Palette.muted[2], Palette.muted[3], 0.55 } -- constant: faded ink, the owner's
local Timing = require('src.content.tuning').shot
local Clocks = require('src.content.tuning').clocks
local Modes = require('src.session.modes')
local Queries = require('src.session.queries')
local Text = require('src.content.text')
local TextFit = require('src.ui.text_fit')
local Pools = require('src.session.world')
local C = Skin.colors
local U
-- Both HUD layouts show the same resolved cone the actor actually fires.
function H.spreadRadius(g)
  return Layout.width
    / 2
    * math.tan(Tuning.pelletSpread * Loadout.spread(g, Context.actor(g)))
    / math.tan(
      math.rad((g.view.fov or Tuning.baseFov) + (g.view.motion ~= false and g.view.fovKick or 0))
        / 2
    )
end
-- Guard (poise) under a health bar: gold fills as blows accumulate toward
-- the break; after a break the strip is grey and shrinks with the lock; a
-- boss's exposed window pulses pale gold. The rule made readable.
function H.guardStrip(g, e, x, y, w)
  local guard = Rules.guardThreshold(e)
  local lock = e.staggerLock or 0
  local G = K.guard
  lg.setColor(G.ground)
  lg.rectangle('fill', x - 1, y - 1, w + 2, G.frame)
  if Rules.has(e, 'exposed') then
    local pulse = G.pulse.base + G.pulse.swing * math.abs(math.sin((g.time or 0) * G.pulse.rate))
    lg.setColor(G.exposed[1], G.exposed[2], G.exposed[3], pulse)
    lg.rectangle('fill', x, y, w, G.height)
  elseif lock > 0 then
    local full = Rules.lockTime(e)
    lg.setColor(G.lock)
    lg.rectangle('fill', x, y, math.floor(w * math.min(1, lock / full)), G.height)
  else
    local fill = math.min(1, (e.poise or 0) / guard)
    if fill > 0 then
      lg.setColor(G.fill)
      lg.rectangle('fill', x, y, math.max(1, math.floor(w * fill)), G.height)
    end
  end
  lg.setColor(1, 1, 1)
end
local function color(c, a)
  lg.setColor(c[1], c[2], c[3], a or 1)
end
local function text(t, x, y, size, c)
  Skin.text(t, x, y, U.fonts[size or K.font], c or C.ivory)
end
local function centered(t, cx, y, size, c)
  text(t, cx - U.fonts[size]:getWidth(t) / 2, y, size, c)
end
local function center(t, y, size, c)
  centered(t, Layout.width / 2, y, size, c)
end
local function number(t, cx, y, w, h, c)
  -- Counters use whole painted digits even if a future rule supplies a fraction.
  if type(t) == 'number' then
    t = string.format('%.0f', math.max(0, math.floor(t + 0.5)))
  end
  local x, top, width, height = PaintedNumbers.draw(t, cx, y, w, h, c)
  Skin.imageBounds('painted number ' .. t, x, top, width, height)
end
local function fitted(t, cx, y, size, w, c)
  if U.fonts[size]:getWidth(t) <= w then
    return centered(t, cx, y, size, c)
  end
  for _, s in ipairs(K.fitted) do
    if s <= size and U.fonts[s]:getWidth(t) <= w then
      return centered(t, cx, y, s, c)
    end
  end
  centered(TextFit.ellipsis(U.fonts[K.smallest], t, w), cx, y, K.smallest, c)
end
local function line(x1, y1, x2, y2, c, w)
  color(c)
  lg.setLineWidth(w or K.line)
  lg.line(x1, y1, x2, y2)
end
local function notice(label, y, size, tint)
  local N = K.notice
  local width = math.min(N.widest, Skin.inkBounds(U.fonts[size], label).w + N.pad)
  Skin.panel(N.x, y, width, N.h, 7, N.corner)
  Skin.zone('combat notice ' .. label, N.zone.x, y + N.inset, width - N.zone.pad, N.zone.h)
  Skin.boxText(label, N.text.x, y + N.text.y, width - N.text.pad, N.text.h, U.fonts[size], tint)
  Skin.endZone()
end
-- The status bar. What it shows of the mode (purse, glyph, echo, progress)
-- is the mode's report (run/modes.lua: hud), never its record read here.
-- A painted seal: what a deed or a chain looks like (assets/art/medals, by Codex).
local seals = {}
local function seal(id, x, y, size, alpha)
  seals[id] = seals[id] or lg.newImage('assets/art/medals/' .. id .. '.png', { mipmaps = true })
  local image = seals[id]
  Skin.imageBounds('seal ' .. id, x, y, size, size)
  lg.setColor(1, 1, 1, alpha)
  lg.draw(image, x, y, 0, size / image:getWidth())
  lg.setColor(1, 1, 1)
end
function H.status(g, run)
  run = run or Modes.act(g, 'hud')
  local p = Context.actor(g)
  Reliquary.status()
  local function zone(name, z)
    Skin.zone(name, z[1], z[2], z[3], z[4])
  end
  local cap = K.caption
  Skin.lightField(K.bar[1], K.bar[2], K.bar[3], K.bar[4])
  local A = K.ammo
  zone('HUD ammunition', A.zone)
  local mag, reserve = Weapons.meter(g, nil, Context.actor(g))
  fitted(Text.get('ammo'), A.cx, cap.y, cap.font, A.width, C.muted)
  number(mag, A.cx, A.number[1], A.number[2], A.number[3], mag == 0 and C.red or C.ivory)
  local ammoCaption = Reload.left(g, Context.actor(g)) > 0 and Reload.label(g, Context.actor(g))
    or Text.get('reserve', { count = reserve })
  fitted(
    ammoCaption,
    A.cx,
    A.below,
    cap.font,
    A.width,
    Reload.left(g, Context.actor(g)) > 0 and C.gold or (reserve == 0 and C.red or C.muted)
  )
  Skin.endZone()
  local Hh = K.health
  zone('HUD health', Hh.zone)
  -- Low health is said by the whole niche: its caption turns red with its number.
  local low = Characters.low(p)
  centered(Text.get('health'), Hh.cx, cap.y, cap.font, low and C.red or C.muted)
  number(
    Characters.percent(Characters.share(p)) .. '%',
    Hh.cx,
    Hh.number[1],
    Hh.number[2],
    Hh.number[3],
    low and C.red or Palette.wound
  )
  Skin.meter(Hh.meter[1], Hh.meter[2], Hh.meter[3], Characters.share(p), C.red, Hh.meter.marks)
  Skin.endZone()
  local Ar = K.arsenal
  zone('HUD arsenal', Ar.zone)
  -- A chain is the weapon's: it stands in the niche of the weapons, as long as it lives, quiet:
  -- its seal and its count (the medal at the top of the view named it), and a small seal on
  -- the row of the weapon that made it, the one its edge is on.
  local chain = Chain.step(p)
  if chain then
    local count = Text.get('hud_chain_count', { count = p.chainCount })
    local ink = Skin.inkBounds(U.fonts[cap.font], count)
    local left = Ar.cx - (Ar.chainSeal + Ar.chainGap + ink.w) / 2
    seal(chain.id, left, Ar.chainTop, Ar.chainSeal, 1)
    text(count, left + (Ar.chainSeal + Ar.chainGap) - ink.x, Ar.chainCount, cap.font, C.gold)
  else
    centered(Text.get('arsenal'), Ar.cx, cap.y, cap.font, C.muted)
  end
  -- Two painted rows: scroll around the selected slot instead of silently
  -- dropping any third weapon or overflowing the fresco's lower ornament.
  local shown, count = Slots.weapons(g, 2)
  for row, weapon in ipairs(shown) do
    -- 0.43 (D04): on the parchment muted prints the darkest ink and gold a brown, so the gun
    -- not in hand used to read first; the gun in hand takes the dark ink, the other a grey.
    local tint = weapon.selected and C.muted or quietInk
    local label = count > 2
        and (Text.get('weapon_slot', { slot = weapon.slot, name = Text.get(weapon.def.hud.tab) }))
      or Text.get(weapon.def.name)
    local y = Ar.row.y + (row - 1) * Ar.row.step
    -- 0.43 (D04): the gun in hand reads first, a size larger; the other stays quiet.
    local size = weapon.selected and Ar.held or Ar.quiet
    local S = Ar.rowSeal
    if chain and p.chainWeapon == weapon.def.id then
      seal(chain.id, S.x, y + 1, S.size, 1)
      fitted(label, S.cx, y - (size - Ar.quiet) / 2, size, S.width, tint)
    else
      fitted(label, Ar.cx, y - (size - Ar.quiet) / 2, size, Ar.width, tint)
    end
  end
  -- The engraving on the gun in hand, where each gun wears its own; else the run's one.
  local engraving = run.glyph ~= 'none' and run.glyph or nil
  if run.worn then
    local held
    for _, weapon in ipairs(shown) do
      held = weapon.selected and weapon.def.id or held
    end
    engraving = held and run.worn[held]
  end
  if chain then
    local M = Ar.meter
    Skin.meter(M[1], M[2], M[3], p.chainLeft / Honours.window, C.gold, M.marks)
  elseif engraving then
    local label = Text.get(assert(Shop.get(engraving).short, 'missing engraving HUD label'))
    fitted(label, Ar.cx, Ar.engraving.y, Ar.engraving.font, Ar.width, C.gold)
  end
  Skin.endZone()
  Portrait.draw(g, K.portraitAt[1], K.portraitAt[2], K.portraitAt.size)
  local W = K.ward
  zone('HUD armor', W.zone)
  centered(Text.get('ward'), W.cx, cap.y, cap.font, C.muted)
  local ward = Characters.wardShare(p)
  local wn = W.number
  number(
    Characters.percent(ward) .. '%',
    W.cx,
    wn[1],
    wn[2],
    wn[3],
    p.armor > 0 and C.blue or C.muted
  )
  Skin.meter(W.meter[1], W.meter[2], W.meter[3], ward, C.blue, W.meter.marks)
  Skin.endZone()
  local Ab = K.abilities
  zone('HUD abilities', Ab.zone)
  -- The equipment of every keyed slot (ui/hud_slots.lua). One item: its key
  -- and tag, its uses of its capacity and their meter; more: one row each.
  local kit = Slots.equipment(g)
  if #kit == 1 then
    local item = kit[1]
    local uses, capacity = item.uses, item.capacity
    text(
      Text.get('ability_key', { key = item.key, tag = item.def and Text.get(item.def.tag) or '' }),
      Ab.x,
      Ab.key.y,
      Ab.key.font,
      C.gold
    )
    text(
      uses > 0 and Text.get('uses', { uses = uses, capacity = capacity }) or Text.get('none'),
      Ab.x,
      Ab.uses.y,
      Ab.uses.font,
      uses > 0 and C.ivory or C.red
    )
    Skin.meter(Ab.meter[1], Ab.meter[2], Ab.meter[3], uses / capacity, C.gold, capacity)
  else
    -- One row each, clear of the niche's edge: an item with a painted mark (assets/art/icons)
    -- shows the mark, its key and its uses large at the right, red at none; one without keeps
    -- its key and tag in small letters. Two rows have room to read large; more keep the old
    -- small rows. The meter is a single item's.
    local roomy = #kit <= 2
    local rows = roomy and Ab.roomy or Ab.tight
    local size, step = rows.font, rows.step
    for row, item in ipairs(kit) do
      local y = Ab.key.y + (row - 1) * step
      local count = Text.get('uses_left', { uses = item.uses })
      local ink = Skin.inkBounds(U.fonts[size], count)
      text(
        count,
        Ab.right - ink.w - ink.x,
        y - (roomy and 1 or 0),
        size,
        item.uses > 0 and C.ivory or C.red
      )
      local marked = roomy and Skin.hasIcon(item.def.id)
      local left, label = Ab.x, nil
      if marked then
        Skin.icon(item.def.id, Ab.x, y - 1, Ab.mark.size)
        left, label = Ab.mark.after, Text.get('ability_key_alone', { key = item.key })
      else
        label = Text.get('ability_key', { key = item.key, tag = Text.get(item.def.tag) })
      end
      local width = Ab.labelRight - ink.w - left
      local small = Ab.small
      local font = marked and Ab.labelFont
        or (Skin.inkBounds(U.fonts[small], label).w <= width and small or K.smallest)
      local fit = TextFit.ellipsis(U.fonts[font], label, width)
      text(fit, left - Skin.inkBounds(U.fonts[font], fit).x, y, font, C.gold)
    end
  end
  Skin.endZone()
  local So = K.souls
  zone('HUD souls', So.zone)
  fitted(Text.get('souls'), So.cx, cap.y, cap.font, So.width, C.gold)
  local showEcho = run.echo
  number(run.wallet, So.cx, So.number, So.width, showEcho and So.heightEcho or So.height, C.gold)
  if showEcho then
    -- Seven-digit legal saves still keep their exact value. A separate short
    -- caption and proportional numeral line fit the fresco niche without
    -- shrinking an entire phrase below the smallest readable PNG font.
    local E = So.echo
    centered(Text.get('echo'), So.cx, E.y, E.font, C.blue)
    number(run.echo.amount, So.cx, E.number, So.width, E.height, C.blue)
  else
    -- What a kill just paid stands in the niche for a moment, in place of the count of deaths.
    local gained = (g.view.soulsGainTimer or 0) > 0
      and Text.get('hud_souls_gain', { amount = g.view.soulsGain })
    fitted(
      gained or run.progress,
      So.cx,
      So.below,
      cap.font,
      So.width,
      gained and C.gold or C.muted
    )
  end
  Skin.endZone()
end
-- Effort, over the fresco, only while it is being spent.
-- The bar, and the mark a dodge needs: below it the knight cannot get away.
function H.stamina(p)
  local share = CombatResources.share(p, 'stamina')
  if share and share < 1 then
    local price = Sigils.dodgeCost(p, Rules.playerBody(p).rollStamina)
      / Characters.of(p).resources.stamina.max
    local S = K.stamina
    Skin.zone('HUD stamina', S.zone[1], S.zone[2], S.zone[3], S.zone[4])
    Skin.meter(S.x, S.y, S.w, share, share >= price and C.gold or C.red, S.marks)
    color(C.ivory)
    lg.rectangle('fill', S.x + S.w * price, S.mark.y, S.mark.w, S.mark.h)
    Skin.endZone()
  end
end
-- What a blow took and can still be fought back, on the health meter.
function H.rally(p)
  if (p.rally or 0) > 0 then
    local R = K.rally
    local x = R.x + R.w * Characters.share(p)
    lg.setColor(C.gold)
    lg.rectangle('fill', x, R.y, math.min(R.right - x, R.w * p.rally / Characters.maxHp(p)), R.h)
    lg.setColor(1, 1, 1)
  end
end
-- The keys and the clock (0.45, owner D18): for the first minutes and whenever the game stands;
-- in play nothing rests over the scene.
local function utilityPanel(g)
  if g.state == 'playing' and not g.map and g.elapsed >= Clocks.helpFor then
    return
  end
  local Ut = K.utility
  local P, Z, T, Ck = Ut.plate, Ut.zone, Ut.text, Ut.clock
  Skin.panel(P[1], P[2], P[3], P[4], 7, P.corner)
  Skin.zone('utility caption field', Z[1], Z[2], Z[3], Z[4])
  local utility = Text.get('hud_utility')
  local utilitySize = T.font
  if Skin.inkBounds(U.fonts[utilitySize], utility).w > T[3] then
    utilitySize = T.small
  end
  Skin.boxText(utility, T[1], T[2], T[3], T[4], U.fonts[utilitySize], C.muted, true)
  local minutes, seconds = math.floor(g.elapsed / 60), math.floor(g.elapsed % 60) -- constant: a minute
  local clock = string.format('%02d:%02d', minutes, seconds)
  local clockInk = Skin.inkBounds(U.fonts[Ck.font], clock)
  text(clock, Ck.right - clockInk.w - clockInk.x, Ck.y, Ck.font, C.gold)
  Skin.endZone()
end
-- What a hit looks like at the reticle.
local function hitMarks(g, cx, cy, mark)
  -- Four short thin strokes off the centre, as the hit markers of shooters do: they say "hit"
  -- and get out of the way, fading over their last moment (owner: the old heavy X shouted).
  -- A kill is the same mark in red, a little longer, with a small jump.
  local kill = g.view.lastKill
  local reach = kill
      and Layout.killReach * (1 + Layout.killPop * (g.view.killPop or 0) / Timing.killPop)
    or (Layout.hitReach + math.floor((g.view.hitWeight or 0) * K.hit.weight))
  local fade = math.min(1, g.view.hitmarker / Layout.markFade)
  for _, v in ipairs({ { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
    local x1, y1 = cx + v[1] * Layout.markGap, cy + v[2] * Layout.markGap
    local x2, y2 = cx + v[1] * reach, cy + v[2] * reach
    color(Palette.inkSoft, K.hit.outline * fade)
    lg.setLineWidth(Layout.markWidth + 1)
    lg.line(x1, y1, x2, y2)
    color(mark, fade)
    lg.setLineWidth(Layout.markWidth)
    lg.line(x1, y1, x2, y2)
  end
  if g.view.armorHit and not g.view.lastKill then
    local A = K.hit.armor
    Skin.icon('armor', cx + A.x, cy + A.y, A.size)
  end
  if g.view.precisionHit then
    -- A small closed diamond distinguishes precision without covering the target. White, like
    -- any hit: gold belongs to a broken guard alone.
    for _, v in ipairs(K.hit.diamond) do
      line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], Palette.ink, K.hit.ink)
      line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], C.ivory, K.line)
    end
  end
end
-- Guard broken: four gold brackets snap outward around the marker, for their own whole time
-- (0.43, V01: drawn inside the hit marks they were cut off with them, 5 frames of 7).
local function breakMarks(g, cx, cy)
  if (g.view.breakConfirm or 0) <= 0 then
    return
  end
  local B, ink = K.breaking, K.hit.ink
  local r = B.from + (1 - g.view.breakConfirm / B.time) * B.snap
  for _, v in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
    local x, y = cx + v[1] * r, cy + v[2] * r
    line(x, y, x - v[1] * B.arm, y, Palette.ink, ink)
    line(x, y, x, y - v[2] * B.arm, Palette.ink, ink)
    line(x, y, x - v[1] * B.arm, y, C.gold, K.line)
    line(x, y, x, y - v[2] * B.arm, C.gold, K.line)
  end
end
-- The hands cannot fire: the reticle opens and dims for as long as that lasts, so a pull that
-- does nothing is never a game that did not listen. What was refused is said under it.
local function aimMarks(g, cx, cy)
  local p = Context.actor(g)
  local locked = Attributes.forbids(p, 'fire')
  local Rt = K.reticle
  local gap = Rt.gap
    + math.min(Rt.most, g.view.recoil * Rt.recoil)
    + (locked and Layout.lockedGap or 0)
  local hit = g.view.hitmarker > 0
  -- One colour, one meaning, on the hit mark alone: white a hit, blue armour, gold a broken
  -- guard, red a kill. The cross itself stays ivory, dimmed while the hands cannot fire.
  local reticle = locked and C.muted or C.ivory
  local mark = g.view.lastKill and Palette.kill or (g.view.armorHit and C.blue or C.ivory)
  local drinking = p.conditions and (p.conditions.drinking or 0) > 0
  -- The hands show a drink themselves (0.45, owner D18); it is said only to a refused pull.
  local says = locked and not drinking and 'hud_off_balance'
    or (g.view.refusalTimer or 0) > 0 and g.view.refusal
  if says then
    -- Ivory with its ink, never red: red at the reticle belongs to a kill alone.
    centered(Text.get(says), cx, cy + Layout.refusalBelow, Rt.refusalFont, C.ivory)
  end
  local arm, ink = Rt.arm, K.hit.ink
  for _, v in ipairs({
    { -gap - arm, 0, -gap, 0 },
    { gap, 0, gap + arm, 0 },
    { 0, -gap - arm, 0, -gap },
  }) do
    line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], Palette.ink, ink)
    line(cx + v[1], cy + v[2], cx + v[3], cy + v[4], reticle, K.line)
  end
  color(Palette.ink)
  lg.rectangle('fill', cx - Rt.dot, cy - Rt.dot, 2 * Rt.dot, 2 * Rt.dot)
  color(reticle)
  lg.rectangle('fill', cx - Rt.core, cy - Rt.core, 2 * Rt.core, 2 * Rt.core)
  if hit then
    hitMarks(g, cx, cy, mark)
  end
  breakMarks(g, cx, cy)
  if Weapons.inHand(g, nil, Context.actor(g)).fire.pellets > 1 then
    local cone = H.spreadRadius(g)
    for _, side in ipairs({ -1, 1 }) do
      local half = K.cone.half
      line(cx + side * cone, cy - half, cx + side * cone, cy + half, Palette.inkSoft, K.cone.ink)
      line(cx + side * cone, cy - half, cx + side * cone, cy + half, C.muted, 1)
    end
  end
end

-- The name and health of what the knight fights or looks at.
local function foePanel(g, p)
  local world = Queries.world(g)
  if world.guardianSpawned and not world.guardianDead then
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      local banner = Archetypes.look(e).banner
      if banner and e.hp > 0 then
        local exposed = Rules.has(e, 'exposed')
        local name = Text.get(
          exposed and banner.exposed or (Archetypes.furious(e) and banner.fury or banner.calm)
        )
        local B = K.boss
        local P, Z, N, M = B.plate, B.zone, B.name, B.meter
        Skin.panel(P[1], P[2], P[3], P[4], 2, P.corner)
        Skin.zone('boss field', Z[1], Z[2], Z[3], Z[4])
        Skin.icon('skull', B.skull[1], B.skull[2], B.skull.size)
        Skin.boxText(
          name,
          N[1],
          N[2],
          N[3],
          N[4],
          U.fonts[N.font],
          exposed and C.gold or C.ivory,
          true
        )
        Skin.meter(M[1], M[2], M[3], e.hp / e.maxHp, C.red, M.marks)
        H.guardStrip(g, e, M[1], B.guard, M[3])
        Skin.endZone()
      end
    end
  else
    local dx, dy, dz = Ballistics.direction(p.yaw, p.pitch)
    local target = Ballistics.traceVector(
      g,
      dx,
      dy,
      dz,
      K.sights,
      Ballistics.prepare(g, p, {}),
      { Ballistics.origin(g, p) }
    )
    -- An ordinary body's bar comes with a hit and goes foeBar s after the last one (0.45, owner
    -- D18); one with a banner stands in the sights as before.
    local struck = g.view.damageTrail
    struck = struck
      and target
      and struck.id == target.id
      and struck.hold + Clocks.foeBar > Clocks.trailHold
    if target and target.hp > 0 and (struck or Archetypes.look(target).banner) then
      local shield = (target.armorRating or 0) > 0
      local T = K.target
      local P, Z, N, M = T.plate, T.zone, T.name, T.meter
      Skin.panel(P[1], P[2], P[3], P[4], 2, P.corner)
      Skin.zone('target field', Z[1], Z[2], Z[3], Z[4])
      local name = target.displayName and Text.show(target.displayName) or Text.get('hud_demon')
      local width = shield and T.width.shield or T.width.plain
      local size = N.font
      while size > N.smallest and Skin.inkBounds(U.fonts[size], name).w > width do
        size = size - 2
      end
      Skin.boxText(name, shield and N.shield or N.plain, N.y, width, N.h, U.fonts[size], C.ivory)
      if shield then
        Skin.icon('armor', T.shield[1], T.shield[2], T.shield.size)
      end
      Skin.meter(M[1], M[2], M[3], target.hp / target.maxHp, C.red, M.marks)
      -- What this body just lost, as this view keeps it (feedback/listeners, systems/clocks): a
      -- pale trail on its bar, where the eye already is.
      local trail = g.view.damageTrail
      trail = trail and trail.id == target.id and trail
      if trail and trail.shown > target.hp then
        local from = M[1] + M[3] * target.hp / target.maxHp
        color(C.ivory, T.trail.alpha)
        lg.rectangle('fill', from, M[2], M[3] * (trail.shown - target.hp) / target.maxHp, T.trail.h)
      end
      H.guardStrip(g, target, M[1], T.guard, M[3])
      Skin.endZone()
    end
  end
end
local function ammoNotice(g)
  local mag, reserve = Weapons.meter(g, nil, Context.actor(g))
  -- The action is captioned in AMMO. A central reload placard covered the
  -- actual breech, cylinder and hands exactly when their animation mattered.
  local def = Weapons.inHand(g, nil, Context.actor(g))
  if Reload.left(g, Context.actor(g)) <= 0 and (mag == 0 or mag < def.fire.rounds) then
    local empty = mag + reserve == 0
    local other = Weapons.nextSlot(g, Context.actor(g))
    local otherMag, otherReserve = Weapons.meter(g, other, Context.actor(g))
    local notice = empty
        and ((otherMag + otherReserve > 0) and Text.get('hud_no_ammo_switch', { slot = other }) or Text.get(
          'hud_no_ammo'
        ))
      or Text.get(mag == 0 and 'hud_reload' or def.hud.partial)
    -- Use the frame's full interior; the partial-load caption has 252 px of painted ink.
    local A = K.ammoNotice
    local Z, P, T = A.zone, A.plate, A.text
    Skin.zone('ammunition notice', Z[1], Z[2], Z[3], Z[4])
    Skin.panel(P[1], P[2], P[3], P[4], 2, P.corner)
    Skin.boxText(notice, T[1], T[2], T[3], T[4], U.fonts[T.font], empty and C.red or C.ivory, true)
    Skin.endZone()
  end
end
local function medalOf(id)
  if Honours.medals[id] then
    return Honours.medals[id]
  end
  for _, step in ipairs(Honours.steps) do
    if step.id == id then
      return step
    end
  end
end
-- A deed or a new step of a chain: at the top of the view, large, for a moment, and it fades. What
-- stays while a chain lives is quiet, in the niches of the bar (H.status).
local function honours(g, cx)
  local left = g.view.medalTimer or 0
  if left <= 0 then
    return
  end
  local medal = medalOf(g.view.medal)
  seal(
    g.view.medal,
    cx - Layout.medalSeal / 2,
    Layout.medalTop,
    Layout.medalSeal,
    math.min(1, left / Layout.medalFade)
  )
  local N = K.medalName
  centered(Text.get(medal.name), cx, Layout.medalTop + Layout.medalSeal + N.gap, N.font, C.gold)
end
local function prompt(g)
  local ctx = g:context()
  if ctx then
    local Pr = K.prompt
    local size = Pr.font
    while size > Pr.smallest and Skin.inkBounds(U.fonts[size], ctx).w > Pr.wide do
      size = size - 2
    end
    -- Still too wide at the least size (a long fire's name): the place before the first ' / '
    -- gives way, the keys stay (0.43, audit F07: it ran past its frame).
    local rest = ctx:match('^.- / (.+)$')
    if rest and Skin.inkBounds(U.fonts[size], ctx).w > Pr.wide then
      ctx = rest
    end
    local P, Z, T = Pr.plate, Pr.zone, Pr.text
    Skin.panel(P[1], P[2], P[3], P[4], 2, P.corner)
    Skin.zone('interaction field', Z[1], Z[2], Z[3], Z[4])
    Skin.boxText(ctx, T[1], T[2], T[3], T[4], U.fonts[size], C.gold, true)
    Skin.endZone()
  end
end
-- One notice over the scene at a time: while a medal stands at the top, the message waits
-- under it rather than over it, and no hint is shown.
local function message(g, medal)
  if g.view.messageTimer > 0 then
    local Ms = K.message
    local top = medal and Layout.medalTop + Layout.medalSeal + Layout.medalBelow or Ms.top
    local width = math.min(Ms.widest, U.fonts[Ms.font]:getWidth(g.view.message) + Ms.pad)
    local mid = Layout.width / 2
    Skin.panel(mid - width / 2, top, width, Ms.h, 2, Ms.corner)
    Skin.zone(
      'message field',
      mid + Ms.inset - width / 2,
      top + Ms.zone.y,
      width - Ms.zone.pad,
      Ms.zone.h
    )
    Skin.boxText(
      g.view.message,
      mid + Ms.inset - width / 2,
      top + Ms.text.y,
      width - Ms.zone.pad,
      Ms.text.h,
      U.fonts[Ms.font],
      C.ivory,
      true
    )
    Skin.endZone()
  end
end
local function hints(g, p, settings)
  if settings.hints ~= false then
    local tools = Queries.tools(g)
    local Hn = K.hint
    local hint = g.elapsed < Hn.first
        and not (tools and tools.combatTrial)
        and Text.get('hud_hint_moves')
      or nil
    -- A lesson of something first seen (feedback/lessons.lua), once nothing hunts him.
    local lesson = Lessons.showing(g.view)
    hint = lesson and Text.get(lesson) or hint
    -- The flask is named only while it has a draught to give.
    local flask = p.abilityState and p.abilityState.flask
    if Characters.low(p) and flask and flask.uses > 0 then
      hint = Text.get('hud_hint_hurt')
    end
    if hint then
      local width = math.min(Hn.widest, Skin.inkBounds(U.fonts[Hn.font], hint).w + Hn.pad)
      local left = Layout.width / 2 - width / 2
      Skin.panel(left, Hn.y, width, Hn.h, 2, Hn.corner)
      Skin.zone('movement hint', left + Hn.zone.x, Hn.zone.y, width - Hn.zone.pad, Hn.zone.h)
      Skin.boxText(
        hint,
        left + Hn.text.x,
        Hn.text.y,
        width - Hn.pad,
        Hn.text.h,
        U.fonts[Hn.font],
        C.ivory,
        true
      )
      Skin.endZone()
    end
  end
end
function H.draw(g, settings, ui, descentUI)
  U = ui
  local p = Context.actor(g)
  local run = Modes.act(g, 'hud')
  local cx, cy = U.aimX or Layout.aimX, U.aimY or Layout.aimY
  descentUI.heading(g)
  utilityPanel(g)
  aimMarks(g, cx, cy)
  -- Incoming blows and near misses: arcs pointing at the source, sized by
  -- the blow's impact and damage, coloured by damage type (src/feedback/weight.lua).
  Weight.drawMarks(g, cx, cy, K.incoming)
  foePanel(g, p)
  H.status(g, run)
  H.stamina(p)
  H.rally(p)
  ammoNotice(g)
  if g.view.feedbackTimer > 0 then
    notice(g.view.feedback, K.noticeY, K.noticeFont, C.gold)
  end
  local medal = (g.view.medalTimer or 0) > 0
  honours(g, cx)
  prompt(g)
  message(g, medal)
  if not medal then
    hints(g, p, settings)
  end
end
return H

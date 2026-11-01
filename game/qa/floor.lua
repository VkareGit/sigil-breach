-- The plain room the test suite plays on: a session with no way through it, a few
-- creatures and supplies, and no rules of its own. Nothing in the game reaches it.
local Maps = require('src.content.maps.index')
local Modes = require('src.run.modes')
local Presentation = require('src.session.presentation')
local Spawn = require('src.session.spawn')
local Text = require('src.content.text')
local Tuning = require('src.content.tuning')
local Views = require('src.run.mode_views')
local F = {}
local installed = false
F.map = {
  id = 'floor',
  size = 31,
  floor = 0,
  decor = {},
  rooms = { { 9, 18, 23, 29 }, { 3, 10, 29, 23 }, { 8, 2, 24, 10 } },
  pillars = {
    { 12, 20 },
    { 20, 20 },
    { 12, 25 },
    { 20, 25 },
    { 12, 5 },
    { 20, 5 },
    { 5, 14 },
    { 5, 19 },
    { 27, 14 },
    { 27, 19 },
    { 9, 12 },
    { 23, 12 },
    { 12, 10 },
    { 20, 10 },
    { 12, 15 },
    { 20, 15 },
  },
  seals = {
    {
      x = 7,
      z = 17,
      id = 'asmoday',
      name = 'seal_asmoday',
      court = 'court_embers',
      color = { 1, 0.28, 0.07 },
    },
    {
      x = 25,
      z = 17,
      id = 'stolas',
      name = 'seal_stolas',
      court = 'court_stars',
      color = { 0.35, 0.65, 1 },
    },
    {
      x = 16,
      z = 5.5,
      id = 'buer',
      name = 'seal_buer',
      court = 'court_resin',
      color = { 0.38, 1, 0.57 },
    },
  },
  spawn = { x = 16, z = 27.5, yaw = math.pi },
  lamps = { { 13, 27 }, { 19, 27 }, { 13, 7 }, { 19, 7 } },
  lampHeight = 1.18,
  emberClear = 2,
  ember = { x = 18, z = 26 },
  gates = { { x = 7, z = 17 }, { x = 25, z = 17 }, { x = 16, z = 23 } },
  zones = { { name = 'zone_nave' } },
}
local report = {}
local function prepare(g)
  if g.world.mapId ~= 'floor' then
    return
  end
  for _, entry in ipairs({ { 'imp', 16, 22 }, { 'imp', 14, 16 }, { 'stolas', 18, 12 } }) do
    g:spawn(entry[1], entry[2], entry[3])
  end
  for _, supply in ipairs({
    { x = 13.5, z = 26, kind = 'ammo', amount = Tuning.ammoPickup },
    { x = 18.5, z = 26, kind = 'health', amount = Tuning.healthPickup },
  }) do
    Spawn.make(g, 'pickup', supply)
  end
end
-- Registers the room and its mode; the bare Game.new() of a test opens it.
function F.install()
  if installed then
    return
  end
  installed = true
  Maps:register('floor', F.map)
  Modes:register('floor', {
    session = { map = 'floor', prepare = prepare, requires = { 'ember' } },
    record = 'run',
    init = function(g)
      g.run = {
        phase = 'play',
        wallet = 100,
        glyph = 'none',
        owned = {},
        claimed = {},
        deaths = 0,
        pending = {},
        fire = 'narthex',
        lit = { narthex = true },
      }
    end,
    test = function()
      return true
    end,
    start = function(g)
      g.state = 'playing'
      Presentation.capture(g, true)
    end,
    progress = function() end,
    weaponModifier = function(g)
      return g.run and (g.run.glyphs or g.run.glyph)
    end,
    canTrade = function()
      return true
    end,
    closeShop = require('src.session.sanctuary').closeTrade,
    buy = function(g, offer)
      return require('src.run.economy').trade(g, offer)
    end,
    lose = function(g)
      g.state = 'dead'
    end,
    worldView = function(g, out)
      return g.world and Views.pilgrimWorld(g, g.run or {}, out) or out
    end,
    runView = function(g, out)
      return g.run and Views.run(g, g.run, out)
    end,
    hud = function(g)
      local r = g.run or {}
      report.glyph, report.wallet, report.echo = r.glyph or 'none', r.wallet or 0, r.echo
      report.progress = Text.get('pilgrim_progress', { deaths = r.deaths or 0 })
      return report
    end,
  })
  Modes.default = 'floor'
  Maps.default = 'floor'
  -- The proving ground opens here too unless a test names its map.
  local field = Modes:get('field').session
  field.map = 'floor'
  field.prepare = prepare
end
return F

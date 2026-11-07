-- The game's modes: the proving ground and the way (session/modes.lua says what a mode is).
local Catalog = require('src.run.field.catalog')
local Chambers = require('src.run.field.chambers')
local Pilgrimage = require('src.run.pilgrimage')
local Drops = require('src.run.drops')
local Field = require('src.run.test_field')
local WorldGallery = require('src.world.gallery')
local Economy = require('src.run.economy')
local Encounter = require('src.session.encounter')
local Modes = require('src.session.modes')
local Sanctuary = require('src.session.sanctuary')
local ModeViews = require('src.run.mode_views')
local Pools = require('src.session.world')
local Text = require('src.content.text')
-- The proving ground (skirmish and stations).
Modes:register('field', {
  prepared = true,
  session = { map = require('src.content.pilgrimage').start().map },
  record = 'testField',
  init = function(g, options)
    Field.init(g, options)
  end,
  construction = function(g)
    return Field.options(g)
  end,
  reset = function(g)
    return Field.reset(g)
  end,
  visit = function(g, previous)
    -- Text keys (content/text.lua).
    g.view.fieldReturnLabel = previous.state == 'menu' and 'return_menu'
      or (previous.state == 'settings' and 'return_settings' or 'return_chapel')
  end,
  worldView = function(g, out)
    return ModeViews.fieldWorld(g, g.run, out, g.testField)
  end,
  tools = function(g, out)
    return ModeViews.fieldTools(g, g.testField, out)
  end,
  objective = ModeViews.fieldObjective,
  runView = function(g, out)
    return ModeViews.run(g, g.run, out)
  end,
  fieldView = function(g, out)
    return ModeViews.field(g, g.testField, out)
  end,
  weaponModifier = function(g)
    return g.run.glyphs or g.run.glyph
  end,
  canTrade = function(g)
    return Field.allows(g, 'trade')
  end,
  policy = { freezable = true, invincible = true, attrition = true },
  attrition = function(g)
    return Field.attrition(g)
  end,
  creatures = function()
    local ids = {}
    for index, entry in ipairs(Catalog.enemies) do
      ids[index] = entry.id
    end
    return ids
  end,
  -- Its targets hold the catalogue pose they were given.
  posed = function()
    return true
  end,
  -- Ready, retry and the shop lead back to the field.
  start = function(g)
    return Field.close(g)
  end,
  progress = function(g, dt)
    Field.update(g, dt)
  end,
  ready = function(g)
    return Field.close(g)
  end,
  retry = function(g)
    return Field.retry(g)
  end,
  closeShop = function(g)
    return g.state == 'shop' and Field.close(g)
  end,
  -- Trial souls: a purchase that saves nothing.
  buy = function(g, offer)
    return Field.allows(g, 'trade') and Economy.trade(g, offer) or false
  end,
  catalog = function(g, id)
    return Field.action(g, id)
  end,
  lose = function(g)
    Chambers.failed(g)
    Encounter.clearThreats(g)
    return false
  end,
  remaining = function(g)
    local alive = 0
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      if e.hp > 0 then
        alive = alive + 1
      end
    end
    return alive
  end,
  -- A gallery pad answers first, then the field (its shop, its prompt).
  interact = function(g)
    if WorldGallery.interact(g) then
      return true
    end
    return Field.interact(g)
  end,
  context = function(g)
    return WorldGallery.context(g) or Field.context(g)
  end,
  frozen = function(g)
    return Field.frozen(g)
  end,
  invincible = function(g)
    return Field.invincible(g)
  end,
  hud = function(g)
    return Field.hud(g)
  end,
})
-- The way through the chapel: fires and posts (run/pilgrimage.lua).
Modes:register('pilgrimage', {
  prepared = true,
  session = { map = require('src.content.pilgrimage').start().map },
  record = 'run',
  policy = { attrition = true },
  attrition = function()
    return true
  end,
  worldView = function(g, out)
    return Pilgrimage.world(g, ModeViews.pilgrimWorld(g, g.run, out))
  end,
  objective = function()
    return Text.get('objective_pilgrim')
  end,
  runView = function(g, out)
    return ModeViews.run(g, g.run, out)
  end,
  -- One engraving on each gun, and its tempering (run/economy.lua).
  weaponModifier = function(g)
    return Economy.modifiers(g.run)
  end,
  init = function(g, options)
    Pilgrimage.init(g, options)
  end,
  construction = function(g)
    return Pilgrimage.construction(g)
  end,
  canTrade = function(g)
    local fire = Pilgrimage.fireHere(g)
    return fire ~= nil and g.run.lit[fire.id] == true
  end,
  closeShop = Sanctuary.closeTrade,
  buy = function(g, offer)
    local ok = Economy.trade(g, offer)
    if ok then
      Pilgrimage.bought(g)
    end
    return ok
  end,
  removeSigil = function(g, id)
    if Economy.unequip(g, id) then
      Pilgrimage.bought(g)
      return true
    end
    return false
  end,
  newRequiresConfirmation = function(g)
    return g.run.saved
  end,
  forget = function(g)
    Pilgrimage.forget(g)
  end,
  flush = function(g)
    return Pilgrimage.flush(g)
  end,
  creatures = function(g)
    return Pilgrimage.creatures(g)
  end,
  unsaved = function(g)
    return Pilgrimage.unsaved(g)
  end,
  relicWanted = function(g, pickup)
    return Pilgrimage.relicWanted(g, pickup)
  end,
  takeRelic = function(g, pickup)
    return Pilgrimage.takeRelic(g, pickup)
  end,
  start = function(g)
    return Pilgrimage.start(g)
  end,
  progress = function(g, dt)
    Pilgrimage.update(g, dt)
  end,
  ready = function(g)
    return Pilgrimage.travel(g)
  end,
  retry = function(g)
    return Pilgrimage.retry(g)
  end,
  lose = function(g)
    Pilgrimage.lose(g)
  end,
  reward = function(g, event)
    Pilgrimage.reward(g, event)
    Drops.kill(g, event)
  end,
  executed = function(g, event)
    Drops.executed(g, event)
  end,
  interact = function(g)
    return Pilgrimage.interact(g)
  end,
  context = function(g)
    return Pilgrimage.context(g)
  end,
  hud = function(g)
    return Pilgrimage.hud(g)
  end,
})
Modes.default = 'pilgrimage'
return Modes

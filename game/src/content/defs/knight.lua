-- The knight's body: the same Body schema as every demon, plus what only the
-- player has (shield share, invulnerability, dodge, hit volume, feet).
local Schema = require('src.core.schema')
local Body = require('src.content.defs.body')
local Knight = {}
Knight.perfectDodge = Schema:new('perfect dodge', {
  refund = { type = 'number', required = true, min = 0, desc = 'dodge charges given back' },
  freeze = { type = 'number', required = true, min = 0, desc = 'demons pause (s)' },
  guardReturn = {
    type = 'number',
    required = true,
    min = 0,
    desc = 'attacker takes this share of its blow on its guard',
  },
  reach = { type = 'number', required = true, min = 0, desc = 'attacker within this distance (m)' },
})
Knight.schema = Body.schema:extend('knight body', {
  armor = { type = 'number', required = true, min = 0, desc = 'ward at the start' },
  height = { type = 'number', required = true, min = 0, desc = 'standing hit volume height (m)' },
  feet = { type = 'number', required = true, min = 0, desc = 'volume starts this high (m)' },
  eye = { type = 'number', required = true, min = 0, desc = 'standing eye (and muzzle) height (m)' },
  shieldShare = {
    type = 'number',
    required = true,
    min = 0,
    max = 1,
    desc = 'share of a hit the ward takes',
  },
  iframes = { type = 'number', required = true, min = 0, desc = 'invulnerability after a blow (s)' },
  rollIframes = {
    type = 'number',
    required = true,
    min = 0,
    desc = 'invulnerability of a dodge (s)',
  },
  rollStamina = { type = 'number', required = true, min = 0, desc = 'what a dodge costs' },
  sideStep = {
    type = 'number',
    required = true,
    min = 0,
    desc = 'share of walking speed sideways',
  },
  backStep = {
    type = 'number',
    required = true,
    min = 0,
    desc = 'share of walking speed backwards',
  },
  airDrag = {
    type = 'number',
    required = true,
    min = 0,
    desc = 'friction of a shove in the air (1/s)',
  },
  perfectDodge = { type = 'table', required = true, schema = Knight.perfectDodge },
  woundFor = {
    type = 'number',
    required = true,
    min = 0,
    desc = 'a major wound slows the knight this long (s)',
  },
  slamShare = {
    type = 'number',
    required = true,
    min = 0,
    max = 1,
    desc = 'share of a wall slam the knight takes as harm',
  },
})
return Knight

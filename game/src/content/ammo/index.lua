-- How a weapon holds what it fires. A model is one entry with one interface, so
-- nothing else knows a magazine from a heat gauge. spec: the weapon's ammo table;
-- state: its live record (the arsenal holds it with the state of the action).
--   schema                       fields of spec
--   reloads                      it needs a reload mechanism
--   check(spec, path)            what its schema cannot say
--   newState(spec)               the fields of a fresh record
--   valid(spec, state)           a record that can be trusted
--   canFire(spec, state)         a pull can go off now
--   spend(spec, state, count)    a pull takes count; returns what it got
--   full(spec, state)            a reload has nothing to do
--   stocked(spec, state)         a reload has something to load
--   pending(spec, state)         what the next load moves
--   load(spec, state)            moves it; returns how much
--   room(spec, state)            what a supply could still add
--   refill(spec, state, n, cap)  adds n, up to cap; returns what it added
--   fill, clear, restock(spec, state)  everything, nothing, as it starts
--   left(spec, state)            shots it could still fire with what it holds
--   meter(spec, state)           value, reserve, capacity for the interface
--   offer(spec)                  pack, unit price and cap of the shop
--   pack(state), list(saved)     what a save keeps, by name and in order
--   unpack(spec, a, b, number)   back from a save (number: its checked reader)
--   tick(spec, state, dt)        optional: it changes with time
local Registry = require('src.core.registry')
local Ammo = Registry:new('ammunition models')
Ammo:register('magazine', require('src.content.ammo.magazine'))
-- The model of a weapon definition.
function Ammo.of(def)
  return Ammo:get(def.ammo.kind)
end
return Ammo

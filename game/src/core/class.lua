-- Minimal classes for objects that own behaviour (registries, worlds,
-- volleys, renderer parts). Game content is NOT built from class
-- hierarchies: creatures differ by data and by composed strategies.
--   local Volley = Class:extend('Volley')
--   function Volley:init(a, b) ... end        -- constructor
--   local v = Volley:new(a, b); v:is(Volley)  --> true
local Class = { name = 'Class' }
Class.__index = Class
function Class:extend(name)
  local cls = setmetatable({}, { __index = self })
  cls.__index = cls
  cls.super = self
  cls.name = name or 'Anonymous'
  return cls
end
function Class:new(...)
  local object = setmetatable({}, self)
  if object.init then
    object:init(...)
  end
  return object
end
-- True when the object is an instance of cls or of one of its subclasses.
function Class:is(cls)
  local m = getmetatable(self)
  while m do
    if m == cls then
      return true
    end
    m = m.super
  end
  return false
end
return Class

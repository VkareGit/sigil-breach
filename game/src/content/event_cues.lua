-- The sound of a deed (PLAN G5): which recipe and how loud a simulation event
-- sounds (feedback/event_cues.lua plays it). A deed of one knight that only the
-- presented one hears says so (presented).
local Shop = require('src.content.shop')
return {
  FlaskDrunk = { sound = 'pickup', volume = 0.5 },
  Executed = { sound = 'seal', volume = require('src.content.combat_defaults').execution.cue },
  Bought = { sound = 'pickup', volume = Shop.boughtCue },
  DoorPassed = { sound = 'seal', volume = 0.5 },
  DoorOpened = { sound = 'seal', volume = 0.5 },
  Rested = { sound = 'seal', volume = 0.5 },
  EchoRecovered = { sound = 'seal', volume = 0.5 },
  TriggerDry = { sound = 'empty', presented = true },
  Dashed = { sound = 'dash', presented = true },
  ZoneEntered = { sound = 'bell', volume = require('src.content.tuning').clocks.zoneBell },
}

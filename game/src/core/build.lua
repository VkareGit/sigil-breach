-- The build's identity, readable from every layer (0.29): the simulation
-- stamps it on journals (session/journal.lua) and the application shows it
-- (app/release.lua). One value, imported, never assigned from outside, so a
-- journal recorded by the game replays in a test or a tool that never loads
-- the application.
return { version = '0.31' }

-- The build's identity, readable from every layer (0.29): the simulation
-- stamps it on journals (session/journal.lua) and the application shows it
-- (app/release.lua). One value, imported, never assigned from outside, so a
-- journal recorded by the game replays in a test or a tool that never loads
-- the application.
local fingerprint = os.getenv('SIGIL_QA_SOURCE_FINGERPRINT')
local origin = fingerprint and 'qa-source-tree' or 'unverified-development'
if
  not fingerprint
  and love
  and love.filesystem
  and love.filesystem.getInfo('build-fingerprint.txt', 'file')
then
  fingerprint = assert(love.filesystem.read('build-fingerprint.txt')):match('^%x+')
  assert(fingerprint and #fingerprint == 64, 'invalid packaged source fingerprint') -- constant: SHA-256 hex
  origin = 'packaged-source-tree'
end
return { version = '0.46', sourceFingerprint = fingerprint, provenance = origin }

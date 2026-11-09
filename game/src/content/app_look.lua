-- The application's own scenes (app/application.lua, PLAN G7): the still a
-- --screenshot run frames, and the page a crash leaves on screen.
return {
  -- The knight's place and pitch (m, rad) and the first demon's distance.
  screenshot = { x = 16, z = 25.5, pitch = 0.04, enemyZ = 21.6, wait = 0.1 },
  crash = { ground = { 0.04, 0.05, 0.06 }, ink = { 1, 0.7, 0.5 }, margin = 30, wait = 0.1 },
}

local Tests = {}
function Tests.run(G, renderer, check)
  local Q = require('qa.runtime')
  local Preferences = require('src.storage.preferences')
  local Settings = require('src.content.settings')
  local Release = require('src.app.release')
  for _, version in ipairs({ 10, 12, 13, 14, 15 }) do
    local q = Q.new({ '--showcase-v' .. version })
    check(
      'legacy showcase v' .. version .. ' shares current isolation and capture route',
      q.capture
        and q.isolated
        and q:has('--showcase')
        and q.output == (os.getenv('SIGIL_UI_QA_DIR') or Release.handOutput)
    )
  end
  check(
    'normal launch never enters a test save identity',
    not Q.new({}).isolated and not Q.captureFlag('--fullscreen')
  )
  check(
    'manual QA isolates saves while keeping its visible mouse',
    Q.new({ '--ui-test' }).isolated and not Q.new({ '--ui-test' }).capture
  )
  check(
    'screenshot and benchmark are both captured and isolated',
    Q.new({ '--screenshot' }).capture and Q.new({ '--benchmark-v15' }):has('--benchmark')
  )
  local p =
    Preferences.decode('sensitivity=99\nfov=-3\nmusic=2\nmotion=false\nmuted=true\nhints=false')
  check(
    'saved preferences clamp to supported ranges and preserve toggles',
    p.sensitivity == 3 and p.fov == 85 and p.music == 1 and not p.motion and p.muted and not p.hints
  )
  local copy = Preferences.decode(Preferences.encode(p))
  check(
    'preferences round trip without losing any supported setting',
    copy.sensitivity == p.sensitivity
      and copy.fov == p.fov
      and copy.music == p.music
      and copy.motion == p.motion
      and copy.muted == p.muted
      and copy.hints == p.hints
      and copy.renderScale == p.renderScale
  )
  p = Preferences.decode(
    'sensitivity=nan\nfov=inf\nmusic=no\nnot motion=false\nhints=garbage\nunknown=1'
  )
  check(
    'invalid preferences and embedded key names leave safe defaults',
    p.sensitivity == 1
      and p.fov == 100
      and p.music == 0.65
      and p.motion
      and p.hints
      and p.renderScale == 1
  )
  for _, scale in ipairs(Settings.renderScale.choices) do
    local saved = Preferences.decode('renderScale=' .. scale)
    check(
      'render scale ' .. scale .. ' survives settings persistence',
      Preferences.decode(Preferences.encode(saved)).renderScale == scale
    )
  end
  for _, value in ipairs({ 'nan', 'inf', '0', '-1', '0.6', '2', 'invalid' }) do
    check(
      'unsupported render scale ' .. value .. ' keeps native quality',
      Preferences.decode('renderScale=' .. value).renderScale == 1
    )
  end
  local Field = require('src.run.test_field')
  local Rules = require('src.combat.rules')
  local function fresh()
    local g = Field.new(G)
    g.ephemeral = true
    Field.close(g)
    g.testField.invincible = false
    return g
  end
  local g = fresh()
  local Application = require('src.app.application')
  local app = Application.new()
  app.qa.isolated = true
  app:adopt(g)
  g.player.fireBuffer, g.player.jumpBuffer = 0.12, 0.12
  for _, scale in ipairs({ 0.75, 0.5, 1 }) do
    app:action('render_scale')
    check(
      'render scale command selects ' .. scale .. ' without clearing gameplay intentions',
      app.settings.renderScale == scale
        and g.view.renderScale == scale
        and g.player.fireBuffer == 0.12
        and g.player.jumpBuffer == 0.12
    )
  end
  app.settings = Preferences.decode('renderScale=0.75')
  app:adopt(fresh())
  check('a new session inherits the saved render scale', app.game.view.renderScale == 0.75)
  -- 0.43 (D02): the owner's A/B of the sounds. Every take of every set lies where the set says;
  -- the preference keeps a set and refuses a name it does not know; F7 goes round the sets.
  do
    local Sets = require('src.content.sound_sets')
    local missing = 0
    for _, prefix in pairs(Sets.prefix) do
      for _, spec in pairs(Sets.cues) do
        for take = 1, Sets.takes do
          local path = Sets.root .. spec.event .. '/' .. prefix .. '-' .. take .. '.wav'
          missing = missing + (love.filesystem.getInfo(path, 'file') and 0 or 1)
        end
      end
    end
    check('every recorded take lies where its set says', missing == 0)
    check(
      'the sound set is kept and a strange one refused',
      Preferences.decode('soundSet=stone').soundSet == 'stone'
        and Preferences.decode('soundSet=loud').soundSet == Sets.default
    )
    local Sound = require('src.audio.audio')
    local was = Sound.set
    Sound.useSet('classic')
    app:action('sound_set')
    local first = app.settings.soundSet
    app:action('sound_set')
    local second = app.settings.soundSet
    app:action('sound_set')
    check(
      'F7 goes round the sets in order',
      first == 'iron' and second == 'stone' and app.settings.soundSet == 'classic'
    )
    Sound.useSet(was)
  end
  g.player.fireBuffer, g.player.jumpBuffer = 0, 0
  local before = g.player.hp
  local Audio = require('src.audio.audio')
  local play = Audio.play
  local thuds = 0
  Audio.play = function(name, ...)
    if name == 'thud' then
      thuds = thuds + 1
    end
  end
  g.player.yaw = 0
  local over, recorded = Rules.slamPlayer(g, 7, g.player.x + 1, g.player.z)
  Audio.play = play
  local receipt = g.playerDamageReport
  check(
    'wall impact records the actual shield and health transaction once',
    receipt
      and receipt.source == 'wall'
      and math.abs(before - g.player.hp - receipt.healthDamage) < 1e-8
      and math.abs(receipt.incoming - receipt.healthDamage - receipt.absorbed - receipt.overkill)
        < 1e-8
  )
  check(
    'wall damage has the same directional feedback and guard signal as other hits',
    #g.view.hurtMarks == 1
      and g.view.hurt > 0
      and (g.player.pushX or 0) == 0
      and (g.player.pushZ or 0) == 0
      and math.abs(g.view.hurtMarks[1].angle - math.pi * 0.5) < 1e-8
      and g.view.weaponImpactVX < 0
  )
  check('a damaging wall contact owns exactly one thud', over > 0 and recorded and thuds == 1)
  Rules.slamPlayer(g, 7)
  check(
    'a latched wall impact cannot repeat its report or sound marker',
    g.playerDamageReport == receipt and #g.view.hurtMarks == 1
  )
  g = fresh()
  g.player.hp = 0.1
  g.player.armor = 0
  Rules.slamPlayer(g, 12)
  check(
    'nonlethal wall contact cannot heal a critically wounded player',
    g.player.hp == 0.1 and g.state == 'playing' and g.playerDamageReport.healthDamage == 0
  )
  g = fresh()
  g.testField.invincible = true
  Rules.slamPlayer(g, 12)
  check(
    'invincible gallery contact does not invent a damage receipt',
    g.playerDamageReport == nil and g.player.hp == 100
  )
  for _, invincible in ipairs({ false, true }) do
    g = fresh()
    g.testField.invincible = invincible
    local wallX
    for x = 17, g.world.size do
      if g.world.map[25][x] == 1 then
        wallX = x
        break
      end
    end
    g.player.x, g.player.z = wallX - 0.5 - 0.22 - 0.02, 25
    g.player.yaw = 0
    g.player.pushX, g.player.pushZ = 7, 0
    thuds = 0
    Audio.play = function(name, ...)
      if name == 'thud' then
        thuds = thuds + 1
      end
    end
    for _ = 1, 6 do
      g:update(1 / 120, {})
    end
    Audio.play = play
    check(
      'real movement wall contact has one sound and correct receipt, invincible='
        .. tostring(invincible),
      thuds == 1
        and g.player.pushX == 0
        and (
          invincible and not g.playerDamageReport
          or not invincible
            and g.playerDamageReport
            and #g.view.hurtMarks == 1
            and math.abs(g.view.hurtMarks[1].angle - math.pi * 0.5) < 1e-6
        )
    )
  end
  if renderer then
    local B = require('src.combat.ballistics')
    local Weapon = require('src.render.weapon')
    g = fresh()
    g.player.yaw = 0.37
    g.player.pitch = 0.16
    g.view.viewPunch = 0.05
    g.view.rollPunch = 0.04
    g.view.bank = 0.02
    g.view.shake = 0.10
    local ox, oy, oz = B.origin(g)
    local dx, dy, dz = B.direction(g.player.yaw, g.player.pitch)
    renderer:draw(g, 1280, 720)
    local x, y = renderer:project(ox + dx * 8, oy + dy * 8, oz + dz * 8)
    check(
      'real camera keeps the authoritative shot at reticle centre during body punch',
      math.abs(x - renderer.w * 0.5) < 1e-6 and math.abs(y - renderer.h * 0.5) < 1e-6
    )
    g.view.viewPunch = 0
    local _, neutral = Weapon.transform(g, 800, 450)
    g.view.viewPunch = 0.05
    local _, struck = Weapon.transform(g, 800, 450)
    check(
      'body punch remains visible in hands within four pixels',
      math.abs(struck - neutral - 4) < 1e-6
    )
  end
end
return Tests

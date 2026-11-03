require('jit.opt').start('maxtrace=20000', 'maxrecord=8000', 'maxmcode=131072', 'sizemcode=1024', 'maxsnap=1000', 'maxside=200')
local root = assert(os.getenv('SIGIL_AUDIT_GAME')):gsub('\\', '/')
local out = assert(os.getenv('SIGIL_AUDIT_OUT')):gsub('\\', '/')
package.path = root .. '/?.lua;' .. package.path
local lines = {}
local function log(s) lines[#lines + 1] = s; print(s) end
local function write()
  local f = assert(io.open(out .. '/probe-results.txt', 'w'))
  f:write(table.concat(lines, '\n')); f:close()
end
function love.load()
  local ok, err = xpcall(function()
    require('src.run.modes')
    require('qa.floor').install()
    local Game = require('src.session.game')
    local P = require('src.run.pilgrimage')
    local K = require('src.content.pilgrimage')
    local A = require('src.content.enemies')
    local Pools = require('src.session.world')
    local Save = require('src.storage.save')
    local Copy = require('src.core.schema').copy
    local Collect = require('src.session.interactions')
    local Attacks = require('src.enemies.actions')
    local AI = require('src.enemies.ai')
    local Encounter = require('src.session.encounter')
    local Hazards = require('src.enemies.hazards')
    local Economy = require('src.run.economy')
    local function fresh(clear)
      local g = Game.new('pilgrimage', nil, { origin = false })
      g.ephemeral = true; g:act('start')
      if clear then Encounter.clearStage(g) end
      return g, g.player
    end
    local function quiet(g)
      for _, e in ipairs(Pools.of(g, 'enemies')) do e.awake = false end
    end
    local function fire(g)
      quiet(g); g.player.x, g.player.z = 27, 35
      assert(P.interact(g)); assert(g.state == 'shop'); g:act('closeShop')
    end
    local function cache(g, id)
      for _, c in ipairs(Pools.of(g, 'pickups')) do if c.rewardId == id then return c end end
    end
    local function post(g, id)
      for _, e in ipairs(Pools.of(g, 'enemies')) do if e.post == id then return e end end
    end
    -- Public collection + rest + death/retry. No changes to content.
    do
      local g, p = fresh()
      local c = assert(cache(g, 'narthex_left'))
      p.arsenal.judge.reserve = 0; p.x, p.z = c.x, c.z
      Collect.collectSupplies(g)
      log(('PICKUP collected=%s reserve=%d'):format(tostring(not cache(g,'narthex_left')),p.arsenal.judge.reserve))
      fire(g)
      log(('PICKUP after_rest present=%s secured=%s'):format(tostring(cache(g,'narthex_left') ~= nil),tostring(g.run.taken.narthex_left)))
      P.lose(g); P.retry(g)
      log(('PICKUP after_death present=%s'):format(tostring(cache(g,'narthex_left') ~= nil)))
    end
    -- Save captures wallet but neither unsecured kills nor the consumed resources.
    do
      local g, p = fresh()
      local e = post(g, 'nave_1')
      g:damageEnemy(e, e.hp + 1, 'weapon', nil, p.id, 'judge')
      p.hp, p.armor, p.arsenal.judge.mag, p.arsenal.judge.reserve = 10, 0, 0, 0
      p.abilityState.flask.uses = 0
      -- Real file roundtrip within this probe's APPDATA identity.
      g.ephemeral = false; assert(P.save(g)); g.ephemeral = true
      local h = Game.new('pilgrimage'); h.ephemeral = true; h:act('start')
      log(('CONTINUE wallet=%d deaths=%d hp=%g ward=%g judge=%d+%d flask=%d slain_nave1=%s enemy_alive=%s'):format(
        h.run.wallet,h.run.deaths,h.player.hp,h.player.armor,h.player.arsenal.judge.mag,h.player.arsenal.judge.reserve,h.player.abilityState.flask.uses,tostring(h.run.slain.nave_1),tostring(post(h,'nave_1').hp > 0)))
      P.forget(h)
    end
    -- Recovery timer using the actual AI, frozen body motion only. Dummy still ticks both clocks.
    do
      local g, p = fresh(true)
      local e = g:spawn('boss', 10, 14)
      local atk
      for _, a in ipairs(A.of(e).attacks) do if a.id == 'cleave' then atk = a end end
      assert(atk)
      e.ai, e.dummy = 'recover', true
      Attacks.rest(e, atk)
      local initialAttack, initialRecover = e.attack, e.recover
      local t = 0
      -- dummy pauses recover: explicitly use ordinary non-dummy tick but block sensing/selection
      e.dummy = false; e.ai = 'strike'; e.attackSpec = atk; e.attackKind = atk.id
      e.aimX, e.aimZ, e.target = p.x, p.z, p.id
      -- AI.states.strike is a public executor registry; local probe replacement prevents another attack,
      -- while preserving tickBody exactly. Never changes repository files.
      local strike = AI.states.strike; AI.states.strike = function() end
      while (e.attack > 0 or e.recover > 0) and t < 10 do
        AI.demons(g, 1/120); t = t + 1/120
      end
      AI.states.strike = strike
      log(('RECOVERY cleave configured_recover=%.3f cooldown=%.3f initial_recover=%.3f initial_attack=%.3f both_expired=%.3f sum_configured=%.3f'):format(atk.recover,atk.cooldown,initialRecover,initialAttack,t,atk.recover+atk.cooldown))
    end
    -- A live Buer pool keeps burning after its caster dies. Rest only asks about live bodies.
    do
      local g, p = fresh(true)
      p.x, p.z, p.hp = 27, 35, 20
      local e = g:spawn('buer', 27, 32)
      local pool = A.of(e).attacks[1].pool
      Hazards.add(g,p.x,p.z,0,pool.radius,pool.life,{packet=pool.packet,pulse=pool.pulse,volume=pool.volume,owner=e.id,side='demons'})
      g:damageEnemy(e,e.hp+1,'weapon',nil,p.id,'judge')
      local hunting = P.fighting(g)
      fire(g)
      local beforeHp, beforeWard = p.hp,p.armor
      for _=1,72 do g:update(1/120,{}) end
      log(('REST_POOL hunting=%s hazards=%d hp=%.3f->%.3f ward=%.3f->%.3f'):format(tostring(hunting),#Pools.of(g,'hazards'),beforeHp,p.hp,beforeWard,p.armor))
    end
    -- HUD report does not carry per-weapon worn engravings.
    do
      local g = fresh(true)
      g.run.wallet=10000; fire(g)
      g.state='shop'; assert(Economy.buy(g,'choke')); assert(Economy.buy(g,'breaker')); g.state='playing'
      g:switchWeapon(1)
      local hud=P.hud(g)
      log(('HUD exorcist_worn=%s judge_worn=%s report_worn=%s report_glyph=%s selected=%s'):format(tostring(g.run.worn.exorcist),tostring(g.run.worn.judge),tostring(hud.worn),tostring(hud.glyph),tostring(g.player.weapon)))
    end
    -- Exact finite economy, not a difficulty estimate.
    do
      local total, hp, ammo, shells, draughts = 0,0,0,0,0
      for _, e in ipairs(K.start().garrison) do total=total+A.get(e.creature).souls*K.souls; hp=hp+A.get(e.creature).body.hp end
      for _, c in ipairs(K.start().supplies) do
        if c.kind=='flask' then draughts=draughts+c.amount elseif c.weapon=='judge' then ammo=ammo+c.amount else shells=shells+c.amount end
      end
      local price=0
      for _,o in ipairs(require('src.content.shop').offers) do
        if o.sold~='field' then for r=0,(o.limit or 1)-1 do price=price+math.ceil(o.price*(o.growth or 1)^r) end end
      end
      log(('ECONOMY souls_once=%d enemy_hp=%d shop_all=%d caches_judge=%d shells=%d flask=%d'):format(total,hp,price,ammo,shells,draughts))
    end
    log('PROBE COMPLETE')
  end, debug.traceback)
  if not ok then log('ERROR '..tostring(err)) end
  write(); love.event.quit(ok and 0 or 1)
end

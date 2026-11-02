local root = assert(os.getenv('SIGIL_AUDIT_GAME'))
function love.errorhandler(message)
  local f=assert(io.open(assert(os.getenv('SIGIL_AUDIT_OUT'))..'/probe-error.txt','w'))
  f:write(tostring(message)..'\n'..debug.traceback()); f:close()
  return function() return 1 end
end
function love.load()
  local ok, reason = xpcall(function()
    package.path=root:gsub('\\','/')..'/?.lua;'..package.path
    require('src.run.modes')
    require('qa.floor').install()
    local Game = require('src.session.game')
    local P = require('src.run.pilgrimage')
    local Encounter = require('src.session.encounter')
    local Weapons = require('src.content.weapons')
    local Save = require('src.storage.save')
    local X = require('src.combat.explosives')
    local Abilities = require('src.content.abilities')
    local Execute = require('src.combat.execution')
    local World = require('src.world.arena')
    local B = require('src.combat.ballistics')
    local Rules = require('src.combat.rules')
    local function fresh()
      local g = Game.new('pilgrimage', nil, {origin=false})
      g.ephemeral = true
      g:act('start')
      Encounter.clearStage(g)
      g.player.x, g.player.z, g.player.yaw = 24, 30, math.pi
      return g, g.player
    end
    do
      local g, p = fresh()
      g:switchWeapon(2)
      for i=1,3 do
        local e=g:spawn('imp',24+(i-2)*0.6,24)
        e.hp=1
      end
      local action=Abilities:get('powder').action
      local r=X.strike(g,{x=24,y=1,z=24,owner=p.id},action.radius,action.blast,'charge')
      print(('CHAIN charge kills=%d shots=%d chain=%s weapon=%s'):format(r.kills,p.shots,tostring(p.chainCount),tostring(p.chainWeapon)))
    end
    do
      local g, p=fresh()
      g.run.vows.vow_vigor=3
      P.bought(g)
      print(('HEALTH hp=%g maxHp=%g HUD=%s%%'):format(p.hp,p.maxHp,math.ceil(p.hp)))
    end
    do
      local g=fresh()
      g.ephemeral=false
      g.run.wallet,g.run.dirty=120,true
      local original=Save.write
      local calls=0
      Save.write=function() calls=calls+1; return false,'injected write failure' end
      local success=P.save(g)
      Save.write=function() calls=calls+1; return true end
      P.flush(g)
      P.update(g,10)
      print(('SAVE success=%s dirty=%s attempts_after_flush_and_update=%d warning=%s'):format(tostring(success),tostring(g.run.dirty),calls,tostring(g.saveWarning)))
      Save.write=original
    end
    do
      local g,p=fresh()
      p.x,p.z,p.yaw=24,24,0
      g:setCell(24,25,1)
      local e=g:spawn('imp',24,26)
      e.stun=2
      Rules.addCondition(e,'exposed',2)
      local _,_,kind=B.world(g.world,24,1,24,0,0,1,2)
      local hp=e.hp
      local result=Execute.perform(g)
      print(('EXECUTION wall=%s performed=%s damage=%g'):format(tostring(kind),tostring(result),hp-e.hp))
    end
    do
      local g,p=fresh()
      local e=g:spawn('imp',p.x,p.z-2)
      e.stun=2
      Rules.addCondition(e,'exposed',2)
      p.jump=8
      local hp=e.hp
      local result=Execute.perform(g)
      print(('EXECUTION height_difference=8 performed=%s damage=%g'):format(tostring(result),hp-e.hp))
    end
    do
      local g=Game.new('pilgrimage',nil,{origin=false})
      g.ephemeral=true
      g:act('start')
      for _=1,60 do g:update(1/120,{}) end
      local awake,seen,waiting=0,0,0
      for _,e in ipairs(require('src.session.world').of(g,'enemies')) do
        if e.awake then awake=awake+1 end
        local dx,dz=e.x-g.player.x,e.z-g.player.z
        local d=math.sqrt(dx*dx+dz*dz)
        local dot=(dx*math.sin(g.player.yaw)+dz*math.cos(g.player.yaw))/d
        if dot>math.cos(math.rad(50)) and d<25 and Rules.sees(g,e,g.player) then
          seen=seen+1
          if not e.awake then waiting=waiting+1 end
        end
      end
      print(('OPENING awake=%d in_cone_with_LOS=%d waiting=%d'):format(awake,seen,waiting))
    end
    do
      local g,p=fresh()
      local defs=require('src.content.enemies').get('buer').attacks[1].pool.packet.effects
      local effects=require('src.combat.effects')
      for i=1,3 do effects.apply(g,p,defs,{side='demons',id=999}) end
      p.x,p.z=27,35
      P.interact(g)
      local left=p.effectState and #p.effectState or 0
      g:act('closeShop')
      local hp,armor=p.hp,p.armor
      for i=1,72 do g:update(1/120,{}) end
      print(('REST poison_instances=%d damage_after_0.6s=%.2f ward_lost=%.2f'):format(left,hp-p.hp,armor-p.armor))
    end
    do
      local g,p=fresh()
      p.armor,p.hp=0,1
      g:damagePlayer({base=100,impact=140},p.x,p.z+1)
      local push=p.pushZ
      P.retry(g)
      local z=p.z
      local after=p.pushZ
      for i=1,12 do g:update(1/120,{}) end
      print(('RETRY fatal_push=%s retained_push=%s displacement_no_input=%.4f'):format(tostring(push),tostring(after),p.z-z))
    end
    do
      local g,p=fresh()
      g:shoot()
      local intent=require('src.player.intent')
      local success=intent.dash(g,1/120,true,1,0,p)
      print(('RECOVERY dodge=%s recover_ms=%.0f refusal=%s refusal_timer=%s buffer_ms=%.0f'):format(tostring(success),(p.recoverAt-g.elapsed)*1000,tostring(g.view.refusal),tostring(g.view.refusalTimer),p.dashBuffer*1000))
    end
    do
      local function up(fn,key)
        for i=1,100 do local name,value=debug.getupvalue(fn,i); if not name then break end; if name==key then return value end end
        error('missing upvalue '..key)
      end
      local hud=require('src.ui.hud')
      local follow=up(up(hud.draw,'foePanel'),'follow')
      local trail=up(follow,'trail')
      local original=love.timer.getDelta
      love.timer.getDelta=function() return 1/60 end
      local target={id=99999,hp=100,maxHp=100}
      follow(target); target.hp=50; follow(target)
      -- While no target is under the crosshair, H.draw does not invoke follow at all.
      local before=trail.hold
      follow(target)
      print(('TRAIL no_target_time_not_applied=true sum=%g timer_changes_only_by_draw_delta=%.4f'):format(trail.sum,before-trail.hold))
      love.timer.getDelta=original
    end
    do
      local K=require('src.content.pilgrimage')
      K.areas:register('audit_annex',{id='audit_annex',map='floor',first='audit_fire',fires={{id='audit_fire',name='fire_west',x=16,z=14}},doors={},garrison={}})
      local chapel=K.start()
      chapel.doors[#chapel.doors+1]={id='audit_door',leads='audit_annex',side={x=27,z=31,yaw=0,art={x=27,z=30,yaw=0}},back={x=16,z=17.5,yaw=0,art={x=16,z=18,yaw=0}}}
      local g,p=fresh()
      p.x,p.z=27,31
      g:interact(); g:interact()
      p.hp,p.armor=1,0
      g:damagePlayer(500)
      g:act('retry')
      local _,home=K.fireOf(g.run.fire)
      print(('AREA retry area=%s map=%s expected_area=%s expected_map=%s fire=%s position=%.1f,%.1f'):format(g.run.area,g.world.mapId,home.id,home.map,g.run.fire,p.x,p.z))
      chapel.doors[#chapel.doors]=nil
      K.areas:unregister('audit_annex')
    end
    do
      local Bot=require('qa.souls_bot')
      local g=Game.new('pilgrimage',nil,{origin=false}); g.ephemeral=true; g:act('start')
      local seed=7
      local function roll() seed=seed*16807%2147483647; return seed/2147483647 end
      local knight,memory=Bot.walker(Bot.human(0.2,roll)),{}
      local states={}
      for frame=1,3600 do
        if g.state=='dead' then g:act('retry'); memory={} end
        for _=1,2 do g:update(1/120,knight(g,memory,24,10.5)) end
        states[g.state]=(states[g.state] or 0)+1
      end
      print(('WATCH_SIM playing_frames=%d shop_frames=%d final=%s elapsed=%.3f shots=%d'):format(states.playing or 0,states.shop or 0,g.state,g.elapsed,g.player.shots))
    end
    print('PROBES COMPLETE')
  end,debug.traceback)
  if not ok then print(reason) end
  love.event.quit(ok and 0 or 1)
end

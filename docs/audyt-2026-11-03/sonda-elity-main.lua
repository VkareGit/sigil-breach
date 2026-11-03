require('jit.opt').start('maxtrace=20000','maxrecord=8000','maxmcode=131072','sizemcode=1024','maxsnap=1000','maxside=200')
local root=assert(os.getenv('SIGIL_AUDIT_GAME')):gsub('\\','/')
local out=assert(os.getenv('SIGIL_AUDIT_OUT')):gsub('\\','/')
package.path=root..'/?.lua;'..package.path
local lines={}
local function log(s) lines[#lines+1]=s; print(s) end
function love.load()
  local ok,err=xpcall(function()
    require('src.run.modes'); require('qa.floor').install()
    local Game=require('src.session.game')
    local Release=require('src.app.release')
    local Bot=require('qa.souls_bot')
    local Stats=require('src.session.stats')
    local P=require('src.run.pilgrimage')
    local Pools=require('src.session.world')
    local function kite(g,m)
      local input=Bot.careless(g,m)
      input.forward=-1
      return input
    end
    local function orbit(g,m)
      local input=Bot.careless(g,m)
      input.strafe=1
      return input
    end
    local trials={}; for t in (os.getenv('SIGIL_TRIALS') or 'ash,storm'):gmatch('[^,]+') do trials[#trials+1]=t end
    for _,trial in ipairs(trials) do
      for _,kind in ipairs({'careless','backpedal','orbit','learning'}) do
        local brain=kind=='backpedal' and kite or kind=='orbit' and orbit or Bot[kind]
        for seed=1,tonumber(os.getenv('SIGIL_SEEDS') or '2') do
          local g=Game.new('field','proving',Release.sessionOptions.field)
          g.ephemeral=true; g.rng.sim:seed(seed)
          assert(g:act('catalog','field_chamber_'..trial))
          local mem,blows={},0
          local used={}
          g.bus:on('sim','AttackReleased',function(ev) blows=blows+1; local id=(ev.attack and ev.attack.id) or (ev.enemy and ev.enemy.attackSpec and ev.enemy.attackSpec.id) or '?'; used[id]=(used[id] or 0)+1 end)
          local tele,cancel,stun,ais=0,0,0,{}
          g.bus:on('sim','AttackTelegraphed',function() tele=tele+1 end)
          g.bus:on('sim','AttackCancelled',function() cancel=cancel+1 end)
          for i=1,120*120 do
            g:update(1/120,brain(g,mem))
            local e=g.enemies[1]; if e and e.hp>0 then if (e.stun or 0)>0 then stun=stun+1/120 end; ais[e.ai]=(ais[e.ai] or 0)+1/120; if e.ai=='move' then local dd=math.sqrt((e.x-g.player.x)^2+(e.z-g.player.z)^2); ais.dsum=(ais.dsum or 0)+dd/120; if not e.visible then ais.blind=(ais.blind or 0)+1/120 end; if (e.blocked or 0)>0 then ais.blocked=(ais.blocked or 0)+1/120 end; if os.getenv('SIGIL_TRACE')==kind and i%60==0 then log(string.format('  t=%.1f ai=%s d=%.1f speed=%.2f walk=%.2f duel=%s vis=%s px=%.1f pz=%.1f ex=%.1f ez=%.1f',i/120,e.ai,math.sqrt((e.x-g.player.x)^2+(e.z-g.player.z)^2),e.speed or -1,e.walkSpeed or -1,tostring(e.duelMove),tostring(e.visible),g.player.x,g.player.z,e.x,e.z)) end end end
            if g.state~='playing' or g.testField.roomTrial.status~='active' then break end
          end
          local u={} for k,v in pairs(used) do u[#u+1]=k..'='..v end table.sort(u)
          log(string.format('ROOM %s %s seed%d t=%.2f state=%s result=%s hp=%.1f ward=%.1f blows=%d [%s]',trial,kind,seed,g.elapsed,g.state,g.testField.roomTrial.status,g.player.hp,g.player.armor,blows,table.concat(u,' ')))
          local a={} for k,v in pairs(ais) do a[#a+1]=string.format('%s=%.1f',k,v) end table.sort(a)
          log(string.format('   telegraphed=%d cancelled=%d stunned=%.1fs states: %s',tele,cancel,stun,table.concat(a,' ')))
        end
      end
    end
    for _,miss in ipairs(os.getenv('SIGIL_CHAPEL') and {0,0.1,0.3} or {}) do
      for seed=1,2 do
        local g=Game.new('pilgrimage',nil,{origin=false}); g.ephemeral=true; g:act('start')
        g.rng.sim:seed(seed)
        local rng=seed
        local function roll() rng=rng*16807%2147483647;return rng/2147483647 end
        local brain=Bot.walker(Bot.human(miss,roll))
        local memory,deaths,shots,empty,fullPackTicks,rests={},0,0,0,0,0
        g.bus:on('sim','ShotFired',function() shots=shots+1 end)
        for i=1,180*120 do
          if g.state=='dead' then deaths=deaths+1;g:act('retry');memory={}
          elseif g.state=='shop' then rests=rests+1;g:act('closeShop') end
          local p=g.player
          if p.arsenal.judge.mag+p.arsenal.judge.reserve+p.arsenal.exorcist.mag+p.arsenal.exorcist.reserve==0 then empty=empty+1 end
          for _,pack in ipairs(Pools.of(g,'pickups')) do
            if pack.kind=='ammo' and (pack.x-p.x)^2+(pack.z-p.z)^2<0.3^2 then
              fullPackTicks=fullPackTicks+1;break
            end
          end
          g:update(1/120,brain(g,memory,24,10.5))
        end
        local lit=0;for _ in pairs(g.run.lit) do lit=lit+1 end
        log(string.format('CHAPEL miss=%.1f seed%d kills=%d deaths=%d shots=%d empty_s=%.2f near_uncollected_pack_s=%.2f rests=%d lit=%d sanctuary=%s pos=%.2f,%.2f',miss,seed,Stats.total(g,'kills'),deaths,shots,empty/120,fullPackTicks/120,rests,lit,tostring(g.run.lit.sanctuary),g.player.x,g.player.z))
      end
    end
    log('COMPLETE')
  end,debug.traceback)
  if not ok then log('ERROR '..tostring(err)) end
  local f=assert(io.open(out..'/combat-probe-results.txt','w'));f:write(table.concat(lines,'\n'));f:close()
  love.event.quit(ok and 0 or 1)
end

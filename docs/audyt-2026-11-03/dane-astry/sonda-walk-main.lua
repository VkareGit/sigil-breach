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
    for _,trial in ipairs({'claws','iron','stars','resin','ash','storm'}) do
      for _,kind in ipairs({'careless','backpedal','orbit','learning'}) do
        local brain=kind=='backpedal' and kite or kind=='orbit' and orbit or Bot[kind]
        for seed=1,2 do
          local g=Game.new('field','proving',Release.sessionOptions.field)
          g.ephemeral=true; g.rng.sim:seed(seed)
          assert(g:act('catalog','field_chamber_'..trial))
          local mem,blows={},0
          g.bus:on('sim','AttackReleased',function() blows=blows+1 end)
          for i=1,120*120 do
            g:update(1/120,brain(g,mem))
            if g.state~='playing' or g.testField.roomTrial.status~='active' then break end
          end
          log(string.format('ROOM %s %s seed%d t=%.2f state=%s result=%s hp=%.1f ward=%.1f blows=%d',trial,kind,seed,g.elapsed,g.state,g.testField.roomTrial.status,g.player.hp,g.player.armor,blows))
        end
      end
    end
    for _,miss in ipairs({0,0.1,0.3}) do
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

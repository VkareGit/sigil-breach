-- Read-only summary of the actual combat report, displayed inside the test catalog.
local R = {}
local Skin = require('src.ui.skin')
local C = Skin.colors
local function amount(value)
  return string.format('%.1f', math.max(0, value or 0))
end
function R.lines(report)
  if not report then
    return 'LAST SHOT / NO MEASUREMENT', 'Fire on the proving ground. F2 shows the result.'
  end
  local distance = 'NO HIT'
  if report.distanceMin then
    distance = amount(report.distanceMin)
    if report.distanceMax and report.distanceMax - report.distanceMin >= 0.1 then
      distance = distance .. '−' .. amount(report.distanceMax)
    end
    distance = distance .. ' M'
  end
  local weapon = report.weaponName or 'EXORCIST'
  local first = 'SHOT: '
    .. weapon
    .. ' / '
    .. distance
    .. ' / HITS '
    .. (report.pelletsHit or 0)
    .. ' / '
    .. (report.pellets or 0)
    .. ' / TARGETS '
    .. (report.targets or 0)
  local second = 'HP −'
    .. amount(report.healthDamage)
    .. ' / ARMOUR '
    .. amount(report.blocked)
    .. ' / IMPACT '
    .. amount(report.impact)
    .. ' / OVERKILL '
    .. amount(report.overkill)
  if (report.headHits or 0) > 0 then
    second = second .. ' / HEAD ' .. report.headHits
  end
  return first, second
end
function R.draw(report, ui)
  local first, second = R.lines(report)
  Skin.zone('last shot report', 86, 562, 1082, 44)
  Skin.boxText(first, 86, 562, 1082, 20, ui.fonts[14], C.gold)
  Skin.boxText(second, 86, 586, 1082, 20, ui.fonts[14], C.ivory)
  Skin.endZone()
end
return R

-- Read-only summary of the actual combat report, displayed inside the test catalog.
local R = {}
local Skin = require('src.ui.skin')
local Text = require('src.content.text')
local C = Skin.colors
local function amount(value)
  return string.format('%.1f', math.max(0, value or 0))
end
function R.lines(report)
  if not report then
    return Text.get('report_none'), Text.get('report_none_hint')
  end
  local distance = Text.get('report_no_hit')
  if report.distanceMin then
    distance = amount(report.distanceMin)
    if report.distanceMax and report.distanceMax - report.distanceMin >= 0.1 then
      distance = Text.get('report_range', { near = distance, far = amount(report.distanceMax) })
    end
    distance = Text.get('report_distance', { distance = distance })
  end
  local first = Text.get('report_first', {
    weapon = Text.get(report.weaponName or 'weapon_exorcist'),
    distance = distance,
    hit = report.pelletsHit or 0,
    pellets = report.pellets or 0,
    targets = report.targets or 0,
  })
  local second = Text.get('report_second', {
    health = amount(report.healthDamage),
    blocked = amount(report.blocked),
    impact = amount(report.impact),
    overkill = amount(report.overkill),
  })
  if (report.headHits or 0) > 0 then
    second = second .. Text.get('report_head', { count = report.headHits })
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

local A = {}
local Skin = require('src.ui.skin')
local GoeticSigils = require('src.ui.goetic_sigils')
local OccultPlates = require('src.ui.occult_plates')
local Palette = require('src.ui.palette')
local Queries = require('src.session.queries')
local Text = require('src.content.text')
A.entries = require('src.content.occult_catalog').entries
local ArchiveLook = require('src.content.ui_look').archive
local FrameSize = require('src.content.ui_layout')
function A.controls(g)
  local buttons = {}
  for i, entry in ipairs(A.entries) do
    buttons[#buttons + 1] = {
      id = 'archive_' .. i,
      label = Text.get(entry.name),
      x = ArchiveLook.entry.x,
      y = ArchiveLook.entry.y + (i - 1) * ArchiveLook.entry.step,
      w = ArchiveLook.entry.w,
      h = ArchiveLook.entry.h,
    }
  end
  local back = ArchiveLook.back
  buttons[#buttons + 1] = {
    id = 'field_open',
    label = Text.get('archive_back'),
    x = back.x,
    y = back.y,
    w = back.w,
    h = back.h,
  }
  return buttons
end
function A.draw(g, U)
  Skin.auditLayer('occult archive')
  local C = Skin.colors
  local index = math.max(1, math.min(#A.entries, Queries.field(g).archiveSelection or 1))
  local entry = A.entries[index]
  local L = ArchiveLook
  love.graphics.setColor(0, 0, 0, L.veil)
  love.graphics.rectangle('fill', 0, 0, FrameSize.width, FrameSize.height)
  Skin.panel(L.page[1], L.page[2], L.page[3], L.page[4], 6, L.page.corner)
  local function label(t, box, col, center)
    local x, y, w, h = box[1], box[2], box[3], box[4]
    Skin.zone('archive inscription', x, y, w, h)
    Skin.boxText(t, x, y, w, h, U.fonts[box.font], col or C.ivory, center)
    Skin.endZone()
  end
  label(Text.get('archive_title'), L.title, C.gold, true)
  label(Text.get('archive_subtitle'), L.subtitle, C.ivory, true)
  label(Text.get(entry.name), L.name, C.gold, true)
  local x, y, w, h
  if OccultPlates.entries[entry.id] then
    local P = L.plate
    x, y, w, h = OccultPlates.draw(entry.id, P[1], P[2], P[3], P[4], Palette.sepia)
  else
    local S = L.seal
    GoeticSigils.draw(entry.id, S[1], S[2], S[3], Palette.sepia, 1)
    x, y, w, h = S[1], S[2], S[3], S[3]
  end
  local F = L.figure
  Skin.zone('historical figure', F[1], F[2], F[3], F[4])
  Skin.imageBounds('archive ' .. entry.id, x, y, w, h)
  Skin.endZone()
  label(Text.get(entry.source), L.source, C.ivory, true)
  label(Text.get(entry.detail), L.detail, C.muted, true)
  label(Text.get('archive_hint'), L.hint, C.muted, true)
end
return A

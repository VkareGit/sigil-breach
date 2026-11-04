-- The anatomy region editor (plan v10 V7): draws an annotation over its
-- painted frames and edits it (model: game/qa/art/anatomy_editor.lua).
-- Usage (ANATOMY-EDITOR.ps1): lovec tools/art/anatomy_editor <game> <id> [atlas]
--   Left/Right frame   Tab part   drag a vertex   I insert   Del remove
--   N new part   X drop part   Z zone   M material   H head anchor at mouse
--   Ctrl+Z undo   P problems   S save (work/anatomy/<id>.lua)
local root, id, atlas
local Editor, Frames, Materials
local editor, images, view, dragging, status, smoke = nil, {}, nil, false, '', nil
local function read(path)
  local f = assert(io.open(path, 'rb'), path)
  local s = f:read('*a')
  f:close()
  return s
end
local function mount()
  table.insert(package.loaders, 1, function(name)
    if name:find('^src%.') or name:find('^qa%.') or name:find('^assets%.') then
      local path = root .. '/' .. name:gsub('%.', '/') .. '.lua'
      return assert(loadstring(read(path), path))
    end
  end)
end
local function image(path)
  if not images[path] then
    local data = love.filesystem.newFileData(read(root .. '/' .. path), path)
    images[path] = love.graphics.newImage(data)
  end
  return images[path]
end
local COLORS = {
  head = { 0.95, 0.3, 0.25 },
  torso = { 0.3, 0.75, 0.95 },
  lower = { 0.4, 0.9, 0.35 },
  [false] = { 0.8, 0.8, 0.8 },
}
function love.load(arguments)
  root, id, atlas = arguments[1], arguments[2], arguments[3]
  assert(root and id, 'usage: lovec tools/art/anatomy_editor <game> <annotation id> [atlas]')
  atlas = atlas or id
  mount()
  Editor = require('qa.art.anatomy_editor')
  Frames = require('src.content.art.enemy_frames')
  Materials = {}
  for name in pairs(require('src.content.ballistic_surfaces')) do
    Materials[#Materials + 1] = name
  end
  table.sort(Materials)
  local Anatomy = require('src.content.art.anatomy_regions')
  editor = Editor.new(id, assert(Anatomy.layouts[id], 'unknown annotation ' .. id))
  -- A smoke run (SIGIL_EDITOR_SMOKE=<png>): one frame drawn, saved, quit.
  smoke = os.getenv('SIGIL_EDITOR_SMOKE')
  if smoke then
    editor:show(tonumber(os.getenv('SIGIL_EDITOR_FRAME') or '1'))
  end
end
function love.update()
  if smoke and view then
    local path = smoke
    love.graphics.captureScreenshot(function(data)
      local file = assert(io.open(path, 'wb'))
      file:write(data:encode('png'):getString())
      file:close()
      love.event.quit()
    end)
    smoke = nil
  end
end
-- Where the frame is drawn: its UV square fitted into the window.
local function place()
  local frame = Frames[atlas].frames[editor.index]
  local source = image(frame.sourcePath)
  local w, h = source:getDimensions()
  local r = frame.rect
  local pw, ph = r[3] * w, r[4] * h
  local ww, wh = love.graphics.getDimensions()
  local scale = math.min((ww - 40) / pw, (wh - 120) / ph)
  view = { x = (ww - pw * scale) / 2, y = 90, w = pw * scale, h = ph * scale }
  return frame, source, scale
end
local function uv(x, y)
  return (x - view.x) / view.w, (y - view.y) / view.h
end
function love.draw()
  local lg = love.graphics
  lg.clear(0.12, 0.11, 0.12)
  local frame, source, scale = place()
  local w, h = source:getDimensions()
  local r = frame.rect
  local quad = lg.newQuad(r[1] * w, r[2] * h, r[3] * w, r[4] * h, w, h)
  lg.setColor(1, 1, 1)
  lg.draw(source, quad, view.x, view.y, 0, scale, scale)
  quad:release()
  lg.setColor(1, 1, 1, 0.4)
  lg.rectangle('line', view.x, view.y, view.w, view.h)
  for i, part in ipairs(editor:frame().parts) do
    local c = COLORS[part.zone] or COLORS[false]
    local points = {}
    for k = 1, #part.polygon, 2 do
      points[k] = view.x + part.polygon[k] * view.w
      points[k + 1] = view.y + part.polygon[k + 1] * view.h
    end
    lg.setColor(c[1], c[2], c[3], i == editor.selected and 1 or 0.45)
    lg.setLineWidth(i == editor.selected and 2 or 1)
    lg.polygon('line', points)
    if i == editor.selected then
      for k = 1, #points, 2 do
        local chosen = editor.vertex == (k + 1) / 2
        lg.circle(chosen and 'fill' or 'line', points[k], points[k + 1], chosen and 5 or 4)
      end
    end
  end
  for name, point in pairs(editor:frame().anchors or {}) do
    lg.setColor(1, 0.85, 0.2)
    lg.circle('line', view.x + point[1] * view.w, view.y + point[2] * view.h, 7)
    lg.print(name, view.x + point[1] * view.w + 9, view.y + point[2] * view.h - 7)
  end
  local part = editor:part()
  lg.setColor(1, 1, 1)
  lg.print(
    string.format(
      '%s  frame %d/%d  part %d/%d: %s  zone %s  material %s%s',
      id,
      editor.index,
      #editor.annotation.frames,
      editor.selected,
      #editor:frame().parts,
      part.id,
      tostring(part.zone),
      part.material,
      part.hittable == false and '  (not hittable)' or ''
    ),
    20,
    20
  )
  lg.print(status, 20, 44)
  lg.print(
    'Left/Right frame  Tab part  drag vertex  I insert  Del remove  N new  X drop  Z zone  M material  H head anchor  Ctrl+Z undo  P problems  S save',
    20,
    64
  )
end
function love.mousepressed(x, y, button)
  if button ~= 1 or not view then
    return
  end
  local u, v = uv(x, y)
  if editor:pick(u, v, 12 / view.w) then
    editor:grab()
    dragging = true
  end
end
function love.mousemoved(x, y)
  if dragging then
    editor:move(uv(x, y))
  end
end
function love.mousereleased()
  dragging = false
end
local function save()
  local dir = require('src.app.workspace').directory(root .. '/..') .. '/anatomy'
  require('qa.directory').ensure(dir)
  local path = dir .. '/' .. id .. '.lua'
  local file = assert(io.open(path, 'w'))
  file:write(editor:text())
  file:close()
  status = 'saved ' .. path .. ' (copy into game/src/content/art/anatomy/ and list it in index.lua)'
end
function love.keypressed(key)
  local ctrl = love.keyboard.isDown('lctrl', 'rctrl')
  if key == 'right' then
    editor:step(1)
  elseif key == 'left' then
    editor:step(-1)
  elseif key == 'tab' then
    editor:cycle(love.keyboard.isDown('lshift', 'rshift') and -1 or 1)
  elseif key == 'i' then
    editor:insert()
  elseif key == 'delete' or key == 'backspace' then
    editor:remove()
  elseif key == 'n' then
    editor:add('part' .. (#editor:frame().parts + 1), 'torso', 'flesh')
  elseif key == 'x' then
    editor:drop()
  elseif key == 'z' and ctrl then
    editor:undo()
  elseif key == 'z' then
    editor:zone()
  elseif key == 'm' then
    local current, next = editor:part().material, 1
    for i, name in ipairs(Materials) do
      if name == current then
        next = i % #Materials + 1
      end
    end
    editor:material(Materials[next])
  elseif key == 'h' and view then
    local u, v = uv(love.mouse.getPosition())
    editor:anchor('head', u, v)
  elseif key == 'p' then
    local problems = editor:problems()
    status = #problems == 0 and 'no problems' or (#problems .. ': ' .. problems[1])
  elseif key == 's' then
    save()
  elseif key == 'escape' then
    love.event.quit()
  end
end

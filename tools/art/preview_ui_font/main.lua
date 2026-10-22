local lg=love.graphics
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
function love.load()
 local root=assert(os.getenv('SIGIL_FONT_SOURCE'));local Bitmap=assert(loadstring(read(root..'/src/ui/fonts/bitmap_font.lua')))()
 local catalog=assert(loadstring(read(root..'/assets/fonts/painted/catalog.lua')))();local fonts={}
 local function img(p)return lg.newImage(love.filesystem.newFileData(read(root..'/'..p),p))end
 for _,s in ipairs({12,16,18,24,28,36,48,64,94})do local m=catalog.sizes[s];fonts[s]=Bitmap.new(m,img(m.image))end
 local canvas=lg.newCanvas(1280,900);canvas:setFilter('nearest','nearest');lg.setCanvas(canvas);lg.clear(.025,.02,.018);lg.setColor(.48,.46,.42);lg.draw(img('assets/art/parchment-v08.png'),0,0,0,1280/1536,900/1024)
 local ivory={.94,.89,.76};local gold={.91,.67,.33}
 local function text(t,x,y,s,c)
  local font=fonts[s];local b=font:getInk(t);assert(font:hasGlyphs(t),'Missing illustrated character')
  assert(x+b.x>=72 and x+b.x+b.w<=1208 and y-font.meta.top+b.y>=40 and y-font.meta.top+b.y+b.h<=860,'Specimen outside writing field: '..t)
  font:draw(t,x,y-font.meta.top,c or ivory)
 end
 text('ALFABET ILUSTROWANY / SIGIL',100,65,36,gold)
 text('Rzeźbiona kość, stary pigment i ślady rdzy. Litery z obrazów.',100,120,24,ivory)
 text('I P T',100,180,94,ivory);text('i p t',680,180,94,ivory)
 text('WERSALIKI',100,325,16,gold);text('MAŁE LITERY',680,325,16,gold)
 text('ABCDEFGHIJKLM',100,370,36,ivory);text('abcdefghijklm',680,370,36,ivory)
 text('NOPQRSTUVWXYZ',100,425,36,ivory);text('nopqrstuvwxyz',680,425,36,ivory)
 text('ĄĆĘŁŃÓŚŹŻ',100,485,36,ivory);text('ąćęłńóśźż',680,485,36,ivory)
 text('0123456789 % /',100,555,36,gold);text('. , : ; ! ? + - ( ) [ ] ° ∞ = ×',680,555,24,ivory)
 text('CZYTELNOŚĆ W GRZE',100,650,18,gold)
 text('Przygotowanie / FALA 1 / 4. Cztery fale i strażnik.',100,694,16,ivory)
 text('[E] ŻAR / ODPOCZYNEK I HANDEL. Cena: 12 dusz. Zapas: 28.',100,732,16,ivory)
 text('ZDROWIE 100%',100,776,18,{.95,.40,.30});text('OSŁONA 40%',430,776,18,{.65,.82,.85});text('Q FALA DUSZ',760,776,18,{.80,.67,.85})
 text('Źródła: trzy arkusze alfabetu i osobny arkusz cyfr. Zachowane proporcje każdej litery.',100,828,16,ivory)
 local function save(c,name)local data=c:newImageData();local path=root..'/../qa-v08-ui/'..name;local f=assert(io.open(path,'wb'));f:write(data:encode('png'):getString());f:close();data:release();print(path)end
 lg.setCanvas();save(canvas,'painted-typography-preview.png')
 local small=lg.newCanvas(960,675);lg.setCanvas(small);lg.clear(0,0,0,0);lg.setColor(1,1,1);lg.draw(canvas,0,0,0,.75,.75);lg.setCanvas();save(small,'painted-typography-small.png');love.event.quit()
end

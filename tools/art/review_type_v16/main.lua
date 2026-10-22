function love.load()
 local root=assert(os.getenv('SIGIL_FONT_SOURCE'))
 local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
 table.insert(package.loaders,1,function(name)
  if name:find('^src%.')or name:find('^assets%.')or name:find('^qa%.')then
   local path=root..'/'..name:gsub('%.','/')..'.lua'
   return assert(loadstring(read(path),path))
  end
 end)
 local image=love.graphics.newImage;local data=love.image.newImageData
 local function file(p)return love.filesystem.newFileData(read(root..'/'..p),p)end
 love.graphics.newImage=function(p,...)if type(p)=='string'then p=file(p)end;return image(p,...)end
 love.image.newImageData=function(p,...)if type(p)=='string'then p=file(p)end;return data(p,...)end
 local ok,err=xpcall(function()
  local count=require('qa.reviews.typography_review').run(root..'/../work/qa-typography-v16')
  print('PASS '..count..' illustrated typography checks; two specimens.')
 end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end

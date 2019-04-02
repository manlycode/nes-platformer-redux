local nintaco = require("nintaco")

STRING = "Hello, World!"
  
SPRITE_ID = 123
SPRITE_SIZE = 32
  
spriteX = 0
spriteY = 8
spriteVx = 1
spriteVy = 1
  
local function apiEnabled()
  print("API enabled")
  
  local sprite = { }
  for y = 0, SPRITE_SIZE - 1 do
    local Y = y - SPRITE_SIZE / 2 + 0.5
    for x = 0, SPRITE_SIZE - 1 do
      local X = x - SPRITE_SIZE / 2 + 0.5
      sprite[SPRITE_SIZE * y + x + 1] = (X * X + Y * Y 
          <= SPRITE_SIZE * SPRITE_SIZE / 4) and nintaco.Colors.ORANGE or -1 
    end
  end
  nintaco.createSprite(SPRITE_ID, SPRITE_SIZE, SPRITE_SIZE, sprite)
  
  strWidth = nintaco.getStringWidth(STRING, false)
  strX = (256 - strWidth) / 2
  strY = (240 - 8) / 2
end
  
local function apiDisabled()
  print("API disabled")
end
  
local function dispose()
  print("API stopped")
end
  
local function statusChanged(message)
  print("Status message: " .. message)
end
  
local function renderFinished()
  nintaco.drawSprite(SPRITE_ID, spriteX, spriteY)
  if spriteX + SPRITE_SIZE == 255 then
    spriteVx = -1
  elseif spriteX == 0 then
    spriteVx = 1
  end
  if spriteY + SPRITE_SIZE == 231 then
    spriteVy = -1
  elseif spriteY == 8 then
    spriteVy = 1
  end
  spriteX = spriteX + spriteVx
  spriteY = spriteY + spriteVy
      
  nintaco.setColor(nintaco.Colors.DARK_BLUE)
  nintaco.fillRect(strX - 1, strY - 1, strWidth + 2, 9)
  nintaco.setColor(nintaco.Colors.BLUE)
  nintaco.drawRect(strX - 2, strY - 2, strWidth + 3, 10)
  nintaco.setColor(nintaco.Colors.WHITE)
  nintaco.drawString(STRING, strX, strY, false)
end

nintaco.initRemoteAPI("localhost", 9999)
nintaco.addFrameListener(renderFinished)
nintaco.addStatusListener(statusChanged)
nintaco.addActivateListener(apiEnabled)
nintaco.addDeactivateListener(apiDisabled)
nintaco.addStopListener(dispose)
nintaco.run()
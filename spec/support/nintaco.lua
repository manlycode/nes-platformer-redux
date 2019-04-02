local socket = require("socket")

local nintaco = {}

local ARRAY_LENGTH = 1024

local EVENT_REQUEST = 255
local EVENT_RESPONSE = 254
local HEARTBEAT = 253
local READY = 252
local RETRY_SECONDS = 1

local client = nil
local clientAlive = false
local buffer = ""
local listenerIDs = {}
local listenerObjects = {}
local host = nil
local port = 0
local nextID = 0
local running = false

nintaco.Colors = {
  GRAY = 0x00,
  DARK_BLUE = 0x01,
  DARK_INDIGO = 0x02,
  DARK_VIOLET = 0x03,
  DARK_MAGENTA = 0x04,
  DARK_RED = 0x05,
  DARK_ORANGE = 0x06,
  DARK_BROWN = 0x07,
  DARK_OLIVE = 0x08,
  DARK_CHARTREUSE = 0x09,
  DARK_GREEN = 0x0A,
  DARK_MINT = 0x0B,
  DARK_CYAN = 0x0C,
  BLACKER_THAN_BLACK = 0x0D,
  BLACK3 = 0x0E,
  BLACK = 0x0F,

  LIGHT_GRAY = 0x10,
  BLUE = 0x11,
  INDIGO = 0x12,
  VIOLET = 0x13,
  MAGENTA = 0x14,
  RED = 0x15,
  ORANGE = 0x16,
  BROWN = 0x17,
  OLIVE = 0x18,
  CHARTREUSE = 0x19,
  GREEN = 0x1A,
  MINT = 0x1B,
  CYAN = 0x1C,
  BLACK2 = 0x1D,
  BLACK4 = 0x1E,
  BLACK5 = 0x1F,

  WHITE = 0x20,
  LIGHT_BLUE = 0x21,
  LIGHT_INDIGO = 0x22,
  LIGHT_VIOLET = 0x23,
  LIGHT_MAGENTA = 0x24,
  LIGHT_RED = 0x25,
  LIGHT_ORANGE = 0x26,
  LIGHT_BROWN = 0x27,
  LIGHT_OLIVE = 0x28,
  LIGHT_CHARTREUSE = 0x29,
  LIGHT_GREEN = 0x2A,
  LIGHT_MINT = 0x2B,
  LIGHT_CYAN = 0x2C,
  DARK_GRAY = 0x2D,
  BLACK6 = 0x2E,
  BLACK7 = 0x2F,  

  WHITE2 = 0x30,
  PALE_BLUE = 0x31,
  PALE_INDIGO = 0x32,
  PALE_VIOLET = 0x33,
  PALE_MAGENTA = 0x34,
  PALE_RED = 0x35,
  PALE_ORANGE = 0x36,
  CREAM = 0x37,
  YELLOW = 0x38,
  PALE_CHARTREUSE = 0x39,
  PALE_GREEN = 0x3A,
  PALE_MINT = 0x3B,
  PALE_CYAN = 0x3C,  
  PALE_GRAY = 0x3D,
  BLACK8 = 0x3E,
  BLACK9 = 0x3F,
}

nintaco.AccessPointType = {
  PreRead = 0,
  Read = 1,
  PreWrite = 2,
  PostWrite = 3,
  PreExecute = 4,
  PostExecute = 5,  
}

local EventTypes = {  
  Activate = 1,
  Deactivate = 3,
  Stop = 5,
  Access = 9,  
  Controllers = 11,  
  Frame = 13,  
  Scanline = 15,  
  ScanlineCycle = 17,  
  SpriteZero = 19,  
  Status = 21,
}

local EVENT_TYPES = { 
  EventTypes.Activate, 
  EventTypes.Deactivate, 
  EventTypes.Stop, 
  EventTypes.Access, 
  EventTypes.Controllers, 
  EventTypes.Frame, 
  EventTypes.Scanline, 
  EventTypes.ScanlineCycle, 
  EventTypes.SpriteZero, 
  EventTypes.Status 
}

nintaco.GamepadButtons = {
  A = 0,
  B = 1,
  Select = 2,
  Start = 3,
  Up = 4,
  Down = 5,
  Left = 6,
  Right = 7,  
}

local function newAccessPoint(listener, accessPointType, minAddress, maxAddress, bank)
  maxAddress = maxAddress or -1
  bank = bank or -1
  local accessPoint = { 
    listener = listener, 
    accessPointType = accessPointType, 
    bank = bank,
  }
  if maxAddress < 0 then
    accessPoint.minAddress = minAddress
    accessPoint.maxAddress = minAddress
  elseif minAddress <= maxAddress then
    accessPoint.minAddress = minAddress
    accessPoint.maxAddress = maxAddress
  else
    accessPoint.minAddress = maxAddress
    accessPoint.maxAddress = minAddress
  end
  return accessPoint
end

local function newScanlineCyclePoint(listener, scanline, scanlineCycle)
  return {
    listener = listener,
    scanline = scanline,
    scanlineCycle = scanlineCycle,
  }
end

local function newScanlinePoint(listener, scanline)
  return {
    listener = listener,
    scanline = scanline,
  }
end

local function writeByteString(str)
  if clientAlive and str ~= nil then
    buffer = buffer .. str  
  end
end

local function readByteString(bytes)
  local str = nil
  if clientAlive then
    str = client:receive(bytes)
    if not str then
      clientAlive = false
    end
  end
  return str
end

local function writeByte(value)
  writeByteString(string.char(value % 256))
end 
 
local function readByte()  
  local str = readByteString(1)
  if str ~= nil and #str == 1 then
    return string.byte(str, 1)
  else
    clientAlive = false
    return -1
  end
end

local function writeInt(value)
  writeByteString(string.char(
      math.floor(value / 16777216) % 256, 
      math.floor(value / 65536) % 256, 
      math.floor(value / 256) % 256, 
      value % 256))
end

local function readInt()
  local value = -1
  local str = readByteString(4)  
  if str ~= nil and #str == 4 then
    local b1, b2, b3, b4 = string.byte(str, 1, 4)
    value = (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
    if value > 2147483647 then
      value = value - 4294967296
    end
  else
    clientAlive = false
  end
  return value
end

local function writeIntArray(array)
  writeInt(#array)
  for i = 1, #array do
    writeInt(array[i])
  end
end
  
local function readIntArray(array)
  local length = readInt()
  if length < 0 or length > #array then
    client:close()
    clientAlive = false
    return -1
  end
  for i = 1, length do
    array[i] = readInt()
  end
  return length
end

local function writeBoolean(value)
  writeByte(value and 1 or 0)
end
  
local function readBoolean()
  return readByte() ~= 0
end

local function writeChar(value)
  writeByteString(value)
end
  
local function readChar()
  local c = readByteString(1)
  if c ~= nil and #c == 1 then
    return c
  else
    return nil
  end
end

local function writeCharArray(array)
  writeInt(#array)
  for i = 1, #array do
    writeChar(array[i])
  end
end
  
local function readCharArray(array)
  local length = readInt()
  if length < 0 or length > #array then
    client:close()
    clientAlive = false
    return -1
  end
  for i = 1, length do
    array[i] = readChar()
  end
  return length
end

local function writeString(str)
  local length = string.len(str)
  writeInt(length)
  for i = 1, length do
    writeChar(string.sub(str, i, i))
  end
end
  
local function readString()
  local length = readInt()
  if length < 0 or length > ARRAY_LENGTH then
    client:close()
    clientAlive = false
    return nil
  end
  s = ""
  for i = 1, length do
    s = s .. readChar()
  end
  return s
end
  
local function writeStringArray(array)
  writeInt(#array)
  for i = 1, #array do
    writeString(array[i])
  end
end
  
local function readStringArray(array)
  local length = readInt()
  if length < 0 or length > #array then
    client:close()
    clientAlive = false
    return -1
  end
  for i = 1, length do
    array[i] = readString()
  end
  return length
end

local function readDynamicStringArray()
  local length = readInt()
  if length < 0 or length > ARRAY_LENGTH then
    client:close()
    clientAlive = false
    return nil
  end
  array = {}
  for i = 1, length do
    array[i] = readString()
  end
  return array 
end
  
local function flush()
  if clientAlive and not client:send(buffer) then
    clientAlive = false
  end
  buffer = ""
end

local function getListeners(eventType) 
  local n = 0
  local listeners = {}
  for k, v in pairs(listenerObjects[eventType]) do
    n = n + 1
    listeners[n] = v
  end
  return listeners
end

local function fireDeactivated()  
  local listeners = getListeners(EventTypes.Deactivate)
  for k, v in pairs(listeners) do
    v()
  end
end
  
local function fireStatusChanged(message, a, b) 
  local msg = string.format(message, a, b)
  local listeners = getListeners(EventTypes.Status)
  for k, v in pairs(listeners) do
    v(msg)
  end
end

local function sendListener(listenerID, eventType, listenerObject)
  if clientAlive then  
    writeByte(eventType)
    writeInt(listenerID)
    if eventType == EventTypes.Access then
      writeInt(listenerObject.accessPointType)
      writeInt(listenerObject.minAddress)
      writeInt(listenerObject.maxAddress)
      writeInt(listenerObject.bank)
    elseif eventType == EventTypes.Scanline then
      writeInt(listenerObject.scanline)
    elseif eventType == EventTypes.ScanlineCycle then
      writeInt(listenerObject.scanline);
      writeInt(listenerObject.scanlineCycle);
    end
    flush()
  end
end

local function sendListeners()
  for k1, v1 in pairs(listenerObjects) do
    for k2, v2 in pairs(v1) do
      sendListener(k2, k1, v2)
    end
  end      
end

local function addListenerObject(listener, eventType, listenerObject)
  listenerObject = listenerObject or listener
  nextID = nextID + 1
  local listenerID = nextID
  listenerIDs[listener] = listenerID
  listenerObjects[eventType][listenerID] = listenerObject
  return listenerID;
end

local function addListener(listener, eventType)
  if listener ~= nil then      
    sendListener(addListenerObject(listener, eventType), eventType, listener)
  end
end

local function removeListenerObject(listener, eventType)
  local listenerID = listenerIDs[listener]
  listenerIDs[listener] = nil
  if listenerID ~= nil then
    listenerObjects[eventType][listenerID] = nil
    return listenerID
  else
    return -1
  end
end

local function removeListener(listener, eventType, methodValue)
  if listener ~= nil then
    local listenerID = removeListenerObject(listener, eventType)
    if listenerID >= 0 and clientAlive then
      writeByte(methodValue)
      writeInt(listenerID)
      flush();
    end
  end
end
  
local function sendReady()
  if clientAlive then
    writeByte(READY)
    flush()
  end
end

local function probeEvents()
    
  writeByte(EVENT_REQUEST)
  flush()
  
  local eventType = readByte()
  
  if eventType < 0 then
    clientAlive = false
    return
  elseif eventType == HEARTBEAT then
    writeByte(EVENT_RESPONSE)
    flush()
    return
  end
  
  local objs = listenerObjects[eventType];
  if objs == nil then
    clientAlive = false
    return
  end
  
  local obj = objs[readInt()]
  
  if obj ~= nil then
    if eventType == EventTypes.Activate 
        or eventType == EventTypes.Deactivate 
        or eventType == EventTypes.Stop 
        or eventType == EventTypes.Controllers 
        or eventType == EventTypes.Frame then
      obj()
      writeByte(EVENT_RESPONSE)
    elseif eventType == EventTypes.Access then
      local t = readInt()
      local address = readInt()
      local value = readInt()
      local result = obj.listener(t, address, value)
      writeByte(EVENT_RESPONSE)
      writeInt(result)
    elseif eventType == EventTypes.Scanline then 
      obj.listener(readInt())
      writeByte(EVENT_RESPONSE)
    elseif eventType == EventTypes.ScanlineCycle then
      local scanline = readInt()
      local scanlineCycle = readInt()
      local address = readInt()
      local rendering = readBoolean()
      obj.listener(scanline, scanlineCycle, address, rendering);
      writeByte(EVENT_RESPONSE)
    elseif eventType == EventTypes.SpriteZero then
      local scanline = readInt()
      local scanlineCycle = readInt()
      obj(scanline, scanlineCycle)
      writeByte(EVENT_RESPONSE)
    elseif eventType == EventTypes.Status then    
      obj(readString())
      writeByte(EVENT_RESPONSE)
    else
      clientAlive = false
    end     
  end
    
  flush()
end

function nintaco.run() 
  if running then
    return
  else
    running = true
  end
  while true do
    fireStatusChanged("Connecting to %s:%d...", host, port)    
    client = socket.connect(host, port)
    if client == nil then
      fireStatusChanged("Failed to establish connection.")
    else      
      fireStatusChanged("Connection established.")
      clientAlive = true
      buffer = ""
      sendListeners()
      sendReady()
      while clientAlive do
        probeEvents()
      end
      client:close()
      client = nil
      buffer = ""
      fireDeactivated()
      fireStatusChanged("Disconnected.")      
    end
    socket.sleep(RETRY_SECONDS)    
  end 
end

function nintaco.addActivateListener(listener)
  addListener(listener, EventTypes.Activate)
end

function nintaco.removeActivateListener(listener)
  removeListener(listener, EventTypes.Activate, 2)
end

function nintaco.addDeactivateListener(listener)
  addListener(listener, EventTypes.Deactivate)
end

function nintaco.removeDeactivateListener(listener)
  removeListener(listener, EventTypes.Deactivate, 4)
end

function nintaco.addStopListener(listener)
  addListener(listener, EventTypes.Stop)
end

function nintaco.removeStopListener(listener)
  removeListener(listener, EventTypes.Stop, 6)
end
  
function nintaco.addAccessPointListener(listener, accessPointType, minAddress, maxAddress, bank)
  maxAddress = maxAddress or -1
  bank = bank or -1    
  if listener ~= nil then
    local point = newAccessPoint(listener, accessPointType, minAddress, maxAddress, bank)
    sendListener(addListenerObject(listener, EventTypes.Access, point), EventTypes.Access, point)
  end
end

function nintaco.removeAccessPointListener(listener)
  removeListener(listener, EventTypes.Access, 10)
end

function nintaco.addControllersListener(listener)
  addListener(listener, EventTypes.Controllers)
end

function nintaco.removeControllersListener(listener)
  removeListener(listener, EventTypes.Controllers, 12)
end

function nintaco.addFrameListener(listener)
  addListener(listener, EventTypes.Frame)
end

function nintaco.removeFrameListener(listener)
  removeListener(listener, EventTypes.Frame, 14)
end
  
function nintaco.addScanlineListener(listener, scanline)    
  if listener ~= nil then
    local point = newScanlinePoint(listener, scanline)
    sendListener(addListenerObject(listener, EventTypes.Scanline, point), EventTypes.Scanline, 
        point)
  end
end

function nintaco.removeScanlineListener(listener)
  removeListener(listener, EventTypes.Scanline, 16)
end
  
function nintaco.addScanlineCycleListener(listener, scanline, scanlineCycle)    
  if listener ~= nil then
    local point = newScanlineCyclePoint(listener, scanline, scanlineCycle)
    sendListener(addListenerObject(listener, EventTypes.ScanlineCycle, point), 
        EventTypes.ScanlineCycle, point)
  end
end
  
function nintaco.removeScanlineCycleListener(listener)
  removeListener(listener, EventTypes.ScanlineCycle, 18)
end
  
function nintaco.addSpriteZeroListener(listener)
  addListener(listener, EventTypes.SpriteZero)
end

function nintaco.removeSpriteZeroListener(listener)
  removeListener(listener, EventTypes.SpriteZero, 20)
end

function nintaco.addStatusListener(listener)
  addListener(listener, EventTypes.Status)
end

function nintaco.removeStatusListener(listener)
  removeListener(listener, EventTypes.Status, 22)
end

function nintaco.getPixels(pixels)
  writeByte(119)
  flush()
  readIntArray(pixels)
end

function nintaco.initRemoteAPI(_host, _port)
  host = _host
  port = _port
  for i = 1, #EVENT_TYPES do
    listenerObjects[EVENT_TYPES[i]] = {}
  end
end

-- THIS IS AUTOGENERATED. DO NOT MODIFY THE CODE BELOW.

function nintaco.setPaused(paused)
  if clientAlive then
    writeByte(23)
    writeBoolean(paused)
    flush()
  end
end

function nintaco.isPaused()
  if clientAlive then
    writeByte(24)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.getFrameCount()
  if clientAlive then
    writeByte(25)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.getA()
  if clientAlive then
    writeByte(26)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setA(A)
  if clientAlive then
    writeByte(27)
    writeInt(A)
    flush()
  end
end

function nintaco.getS()
  if clientAlive then
    writeByte(28)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setS(S)
  if clientAlive then
    writeByte(29)
    writeInt(S)
    flush()
  end
end

function nintaco.getPC()
  if clientAlive then
    writeByte(30)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setPC(PC)
  if clientAlive then
    writeByte(31)
    writeInt(PC)
    flush()
  end
end

function nintaco.getX()
  if clientAlive then
    writeByte(32)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setX(X)
  if clientAlive then
    writeByte(33)
    writeInt(X)
    flush()
  end
end

function nintaco.getY()
  if clientAlive then
    writeByte(34)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setY(Y)
  if clientAlive then
    writeByte(35)
    writeInt(Y)
    flush()
  end
end

function nintaco.getP()
  if clientAlive then
    writeByte(36)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setP(P)
  if clientAlive then
    writeByte(37)
    writeInt(P)
    flush()
  end
end

function nintaco.isN()
  if clientAlive then
    writeByte(38)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setN(N)
  if clientAlive then
    writeByte(39)
    writeBoolean(N)
    flush()
  end
end

function nintaco.isV()
  if clientAlive then
    writeByte(40)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setV(V)
  if clientAlive then
    writeByte(41)
    writeBoolean(V)
    flush()
  end
end

function nintaco.isD()
  if clientAlive then
    writeByte(42)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setD(D)
  if clientAlive then
    writeByte(43)
    writeBoolean(D)
    flush()
  end
end

function nintaco.isI()
  if clientAlive then
    writeByte(44)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setI(I)
  if clientAlive then
    writeByte(45)
    writeBoolean(I)
    flush()
  end
end

function nintaco.isZ()
  if clientAlive then
    writeByte(46)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setZ(Z)
  if clientAlive then
    writeByte(47)
    writeBoolean(Z)
    flush()
  end
end

function nintaco.isC()
  if clientAlive then
    writeByte(48)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setC(C)
  if clientAlive then
    writeByte(49)
    writeBoolean(C)
    flush()
  end
end

function nintaco.getPPUv()
  if clientAlive then
    writeByte(50)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setPPUv(v)
  if clientAlive then
    writeByte(51)
    writeInt(v)
    flush()
  end
end

function nintaco.getPPUt()
  if clientAlive then
    writeByte(52)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setPPUt(t)
  if clientAlive then
    writeByte(53)
    writeInt(t)
    flush()
  end
end

function nintaco.getPPUx()
  if clientAlive then
    writeByte(54)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setPPUx(x)
  if clientAlive then
    writeByte(55)
    writeInt(x)
    flush()
  end
end

function nintaco.isPPUw()
  if clientAlive then
    writeByte(56)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setPPUw(w)
  if clientAlive then
    writeByte(57)
    writeBoolean(w)
    flush()
  end
end

function nintaco.getCameraX()
  if clientAlive then
    writeByte(58)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setCameraX(scrollX)
  if clientAlive then
    writeByte(59)
    writeInt(scrollX)
    flush()
  end
end

function nintaco.getCameraY()
  if clientAlive then
    writeByte(60)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setCameraY(scrollY)
  if clientAlive then
    writeByte(61)
    writeInt(scrollY)
    flush()
  end
end

function nintaco.getScanline()
  if clientAlive then
    writeByte(62)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.getDot()
  if clientAlive then
    writeByte(63)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.isSpriteZeroHit()
  if clientAlive then
    writeByte(64)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setSpriteZeroHit(sprite0Hit)
  if clientAlive then
    writeByte(65)
    writeBoolean(sprite0Hit)
    flush()
  end
end

function nintaco.getScanlineCount()
  if clientAlive then
    writeByte(66)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.requestInterrupt()
  if clientAlive then
    writeByte(67)
    flush()
  end
end

function nintaco.acknowledgeInterrupt()
  if clientAlive then
    writeByte(68)
    flush()
  end
end

function nintaco.peekCPU(address)
  if clientAlive then
    writeByte(69)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.readCPU(address)
  if clientAlive then
    writeByte(70)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writeCPU(address, value)
  if clientAlive then
    writeByte(71)
    writeInt(address)
    writeInt(value)
    flush()
  end
end

function nintaco.peekCPU16(address)
  if clientAlive then
    writeByte(72)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.readCPU16(address)
  if clientAlive then
    writeByte(73)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writeCPU16(address, value)
  if clientAlive then
    writeByte(74)
    writeInt(address)
    writeInt(value)
    flush()
  end
end

function nintaco.peekCPU32(address)
  if clientAlive then
    writeByte(75)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.readCPU32(address)
  if clientAlive then
    writeByte(76)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writeCPU32(address, value)
  if clientAlive then
    writeByte(77)
    writeInt(address)
    writeInt(value)
    flush()
  end
end

function nintaco.readPPU(address)
  if clientAlive then
    writeByte(78)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writePPU(address, value)
  if clientAlive then
    writeByte(79)
    writeInt(address)
    writeInt(value)
    flush()
  end
end

function nintaco.readPaletteRAM(address)
  if clientAlive then
    writeByte(80)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writePaletteRAM(address, value)
  if clientAlive then
    writeByte(81)
    writeInt(address)
    writeInt(value)
    flush()
  end
end

function nintaco.readOAM(address)
  if clientAlive then
    writeByte(82)
    writeInt(address)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writeOAM(address, value)
  if clientAlive then
    writeByte(83)
    writeInt(address)
    writeInt(value)
    flush()
  end
end

function nintaco.readGamepad(gamepad, button)
  if clientAlive then
    writeByte(84)
    writeInt(gamepad)
    writeInt(button)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.writeGamepad(gamepad, button, value)
  if clientAlive then
    writeByte(85)
    writeInt(gamepad)
    writeInt(button)
    writeBoolean(value)
    flush()
  end
end

function nintaco.isZapperTrigger()
  if clientAlive then
    writeByte(86)
    flush()
    return readBoolean()
  end
  return false
end

function nintaco.setZapperTrigger(zapperTrigger)
  if clientAlive then
    writeByte(87)
    writeBoolean(zapperTrigger)
    flush()
  end
end

function nintaco.getZapperX()
  if clientAlive then
    writeByte(88)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setZapperX(x)
  if clientAlive then
    writeByte(89)
    writeInt(x)
    flush()
  end
end

function nintaco.getZapperY()
  if clientAlive then
    writeByte(90)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setZapperY(y)
  if clientAlive then
    writeByte(91)
    writeInt(y)
    flush()
  end
end

function nintaco.setColor(color)
  if clientAlive then
    writeByte(92)
    writeInt(color)
    flush()
  end
end

function nintaco.getColor()
  if clientAlive then
    writeByte(93)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.setClip(x, y, width, height)
  if clientAlive then
    writeByte(94)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    flush()
  end
end

function nintaco.clipRect(x, y, width, height)
  if clientAlive then
    writeByte(95)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    flush()
  end
end

function nintaco.resetClip()
  if clientAlive then
    writeByte(96)
    flush()
  end
end

function nintaco.copyArea(x, y, width, height, dx, dy)
  if clientAlive then
    writeByte(97)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeInt(dx)
    writeInt(dy)
    flush()
  end
end

function nintaco.drawLine(x1, y1, x2, y2)
  if clientAlive then
    writeByte(98)
    writeInt(x1)
    writeInt(y1)
    writeInt(x2)
    writeInt(y2)
    flush()
  end
end

function nintaco.drawOval(x, y, width, height)
  if clientAlive then
    writeByte(99)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    flush()
  end
end

function nintaco.drawPolygon(xPoints, yPoints, nPoints)
  if clientAlive then
    writeByte(100)
    writeIntArray(xPoints)
    writeIntArray(yPoints)
    writeInt(nPoints)
    flush()
  end
end

function nintaco.drawPolyline(xPoints, yPoints, nPoints)
  if clientAlive then
    writeByte(101)
    writeIntArray(xPoints)
    writeIntArray(yPoints)
    writeInt(nPoints)
    flush()
  end
end

function nintaco.drawRect(x, y, width, height)
  if clientAlive then
    writeByte(102)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    flush()
  end
end

function nintaco.drawRoundRect(x, y, width, height, arcWidth, arcHeight)
  if clientAlive then
    writeByte(103)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeInt(arcWidth)
    writeInt(arcHeight)
    flush()
  end
end

function nintaco.draw3DRect(x, y, width, height, raised)
  if clientAlive then
    writeByte(104)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeBoolean(raised)
    flush()
  end
end

function nintaco.drawArc(x, y, width, height, startAngle, arcAngle)
  if clientAlive then
    writeByte(105)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeInt(startAngle)
    writeInt(arcAngle)
    flush()
  end
end

function nintaco.fill3DRect(x, y, width, height, raised)
  if clientAlive then
    writeByte(106)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeBoolean(raised)
    flush()
  end
end

function nintaco.fillArc(x, y, width, height, startAngle, arcAngle)
  if clientAlive then
    writeByte(107)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeInt(startAngle)
    writeInt(arcAngle)
    flush()
  end
end

function nintaco.fillOval(x, y, width, height)
  if clientAlive then
    writeByte(108)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    flush()
  end
end

function nintaco.fillPolygon(xPoints, yPoints, nPoints)
  if clientAlive then
    writeByte(109)
    writeIntArray(xPoints)
    writeIntArray(yPoints)
    writeInt(nPoints)
    flush()
  end
end

function nintaco.fillRect(x, y, width, height)
  if clientAlive then
    writeByte(110)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    flush()
  end
end

function nintaco.fillRoundRect(x, y, width, height, arcWidth, arcHeight)
  if clientAlive then
    writeByte(111)
    writeInt(x)
    writeInt(y)
    writeInt(width)
    writeInt(height)
    writeInt(arcWidth)
    writeInt(arcHeight)
    flush()
  end
end

function nintaco.drawChar(c, x, y)
  if clientAlive then
    writeByte(112)
    writeChar(c)
    writeInt(x)
    writeInt(y)
    flush()
  end
end

function nintaco.drawChars(data, offset, length, x, y, monospaced)
  if clientAlive then
    writeByte(113)
    writeCharArray(data)
    writeInt(offset)
    writeInt(length)
    writeInt(x)
    writeInt(y)
    writeBoolean(monospaced)
    flush()
  end
end

function nintaco.drawString(str, x, y, monospaced)
  if clientAlive then
    writeByte(114)
    writeString(str)
    writeInt(x)
    writeInt(y)
    writeBoolean(monospaced)
    flush()
  end
end

function nintaco.createSprite(id, width, height, pixels)
  if clientAlive then
    writeByte(115)
    writeInt(id)
    writeInt(width)
    writeInt(height)
    writeIntArray(pixels)
    flush()
  end
end

function nintaco.drawSprite(id, x, y)
  if clientAlive then
    writeByte(116)
    writeInt(id)
    writeInt(x)
    writeInt(y)
    flush()
  end
end

function nintaco.setPixel(x, y, color)
  if clientAlive then
    writeByte(117)
    writeInt(x)
    writeInt(y)
    writeInt(color)
    flush()
  end
end

function nintaco.getPixel(x, y)
  if clientAlive then
    writeByte(118)
    writeInt(x)
    writeInt(y)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.powerCycle()
  if clientAlive then
    writeByte(120)
    flush()
  end
end

function nintaco.reset()
  if clientAlive then
    writeByte(121)
    flush()
  end
end

function nintaco.deleteSprite(id)
  if clientAlive then
    writeByte(122)
    writeInt(id)
    flush()
  end
end

function nintaco.setSpeed(percent)
  if clientAlive then
    writeByte(123)
    writeInt(percent)
    flush()
  end
end

function nintaco.stepToNextFrame()
  if clientAlive then
    writeByte(124)
    flush()
  end
end

function nintaco.showMessage(message)
  if clientAlive then
    writeByte(125)
    writeString(message)
    flush()
  end
end

function nintaco.getWorkingDirectory()
  if clientAlive then
    writeByte(126)
    flush()
    return readString()
  end
  return nil
end

function nintaco.getContentDirectory()
  if clientAlive then
    writeByte(127)
    flush()
    return readString()
  end
  return nil
end

function nintaco.open(fileName)
  if clientAlive then
    writeByte(128)
    writeString(fileName)
    flush()
  end
end

function nintaco.openArchiveEntry(archiveFileName, entryFileName)
  if clientAlive then
    writeByte(129)
    writeString(archiveFileName)
    writeString(entryFileName)
    flush()
  end
end

function nintaco.getArchiveEntries(archiveFileName)
  if clientAlive then
    writeByte(130)
    writeString(archiveFileName)
    flush()
    return readDynamicStringArray()
  end
  return nil
end

function nintaco.getDefaultArchiveEntry(archiveFileName)
  if clientAlive then
    writeByte(131)
    writeString(archiveFileName)
    flush()
    return readString()
  end
  return nil
end

function nintaco.openDefaultArchiveEntry(archiveFileName)
  if clientAlive then
    writeByte(132)
    writeString(archiveFileName)
    flush()
  end
end

function nintaco.close()
  if clientAlive then
    writeByte(133)
    flush()
  end
end

function nintaco.saveState(stateFileName)
  if clientAlive then
    writeByte(134)
    writeString(stateFileName)
    flush()
  end
end

function nintaco.loadState(stateFileName)
  if clientAlive then
    writeByte(135)
    writeString(stateFileName)
    flush()
  end
end

function nintaco.quickSaveState(slot)
  if clientAlive then
    writeByte(136)
    writeInt(slot)
    flush()
  end
end

function nintaco.quickLoadState(slot)
  if clientAlive then
    writeByte(137)
    writeInt(slot)
    flush()
  end
end

function nintaco.setTVSystem(tvSystem)
  if clientAlive then
    writeByte(138)
    writeString(tvSystem)
    flush()
  end
end

function nintaco.getTVSystem()
  if clientAlive then
    writeByte(139)
    flush()
    return readString()
  end
  return nil
end

function nintaco.getDiskSides()
  if clientAlive then
    writeByte(140)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.insertDisk(disk, side)
  if clientAlive then
    writeByte(141)
    writeInt(disk)
    writeInt(side)
    flush()
  end
end

function nintaco.flipDiskSide()
  if clientAlive then
    writeByte(142)
    flush()
  end
end

function nintaco.ejectDisk()
  if clientAlive then
    writeByte(143)
    flush()
  end
end

function nintaco.insertCoin()
  if clientAlive then
    writeByte(144)
    flush()
  end
end

function nintaco.pressServiceButton()
  if clientAlive then
    writeByte(145)
    flush()
  end
end

function nintaco.screamIntoMicrophone()
  if clientAlive then
    writeByte(146)
    flush()
  end
end

function nintaco.glitch()
  if clientAlive then
    writeByte(147)
    flush()
  end
end

function nintaco.getFileInfo()
  if clientAlive then
    writeByte(148)
    flush()
    return readString()
  end
  return nil
end

function nintaco.setFullscreenMode(fullscreenMode)
  if clientAlive then
    writeByte(149)
    writeBoolean(fullscreenMode)
    flush()
  end
end

function nintaco.saveScreenshot()
  if clientAlive then
    writeByte(150)
    flush()
  end
end

function nintaco.addCheat(address, value, compare, description, enabled)
  if clientAlive then
    writeByte(151)
    writeInt(address)
    writeInt(value)
    writeInt(compare)
    writeString(description)
    writeBoolean(enabled)
    flush()
  end
end

function nintaco.removeCheat(address, value, compare)
  if clientAlive then
    writeByte(152)
    writeInt(address)
    writeInt(value)
    writeInt(compare)
    flush()
  end
end

function nintaco.addGameGenie(gameGenieCode, description, enabled)
  if clientAlive then
    writeByte(153)
    writeString(gameGenieCode)
    writeString(description)
    writeBoolean(enabled)
    flush()
  end
end

function nintaco.removeGameGenie(gameGenieCode)
  if clientAlive then
    writeByte(154)
    writeString(gameGenieCode)
    flush()
  end
end

function nintaco.addProActionRocky(proActionRockyCode, description, enabled)
  if clientAlive then
    writeByte(155)
    writeString(proActionRockyCode)
    writeString(description)
    writeBoolean(enabled)
    flush()
  end
end

function nintaco.removeProActionRocky(proActionRockyCode)
  if clientAlive then
    writeByte(156)
    writeString(proActionRockyCode)
    flush()
  end
end

function nintaco.getPrgRomSize()
  if clientAlive then
    writeByte(157)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.readPrgRom(index)
  if clientAlive then
    writeByte(158)
    writeInt(index)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writePrgRom(index, value)
  if clientAlive then
    writeByte(159)
    writeInt(index)
    writeInt(value)
    flush()
  end
end

function nintaco.getChrRomSize()
  if clientAlive then
    writeByte(160)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.readChrRom(index)
  if clientAlive then
    writeByte(161)
    writeInt(index)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.writeChrRom(index, value)
  if clientAlive then
    writeByte(162)
    writeInt(index)
    writeInt(value)
    flush()
  end
end

function nintaco.getStringWidth(str, monospaced)
  if clientAlive then
    writeByte(163)
    writeString(str)
    writeBoolean(monospaced)
    flush()
    return readInt()
  end
  return -1
end

function nintaco.getCharsWidth(chars, monospaced)
  if clientAlive then
    writeByte(164)
    writeCharArray(chars)
    writeBoolean(monospaced)
    flush()
    return readInt()
  end
  return -1
end

return nintaco
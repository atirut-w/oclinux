-- OCLinux kernel by Atirut Wattanamongkol(WattanaGaming)
_G.boot_invoke = nil

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

-- Kernel table containing built-in functions.
kernel = {}
kernel.modules = {}
kernel.display = {
  isInitialized = false,
  resolution = {
    x = 0,
    y = 0
  },

  initialize = function(self)
    if (self.isInitialized) then
      return false
    end
    self.gpu = component.proxy(component.list("gpu")())
    self.resolution.x, self.resolution.y = self.gpu.getResolution()

    self.isInitialized = true
    return true
  end,

  -- A very basic and barebone system for putting texts on the screen.
  simpleBuffer = {
    lineBuffer = {},

    updateScreen = function(self)
      local gpu = kernel.display.gpu
      local resolution = kernel.display.resolution
      if #self.lineBuffer > resolution.y then
        while #self.lineBuffer > resolution.y do
          table.remove(self.lineBuffer, 1)
        end
        -- Scroll instead of redrawing the entire screen. This reduce screen flickering.
        gpu.copy(0, 1, resolution.x, resolution.y, 0, -1)
        gpu.fill(1, resolution.y, resolution.x, 1, " ")
        gpu.set(1, resolution.y, self.lineBuffer[resolution.y])
        return
      end
      gpu.set(1, #self.lineBuffer, self.lineBuffer[#self.lineBuffer])
    end,

    print = function(self, text)
      text = text or ""
      text = tostring(text)
      if text:len() > kernel.display.resolution.x then
        local function split(str, max_line_length)
          local lines = {}
          local line
          str:gsub('(%s*)(%S+)', 
             function(spc, word) 
                if not line or #line + #spc + #word > max_line_length then
                   table.insert(lines, line)
                   line = word
                else
                   line = line..spc..word
                end
             end
          )
          table.insert(lines, line)
          return lines
        end
        for _, line in ipairs(split(text, kernel.display.resolution.x)) do
          self:print(line)
        end
      else
        table.insert(self.lineBuffer, text)
      end
      self:updateScreen()
    end,

    write = function(self, text)
      text = text or ""
      text = tostring(text)
      self.lineBuffer[#self.lineBuffer] = self.lineBuffer[#self.lineBuffer]..text
      self:updateScreen()
    end
  }
}

kernel.threads = {
  coroutines = {},

  new = function(self, func, name, options)
    name = name or ""
    options = options or {}
    local id = #self.coroutines + 1

    local tData = {
      cname = name,
      -- Consider using `coroutine.wrap()`?
      co = coroutine.create(func),
    }
    tData.inputBuffer = options.args or {} -- Rudimentary way to send stuff to the coroutine.
    tData.errHandler = options.errHandler or nil
    tData.stallProtection = options.stallProtection or false -- Temp fix for thread stall crash

    self.coroutines[id] = tData
    return id
  end,
  
  -- FIXME:
  -- If too many threads stall successively, a crash WILL happen when cycling threads.
  -- Either append `computer.pullSignal()` to the end of the loop(significant slowdown) OR
  -- Try to detect the "too long without yielding" result and then do `pullSignal()`
  cycle = function(self)
    for i=1,#self.coroutines do
      local current = self.coroutines[i]
      if coroutine.status(current.co) == "dead" then
        self.coroutines[i] = nil
        return
      end

      local success, result = coroutine.resume(current.co, current.inputBuffer)
      if current.inputBuffer then current.inputBuffer = nil end
      -- Handle values or requests made by the thread.

      if not success and string.find(result, "too long without yielding") then -- TODO: Do some testing
        computer.pullSignal(0.1)
      end
      if not success and current.errHandler then
        current.errHandler(result)
      elseif not success then
        error(result)
      end
      -- if current.stallProtection then computer.pullSignal(0.1) end -- Temp fix for thread stall crash
    end
  end
}

kernel.internal = {
  isInitialized = false,

  readfile = function(file)
    local addr, invoke = computer.getBootAddress(), component.invoke
    local handle = assert(invoke(addr, "open", file), "Requested file "..file.." not found")
    local buffer = ""
    repeat
      local data = invoke(addr, "read", handle, math.huge)
      buffer = buffer .. (data or "")
    until not data
    invoke(addr, "close", handle)
    return buffer
  end,
  
  loadfile = function(file, env)
    return load(kernel.internal.readfile(file), "=" .. file, "bt", env)
  end,

  initialize = function(self)
    if (self.isInitialized) then -- Prevent the function from running again once initialized
      return false
    end
    self.bootAddr = computer.getBootAddress()

    kernel.display:initialize()
    kernel.display.simpleBuffer:print("Loading and executing /sbin/init.lua")

    kernel.threads:new(self.loadfile("/sbin/init.lua", _G), "init", {
      errHandler = function(err) -- Special handler.
        computer.beep(1000, 0.1)
        local print = function(a) kernel.display.simpleBuffer:print(a) end
        print("Error whilst executing init:")
        print("  "..tostring(err))
        print("")
        print("Halted.")
        while true do computer.pullSignal() end
      end
    })

    self.isInitialized = true
    return true
  end
}

kernel.internal:initialize()

while coroutine.status(kernel.threads.coroutines[1].co) ~= "dead" do
  kernel.threads:cycle()
end

kernel.display.simpleBuffer:print("Init has returned.")

-- OCLinux kernel by Atirut Wattanamongkol(WattanaGaming)
_G.boot_invoke = nil

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
-- local unicode = unicode or require('unicode')

-- Kernel table containing built-in functions.
local kernel = {}
kernel.modules = {}
kernel.display = {
  isInitialized = false,
  gpu = nil,
  resolution = {
    w = 0,
    h = 0
  },
  
  initialize = function(self)
    if (self.isInitialized) then
      return false
    end
    self.gpu = component.proxy(component.list("gpu")())
    self.resolution.w, self.resolution.h = self.gpu.getResolution()
    
    self.isInitialized = true
    return true
  end,
  
  -- A very basic and barebone system for putting texts on the screen.
  simpleBuffer = {
    lineBuffer = {},
    
    updateScreen = function(self)
      local gpu = kernel.display.gpu
      local resolution = kernel.display.resolution
      if #self.lineBuffer > resolution.h then
        while #self.lineBuffer > resolution.h do
          table.remove(self.lineBuffer, 1)
        end
        -- Scroll instead of redrawing the entire screen. This reduce screen flickering.
        gpu.copy(0, 1, resolution.w, resolution.h, 0, -1)
        gpu.fill(1, resolution.h, resolution.w, 1, " ")
        gpu.set(1, resolution.h, self.lineBuffer[resolution.h])
        return
      end
      gpu.set(1, #self.lineBuffer, self.lineBuffer[#self.lineBuffer])
    end,
    
    print = function(self, text)
      text = text or ""
      text = tostring(text)
      if text:len() > kernel.display.resolution.w then
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
        for _, line in ipairs(split(text, kernel.display.resolution.w)) do
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
      co = coroutine.create(func),
    }
    tData.inputBuffer = options.args or nil -- Rudimentary way to send stuff to the coroutine.
    tData.errHandler = options.errHandler or nil
    tData.stallProtection = options.stallProtection or false
    
    -- self.coroutines[id] = tData
    table.insert(self.coroutines, id, tData)
    return id
  end,
  
  cycle = function(self)
    for pid=1,#self.coroutines do
      local thread = self.coroutines[pid]
      if thread == nil then
        -- This causes some thread to not continue until another thread yields.
        -- TOOD: Fix thread leak without causing the said problem.
        -- table.remove(self.coroutines, pid)
        goto skip
      elseif coroutine.status(thread.co) == "dead" then
        self.coroutines[pid] = nil
        goto skip
      end

      local cycleStartTime = computer.uptime()
      local success, result = coroutine.resume(thread.co, thread.inputBuffer)
      if thread.inputBuffer then thread.inputBuffer = nil end
      thread.cpuTime = computer.uptime() - cycleStartTime
      
      if not success and (
        string.find(tostring(result), "too long without yielding") or
        result == "pullSignal"
      ) then
        computer.pullSignal(0.1)
      end
      if not success and thread.errHandler then
        thread.errHandler(result)
      elseif not success then
        error(result)
      end
      ::skip::
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

  copy = function(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[kernel.internal.copy(k, s)] = kernel.internal.copy(v, s) end
    return res
  end,
  
  loadfile = function(file, env, isSandbox)
    if isSandbox == true then
      local sandbox = kernel.internal.copy(env)
      sandbox._G = sandbox
      -- sandbox.component = nil
      -- sandbox.computer = nil
      return load(kernel.internal.readfile(file), "=" .. file, "bt", sandbox)
    else
      return load(kernel.internal.readfile(file), "=" .. file, "bt", env)
    end
  end,
  
  initialize = function(self)
    if (self.isInitialized) then -- Prevent the function from running again once initialized
      return false
    end
    self.bootAddr = computer.getBootAddress()
    kernel.display:initialize()

    kernel.display.simpleBuffer:print("Loading and executing /sbin/init.lua")
    kernel.threads:new(self.loadfile("/sbin/init.lua", _G, false), "init", {
      errHandler = function(err) -- Special handler.
        computer.beep(1000, 0.1)
        local print = function(a) kernel.display.simpleBuffer:print(a) end
        print("Error whilst executing init:")
        print("  "..tostring(err))
        print("")
        print("Halted.")
        while true do computer.pullSignal() end
      end,
      sandbox = true
    })
    
    self.isInitialized = true
    return true
  end
}

system = {
  deviceInfo = (function() return computer.getDeviceInfo() end)(),
  architecture = (function() return computer.getArchitecture() end)(),
  bootAddress = (function() return computer.getBootAddress() end)(),
  display = {
    getGPU = function() return kernel.display.gpu end,
    simplePrint = function(message) kernel.display.simpleBuffer:print(message) end,
    simpleWrite = function(message) kernel.display.simpleBuffer:print(message) end,
  },
  kernel = {
    readfile = function(file) return kernel.internal.readfile(file) end,
    initModule = function(name, data, isSandbox)
      assert(name ~= "", "Module name cannot be blank or nil")
      assert(data ~= "", "Module data cannot be blank or nil")

      local modfunc = nil
      if isSandbox == true then
        modfunc = load(data, "=" .. name, "bt", kernel.internal.copy(_G))
      else
        modfunc = load(data, "=" .. name, "bt", _G)
      end
      local success, result = pcall(modfunc)

      if success and result then kernel.modules[name] = result return true
      elseif not success then error("Module execution error:\r"..result) end
    end,
    getModule = function(name)
      assert(kernel.modules[name], "Invalid module name")
      return kernel.modules[name]
    end,
    thread = {
      new = function(func, name, options) return kernel.threads:new(func, name, options) end,
      exists = function(pid) if kernel.threads.coroutines[pid] then return true else return false end end,
      list = function() return kernel.threads.coroutines end,
    },
  },
}

kernel.internal:initialize()
while coroutine.status(kernel.threads.coroutines[1].co) ~= "dead" do
  kernel.threads:cycle()

  -- Clean up nil threads
  -- for pid=1,#kernel.threads.coroutines do
  --   local thread = kernel.threads.coroutines[pid]
  --   if thread == nil then
  --     table.remove(kernel.threads.coroutines, pid)
  --   end
  -- end
end

kernel.display.simpleBuffer:print("Init has returned.")

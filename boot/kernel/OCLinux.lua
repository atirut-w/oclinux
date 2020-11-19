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
        current = nil
        return
      end
      
      local success, result = coroutine.resume(current.co, current.inputBuffer)
      if current.inputBuffer then current.inputBuffer = nil end
      -- Handle values or requests made by the thread.
      if success and result then
        if result.syscall then -- Deal with SysCalls
          local syscall = result.syscall
          -- Context for syscall functions
          local ctx = {
            pid = i
          }
          
          local function procSyscall(call, ctx, args)
            return (kernel.syscallList[call] or kernel.syscallList["default"])(ctx, args)
          end
          current.inputBuffer = procSyscall(syscall.call, ctx, syscall.args)
        end
      end
      
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

-- TODO: Consider looking for a better implementation
kernel.syscallList = {
  ["default"] = function() error("Invalid syscall", 4) end,
  ["getDisplay"] = function() return kernel.display end,
  ["getSystem"] = function() return {
    bootAddress = computer.getBootAddress(),
  } end,
  ["readfile"] = function(ctx, file) return kernel.internal.readfile(file) end,
  ["kernel.initModule"] = function(ctx, args)
    -- This function basically compile modstring into a function and execute it with a stripped down ENV
    -- then put the table that the module returned into `kernel.modules`
    assert(args, "Not enough or no arguments")
    assert(args[1] or args[1] ~= "", "Module string is blank or nil")
    assert(args[2] or args[2] ~= "", "Module name is blank or nil")

    local modstring, modname = args[1], args[2]
    local modfunc = load(modstring, "=" .. modname, "bt", kernel.internal.baseEnv)
    local success, result = pcall(modfunc)

    if success and result then kernel.modules[modname] = result return true
    elseif not success then error("Module execution error:\r"..result, 0) end
  end,
  ["kernel.getModule"] = function(ctx, name)
    assert(kernel.modules[name], "Invalid module name")
    return kernel.modules[name]
  end,
  ["threads.new"] = function(ctx, args) return kernel.threads:new(args[1], args[2], args[3]) end,
  ["threads.exists"] = function(ctx, pid) if kernel.threads.coroutines[pid] then return true else return false end end,
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

    kernel.threads:new(self.loadfile("/sbin/init.lua", kernel.internal.baseEnv), "init", {
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

-- TODO: Replace this with a copy of _G
kernel.internal.baseEnv = {
  coroutine = coroutine,
  checkArg = checkArg,
  component = component,
  unicode = unicode,
  type = type,
  next = next,
  assert = assert,
  pairs = pairs,
  select = select,
  table = table,
  tostring = tostring,
  setmetatable = setmetatable,
  math = math,
  load = load,
  error = error,
}
kernel.internal.baseEnv._G = kernel.internal.baseEnv

kernel.internal:initialize()

while coroutine.status(kernel.threads.coroutines[1].co) ~= "dead" do
  kernel.threads:cycle()
end

kernel.display.simpleBuffer:print("Init has returned.")

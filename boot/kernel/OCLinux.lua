-- OCLinux kernel by WattanaGaming
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3 beta"

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

-- Kernel table containing built-in functions. 
kernel = {
  modules = {},
  display = {
    isInitialized = false,
    resolution = {
      x = nil,
      y = nil
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
        kernel.display.gpu.fill(1, 1, kernel.display.resolution.x, kernel.display.resolution.y, " ")
        if #self.lineBuffer > kernel.display.resolution.y then
          table.remove(self.lineBuffer, 1)
        end
        for i=1,#self.lineBuffer do
          kernel.display.gpu.set(1, i, self.lineBuffer[i])
        end
      end,
      
      line = function(self, text)
        text = text or ""
        table.insert(self.lineBuffer, tostring(text))
        self:updateScreen()
      end
    }
  },
  
  CoroutineManager = {
    coroutines = {},
    
    CreateCoroutine = function(self, func, name)
      name = name or ""
      local id = #self.coroutines + 1
      self.coroutines[id] = {
        cname = name,
        co = coroutine.create(func),
      }
      return id
    end,
    
    ExecuteCoroutines = function(self)
      for i=1,#self.coroutines do
        coroutine.resume(self.coroutines[i].co)
      end
    end
  },
  
  essentials = {
    loadfile = function(file, env)
      local handle = kernel.filesystem.open(file, "r")
      local buffer = ""
      repeat
        local data = handle:read(1024)
        buffer = buffer .. (data or "")
      until not data
      handle:close()
      return load(buffer, "=" .. file, "bt", env)
    end,

    createSandbox = function(template, interfaces)
      template = template or _G
      local seen = {} -- DO NOT define this inside the function.
      local function copy(tbl) -- Massive thanks to Ocawesome101 for this loop!
        local ret = {}
        for k, v in pairs(tbl) do -- TODO: Make this loop function-independent.
          if type(v) == "table" and not seen[v] then
            seen[v] = true
            ret[k] = copy(v)
          else
            ret[k] = v
          end
        end
        return ret
      end
      local sandbox = copy(template)
      sandbox._G = sandbox
      return sandbox
    end,
  },
  
  internal = {
    isInitialized = false,
    accessLevel = {
      kLevel = kernel,
      blank = {}
    },
    interfaces = { -- For two-way comms
      "display",
      "filesystem",
      "modules",
    },
    
    loadfile = function(file)
      local addr, invoke = computer.getBootAddress(), component.invoke
      local handle = assert(invoke(addr, "open", file))
      local buffer = ""
      repeat
        local data = invoke(addr, "read", handle, math.huge)
        buffer = buffer .. (data or "")
      until not data
      invoke(addr, "close", handle)
      return load(buffer, "=" .. file, "bt", _G)
    end,

    loadModule = function(modFunc, modName)
      kernel.modules[modName] = load(modFunc, "="..modName, "bt", _G)()
    end,
    
    initialize = function(self)
      if (self.isInitialized) then -- Prevent the function from running again once initialized
        return false
      end
      self.bootAddr = computer.getBootAddress()
      
      kernel.display:initialize()
      local initSandbox = kernel.essentials.createSandbox(self.accessLevel.kLevel, self.interfaces)

      kernel.display.simpleBuffer:line("Loading and executing /sbin/init.lua")

      kernel.CoroutineManager:CreateCoroutine(self.loadfile("/sbin/init.lua", _G), "init")

      self.isInitialized = true
      return true
    end
  }
}

kernel.internal:initialize()

while coroutine.status(kernel.CoroutineManager.coroutines[1].co) ~= "dead" do
  kernel.CoroutineManager:ExecuteCoroutines()
end

kernel.display.simpleBuffer:line("Init has returned.")

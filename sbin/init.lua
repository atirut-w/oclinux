local args = ...

_G._INITVERSION = "INDEV"
_G._BASE_MOD_DIR = "/boot/kmod/base/"
_G._SHELL = args.shell or "/sbin/luashell.lua"

-- Get the kernel's built-in display system
local display = coroutine.yield({syscall = {
    call = "getDisplay"
  }
})
local print = function(msg) display.simpleBuffer:print(msg) end -- Alias
local write = function(msg) display.simpleBuffer:write(msg) end -- Alias

local system = coroutine.yield({syscall = {
    call = "getSystem"
  }
})

-- List of built-in modules to load
local baseModules = {
  "filesystem"
}

print("Basic init for OCLinux v".._G._INITVERSION)
print("Loading base kernel modules")
for i=1,#baseModules do
  print(baseModules[i].."... ")
  local modString = coroutine.yield({syscall = {
    call = "readfile",
    args = _G._BASE_MOD_DIR..baseModules[i]..".lua"
  }})
  coroutine.yield({syscall = {
    call = "kernel.initModule",
    args = {modString, baseModules[i]}
  }})
  write("done")
  coroutine.yield()
end

local filesystem = coroutine.yield({syscall = {
  call = "kernel.getModule",
  args = "filesystem"
}})
print("Mounting "..system.bootAddress.." as root(/)... ")
filesystem.mount(system.bootAddress, "/")

print("Attempting to load and execute ".._G._SHELL.."...")
-- Load file into function
local file = filesystem.open(_G._SHELL, "r")
assert(file, _G._SHELL.." not found")
local shellScript = file:read(math.huge)
file:close()
local shellFunc = load(shellScript, "=".._G._SHELL, "t", _G)

-- Execute
local shellProcess
local function createShellProcess()
  shellProcess = coroutine.yield({syscall = {
    call = "threads.new",
    args = {
      shellFunc, _G._SHELL, {errHandler = function(err) 
        print("Shell process exited with the following error:")
        print("    "..err)
      end}
    }
  }
  })
end
createShellProcess()

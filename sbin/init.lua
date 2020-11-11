_G._INITVERSION = "INDEV"

-- Get the kernel's built-in display system
local display = coroutine.yield({
  syscall = {
    call = "getDisplay"
  }
})
local print = function(msg) display.simpleBuffer:print(msg) end -- Alias
local write = function(msg) display.simpleBuffer:write(msg) end -- Alias

local system = coroutine.yield({
  syscall = {
    call = "getSystem"
  }
})

-- List of built-in modules to load
local baseModules = {
  "filesystem"
}

print("OCLinux bundled init v".._G._INITVERSION)
print("Loading built-in kernel modules")
for i=1,#baseModules do
  print(baseModules[i].."... ")
  local modString = coroutine.yield({syscall = {
    call = "readfile",
    args = "/boot/kmod/"..baseModules[i]..".lua"
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

print("A wild <EOF> blocks the path! Looks like the bundled init still being developed at the time.")

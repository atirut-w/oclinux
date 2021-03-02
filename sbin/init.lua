_G._INITVERSION = "INDEV"
local modDir = "/boot/kmod/base/"
local shell = "/sbin/tinyshell.lua"
local autoRestartShell = false

print = system.display.simplePrint
write = system.display.simpleWrite

-- List of built-in modules to load
local baseModules = {
    "filesystem",
    "standardlib",
}

print("TinyInit v".._G._INITVERSION)

print("Loading base kernel modules")
for i=1,#baseModules do
    write (baseModules[i].."... ")
    local modString = system.kernel.readfile(modDir..baseModules[i]..".lua")
    system.kernel.initModule(baseModules[i], modString, false)
    coroutine.yield()
end
print("Done loading modules")

local filesystem = system.kernel.getModule("filesystem")
print("Mounting "..system.bootAddress.." as root(/)... ")
filesystem.mount(system.bootAddress, "/")

print("Attempting to load and execute " .. shell .."...")
-- Load file into function
local file = filesystem.open(shell, "r")
assert(file, shell.." not found")
local shellScript = ""
do
    local buffer = ""
    repeat
        local data = file:read(math.huge)
        buffer = buffer .. (data or "")
    until not data
    shellScript = buffer
    file:close()
end
local shellFunc = load(shellScript, "=" .. shell, "t", _G)

local function shellErrorHandler(err)
    print("Shell process exited with the following error:")
    print("    "..(err or "not specified"))
end
local shellProcessID = os.thread:new(shellFunc, shell, {errorHandler = shellErrorHandler})

local running = true
while running do
    coroutine.yield()
    if autoRestartShell and not os.thread:exists(shellProcessID) then
        shellProcessID = os.thread:new(shellFunc, shell, {errorHandler = shellErrorHandler})
    elseif not os.thread:exists(shellProcessID) then
        running = false
    end
end

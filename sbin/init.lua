_G._INITVERSION = "INDEV"
local modDir = "/boot/kmod/base/"
local shell = "/sbin/tinyshell.lua"
local autoRestartShell = false

print = os.simpleDisplay.status
print("TinyInit v".._G._INITVERSION)

-- List of built-in modules to load
local baseModules = {
    "filesystem",
    "standardlib",
}

print("Loading base kernel modules")
for i=1,#baseModules do
    print (baseModules[i].."...")
    local file = io.open(modDir..baseModules[i]..".lua", "r")
    os.kernel.initModule(baseModules[i], file:read("a"), false)
    file:close()
    coroutine.yield()
end
print("Done loading modules")

local filesystem = os.kernel.getModule("filesystem")
print("Mounting "..computer.getBootAddress().." as root(/)... ")
filesystem.mount(computer.getBootAddress(), "/")

print("Attempting to load and execute " .. shell .."...")
-- Load file into function
local shellFunc
do
    local file = io.open(shell, "r")
    assert(file, shell.." not found")
    local shellScript = file:read("a")
    file:close()
    shellFunc = load(shellScript, "=" .. shell, "t", _G)
end

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

-- OCLinux kernel by Atirut Wattanamongkol(WattanaGaming)
--#include "src/includes/object.lua"
--#include "src/includes/switch.lua"
_G.boot_invoke = nil

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
-- local unicode = unicode or require('unicode')

-- Kernel table containing built-in functions.
local kernel = {}
os.kernel = {
    _BUILDTIME = $(NOW)
}
os.kernel.modules = {}

--#include "src/modules/io.lua"
--#include "src/modules/simpleDisplay.lua"
--#include "src/modules/thread.lua"

local internal = {}

internal.readfile = function(file)
    local addr, invoke = computer.getBootAddress(), component.invoke
    local handle = assert(invoke(addr, "open", file), "Requested file "..file.." not found")
    local buffer = ""
    repeat
        local data = invoke(addr, "read", handle, math.huge)
        buffer = buffer .. (data or "")
    until not data
    invoke(addr, "close", handle)
    return buffer
end

internal.copy = function(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[internal.copy(k, s)] = internal.copy(v, s) end
    return res
end

internal.loadfile = function(file, env, isSandbox)
    if isSandbox == true then
        local sandbox = internal.copy(env)
        sandbox._G = sandbox
        return load(internal.readfile(file), "=" .. file, "bt", sandbox)
    else
        return load(internal.readfile(file), "=" .. file, "bt", env)
    end
end

function os.kernel.initModule(name, data, isSandbox)
    assert(name ~= "", "Module name cannot be blank or nil")
    assert(data ~= "", "Module data cannot be blank or nil")
    
    local modfunc = nil
    if isSandbox == true then
        modfunc = load(data, "=" .. name, "bt", internal.copy(_G))
    else
        modfunc = load(data, "=" .. name, "bt", _G)
    end
    local success, result = pcall(modfunc)
    
    if success and result then os.kernel.modules[name] = result return true
    elseif not success then error("Module execution error:\r"..result) end
end

function os.kernel.getModule(name)
    assert(os.kernel.modules[name], "Invalid module name")
    return os.kernel.modules[name]
end

os.kernel.readfile = function(file) return internal.readfile(file) end

-- +------------------+
-- | Initialize stuff |
-- +------------------+

-- Load up init as a thread.
os.simpleDisplay.status("Loading and executing /sbin/init.lua")
os.thread:new(internal.loadfile("/sbin/init.lua", _G, false), "init", {
    errorHandler = function(err) -- Special handler.
        computer.beep(1000, 0.1)
        local print = function(a) os.simpleDisplay.status(a) end
        print("Error whilst executing init:")
        print("  "..tostring(err))
        print("")
        print("Halted.")
        while true do computer.pullSignal() end
    end,
})
while os.thread:exists(1) do
    os.thread:cycle()
end

os.simpleDisplay.status("Init has returned.")

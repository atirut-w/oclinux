-- OCLinux kernel by WattanaGaming
-- Clean start is always gud for your health ;)
_G.boot_invoke = nil
-- Kernel metadata
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "1.0"
_G._KERNELVERSION = _KERNELNAME.." ".._KERNELVER

-- Fetch some important goodies
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

local bootDrive = computer.getBootAddress()
local gpu = component.list("gpu")()
local screen = component.list("screen")()

-- Set up variables
cursorPos = {
    x = 1,
    y = 1
}

-- [[ Low-level GPU function from a very early version of OCLinux ]]
function gpuInvoke(op, arg, ...)
    local res = {}
    local n = 1
    for address in component.list('screen') do
        component.invoke(gpu, "bind", address)
        if type(arg) == "table" then
            res[#res + 1] = {component.invoke(gpu, op, table.unpack(arg[n]))}
        else
            res[#res + 1] = {component.invoke(gpu, op, arg, ...)}
        end
        n = n + 1
    end
    return res
end
if gpu and screen then
    --component.invoke(gpu, "bind", screen)
    w, h = component.invoke(gpu, "getResolution")
    local res = gpuInvoke("getResolution")
    gpuInvoke("setResolution", res)
    gpuInvoke("setBackground", 0x000000)
    gpuInvoke("setForeground", 0xFFFFFF)
    for _, e in ipairs(res)do
        table.insert(e, 1, 1)
        table.insert(e, 1, 1)
        e[#e+1] = " "
    end
    gpuInvoke("fill", res)
    cls = function()gpuInvoke("fill", res)end
end
-- [[ END OF GPU SECTION ]]

function printStatus(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        gpuInvoke("set", cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = 1
        cursorPos.y = cursorPos.y + 1
    end
    -- cursorPos.y = cursorPos.y + 1
end

function writeStatus(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        gpuInvoke("set", cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = string.len(...) + 1
    end
    -- cursorPos.y = cursorPos.y + 1
end

-- A very low level filesystem controller
function fs(op, arg, ...)
    local r = component.invoke(bootDrive, op, arg, ...)
    return r
end

function execInit(init)
    writeStatus("Looking for init \""..init.."\"....    ")
    if fs("exists", init) then
        printStatus("init found!")
        initHandle = fs("open", init, "r")
        initSize = fs("size", init)
        initCode = fs("read", initHandle, initSize)
        load(initCode, "/boot/kernel/OCLinux.lua", _G)()
        return true
    else
        printStatus("Not here")
    end
end

function panic(reason)
    if not reason then
        reason = "No reason specified"
    end
    printStatus("Kernel panic: "..reason)
    printStatus("System halted")
    computer.beep(1000, .5)
    computer.beep(1000, .5)
    computer.beep(1000, 1)
    while true do
        computer.pullSignal()
    end    
end

-- A Lua version of the kernel loading code from the Wiki pae of
-- kernel panic
if not execInit("/sbin/init.lua") and not execInit("/etc/init.lua") and not execInit("/bin/init.lua") then
end

-- Halt the system, everything should be ok if there is no BSoD
panic()
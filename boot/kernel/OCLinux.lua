-- OCLinux kernel by WattanaGaming
-- Clean start is always gud for your health ;)
_G.boot_invoke = nil
-- Kernel metadata
_G._OSNAME = "OCLinux"
_G._OSVER = "1.0"
_G._OSVERSION = _OSNAME.." ".._OSVER

-- Fetch some important goodies
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

local file = computer.getBootAddress()
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
    gpuInvoke("set", 1, cursorPos.y, tostring(...))
    cursorPos.y = cursorPos.y + 1
end

function fs(op, arg, ...)
    local r = component.invoke(file, op, arg, ...)
    return r
end

-- Print out a test message
printStatus("Welcome to OCLinux 1.0!")
printStatus("Boot drive: "..computer.getBootAddress())
printStatus("Boot drive space usage: "..fs("spaceUsed").." bytes out of "..fs("spaceTotal").." bytes")
printStatus("Listing connected components:")
for address,type in component.list() do
    printStatus("    "..address.."  "..type)
end
-- Halt the system, everything should be ok if there is no BSoD
printStatus("SYSTEM HALTED!")
while true do
    computer.pullSignal()
end
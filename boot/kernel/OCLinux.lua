-- OCLinux kernel by WattanaGaming
-- Set up variables
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.2.2 beta"
_G._KERNELVERSION = _KERNELNAME.._KERNELVER

-- Load up basic libraries
component = component or require('component')
computer = computer or require('computer')
unicode = unicode or require('unicode')

-- Initialize the GPU and the display
gpu = component.list("gpu")()
screen = component.list("screen")()

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
    screenRes = {}
    screenRes.w, screenRes.h = component.invoke(gpu, "getResolution")
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
-- display related functions
-- This will come in handy for managing cursor position
cursorPos = {
    x = 1,
    y = 1
}
function printStatus(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        if cursorPos.y > screenRes.h then
            -- Why the hell did they use Cartesian Coordinate? WHY?!
            gpuInvoke("copy", 1, 2, screenRes.w, screenRes.h-1, 0, -1)
            gpuInvoke("setForeground", 0x000000)
            gpuInvoke("fill", 1, screenRes.h, screenRes.w, 1, " ")
            gpuInvoke("setForeground", 0xFFFFFF)
            cursorPos.y = cursorPos.y - 1
        end
        gpuInvoke("set", cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = 1
        cursorPos.y = cursorPos.y + 1
    end
end

function writeStatus(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        gpuInvoke("set", cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = string.len(...) + 1
    end
end

for a=1,200 do
    printStatus(a)
end
printStatus("Done")

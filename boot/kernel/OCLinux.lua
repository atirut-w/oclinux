-- OCLinux kernel by WattanaGaming
-- Clean start is always gud for your health ;)
_G.boot_invoke = nil

-- Kernel metadata
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3.0 beta"
_G._KERNELVERSION = _KERNELNAME .. " " .. _KERNELVER

-- Fetch some important goodies
component = component or require('component')
computer = computer or require('computer')
unicode = unicode or require('unicode')

bootDrive = computer.getBootAddress()
gpu = component.list("gpu")()
screen = nil

-- Set up variables
cursorPos = {
    x = 1,
    y = 1
}
screenResolution = {}

-- Bind screen to GPU
for address in component.list("screen") do
    if #component.invoke(address, "getKeyboards") > 0 then
        screen = address
    end
end
if not screen then
    screen = component.list("screen")()
end
component.invoke(gpu, "bind", screen)

-- Note to WattanaGaming: binding the screen at each operations kinda allow for multi-screen but
-- slows down a lot the graphics operation.
function gpuInvoke(op, arg, ...)
    local res = {}
    if type(arg) == "table" then
        res[#res + 1] = {component.invoke(gpu, op, table.unpack(arg[1]))}
    else
        res[#res + 1] = {component.invoke(gpu, op, arg, ...)}
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
screenResolution.w, screenResolution.h = gpuInvoke("getResolution")

-- [[ END OF GPU SECTION ]]

function printStatus(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        if cursorPos.y > h then
            -- Why the hell did they use Cartesian Coordinate? WHY?!
            gpuInvoke("copy", 1, 2, w, h-1, 0, -1)
            gpuInvoke("setForeground", 0x000000)
            gpuInvoke("fill", 1, h, w, 1, " ")
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

-- A very low level filesystem controller
-- that is now useless with "filesystem" API
function fs(drive, op, arg, ...)
    return component.invoke(drive, op, arg, ...)
end

function readFile(drive, file)
    fileHandle = fs(drive, "open", file, "r")
    fileSize = fs(drive, "size", file)
    fileContent = fs(drive, "read", fileHandle, fileSize)
    return fileContent
end

--Declare kernel specific functions
function execInit(init)
    writeStatus("Looking for init \""..init.."\"....    ")
    if fs(bootDrive, "exists", init) then
        printStatus("Init found!")
        initC = readFile(bootDrive, init)
        local v, err = pcall(function()
			load(initC, "=" .. init, nil, _G)()
		end)
		if not v then
			gpuInvoke("setForeground", 0xFF0000) -- some unstandard way to do error
			printStatus(err)
			panic("An error occured during execution")
		end
        return true
    else
        printStatus("Not here")
    end
end

function panic(reason)
    if not reason then
        reason = "No reason specified"
    end
    gpuInvoke("setForeground", 0xFF0000) -- error color ;)
    printStatus("Kernel Panic!!")
    printStatus("    Reason        : " .. reason)
    printStatus("    Kernel version: " .. _KERNELVER)
    printStatus("    System uptime : " .. computer.uptime())
    cursorPos.y = cursorPos.y + 1 -- break line
    --printStatus("Your computer will shutdown after the long beep")
    computer.beep(1000, 0.75)
    -- Re-add shutdown when kernel is ready for release
    while true do
        computer.pullSignal()
    end
    --computer.shutdown()
end

-- [[ YOU BETTER LEFT THESE PARTS UNTOUCHED ]]
-- A Lua version of the kernel loading code from the Wiki page of the
-- kernel panic
if not execInit("/sbin/init.lua") and not execInit("/etc/init.lua") and not execInit("/bin/init.lua") then
    panic("Init not found. You are on your own now, good luck!")
end

-- Halt the system, everything should be ok if there is no BSoD
panic("Init returned")
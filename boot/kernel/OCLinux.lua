-- OCLinux kernel by WattanaGaming
-- Set up variables
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.2.2 beta"
_G._KERNELVERSION = _KERNELNAME.." ".._KERNELVER

-- Load up basic libraries
component = component or require('component')
computer = computer or require('computer')
unicode = unicode or require('unicode')

-- Start of the graphics section
-- Get the GPU and the display
gpu = component.list("gpu")()
screen = component.list("screen")()

-- Idk what this shit does. I took it from OpenLoader init
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
-- Display related functions
-- This variable will come in handy for managing cursor position
cursorPos = {
    x = 1,
    y = 1
}
function print(...)
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

function write(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        gpuInvoke("set", cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = string.len(...) + 1
    end
end
-- End of the graphics section

-- Filesystem wrapper function
function fs(filesystem, op, arg, ...)
    return component.invoke(filesystem, op, arg, ...)
end

function readFile(filesystem, file)
    local fileHandle = fs(filesystem, "open", file, "r")
    local fileSize = fs(filesystem, "size", file)
    local fileContent = ""
    local tmp = fileSize
    local readed = ""
    while true do
        readed = fs(filesystem, "read", fileHandle, 2048)
        if readed == nil then
            break
        end
        fileContent = fileContent..readed
    end
    return fileContent
end
-- Get the boot address
bootFs = computer.getBootAddress()

-- Start of the kernel specific section
kernel = {}

function kernel.execInit(init)
    write("Looking for init \""..init.."\"....    ")
    if fs(bootFs, "exists", init) then
        print("Init found!")
        initC = readFile(bootFs, init)
        local v, err = pcall(function()
      load(initC, "=" .. init, nil, _G)()
    end)
    if not v then
      gpuInvoke("setForeground", 0xFF0000) -- some unstandard way to do error
      print(err)
      panic("An error occured during execution of "..init)
    end
        return true
    else
        print("Not here")
    end
end

function kernel.panic(reason)
    if not reason then
        reason = "No reason specified"
    end
    --  Zenith's tweak of the kernel panic error'
    print("Kernel Panic!!")
    print("    Reason        : " .. reason)
    print("    Kernel version: " .. _KERNELVER)
    print("    System uptime : " .. computer.uptime())
    cursorPos.y = cursorPos.y + 1 -- break line
    print("System halted.")
    computer.beep(1000, 0.75)
    -- Re-add shutdown when kernel is ready for release
    while true do
        computer.pullSignal()
    end
    --computer.shutdown()
end

if not kernel.execInit("/sbin/init.lua") and not kernel.execInit("/etc/init.lua") and not kernel.execInit("/bin/init.lua") then
    kernel.panic("Init not found. You are on your own now, good luck!")
end

-- Halt the system, everything should be ok if there is no BSoD
kernel.panic("Init returned")

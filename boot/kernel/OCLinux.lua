-- OCLinux kernel by WattanaGaming
-- Set up variables
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.2.3 beta"
_G._KERNELVERSION = _KERNELNAME.." ".._KERNELVER

-- Load up basic libraries
component = component or require('component')
computer = computer or require('computer')
unicode = unicode or require('unicode')

-- Start of the graphics section
-- Get the GPU and the display
gpu = component.proxy(component.list("gpu")())
screen = component.list("screen")()
-- Bind the screen to the GPU and get the screen resolution
gpu.bind(screen)
screenRes = {}
screenRes.w, screenRes.h = gpu.getResolution()
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
            gpu.copy(1, 2, screenRes.w, screenRes.h-1, 0, -1)
            gpu.setForeground( 0x000000)
            gpu.fill(1, screenRes.h, screenRes.w, 1, " ")
            gpu.setForeground(0xFFFFFF)
            cursorPos.y = cursorPos.y - 1
        end
        gpu.set(cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = 1
        cursorPos.y = cursorPos.y + 1
    end
end

function write(...)
    for i in string.gmatch(tostring(...), "([^\r\n]+)") do
        gpu.set(cursorPos.x, cursorPos.y, tostring(i))
        cursorPos.x = string.len(...) + 1
    end
end
-- End of the graphics section

-- Start of the filesystem section
fs = {}
fs.lowLevel = component.proxy(computer.getBootAddress())
fs.mountpoints = {}

function fs.mount(filesystem, mountpoint)

end

function fs.open(filesystem, file, mode)
    return fs.lowLevel.open(file, mode)
end

function fs.close(filesystem, handle)
    return fs.lowLevel.close(handle)
end

function fs.exists(filesystem, file)
    return fs.lowLevel.exists(file)
end

function fs.read(filesystem, handle)
    local fileContent = ""
    local tmp = fileSize
    local readed = ""
    while true do
        readed = fs.lowLevel.read(handle, 2048)
        if readed == nil then
            break
        end
        fileContent = fileContent..readed
    end
    return fileContent
end

-- Start of the kernel specific section
kernel = {}

-- Get the boot time until kernel in case there is a bootloader delay
kernel.bootTime = computer.uptime()
-- Get the boot address
kernel.bootFs = computer.getBootAddress()

function kernel.execInit(init)
    write("Looking for init \""..init.."\"....    ")
    if fs.exists(kernel.bootFs, init) then
        print("Init found!")
        initHandle = fs.open(kernel.bootFs, init, "r")
        initC = fs.read(kernel.bootFs, initHandle)
        -- Zenith's error detection
        local v, err = pcall(function()
            load(initC, "=" .. init, nil, _G)()
        end)
        if not v then
            kernel.panic("An error occured during execution of "..init, err)
        end
        return true
    else
        print("Not here")
    end
end

function kernel.panic(reason, traceback)
    if not reason then
        reason = "Not specified"
    elseif not traceback then
        traceback = "None"
    end
    --  Zenith's tweak of the kernel panic error'
    print("Kernel Panic!!")
    print("  Reason: " .. reason)
    print("  Traceback: "..traceback)
    print("  Kernel version: ".. _KERNELVER)
    print("  System uptime: ".. computer.uptime() - kernel.bootTime)
    print("System halted.")
    computer.beep(1000, 0.75)
    while true do
        computer.pullSignal()
    end
end

if not kernel.execInit("/sbin/init.lua") and not kernel.execInit("/etc/init.lua") and not kernel.execInit("/bin/init.lua") then
    kernel.panic("Init not found. You are on your own now, good luck!")
end

-- Halt the system, everything should be ok if there is no BSoD
kernel.panic("Init returned")


-- OCLinux kernel by WattanaGaming
-- Set up variables
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.2.5 beta"
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
fs.filesystems = {}
fs.mtab = {name="", children={}, links={}}
fs.fstab = {}

function table.maxn(tab)
    local i = 0
    for k, v in pairs(tab) do
        i = math.max(i, k)
    end
    return i
end

function fs.segments(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
        local current, up = part:find("^%.?%.$")
        if current then
            if up == 2 then
                table.remove(parts)
            end
        else
            table.insert(parts, part)
        end
    end
    return parts
end

function fs.hasMountPoint(path)
    return fs.getNode(path) ~= nil
end

function fs.canonical(path)
    local result = table.concat(fs.segments(path), "/")
    if unicode.sub(path, 1, 1) == "/" then
        return "/" .. result
    else
        return result
    end
end

function fs.concat(...)
    local set = table.pack(...)
    for index, value in ipairs(set) do
        checkArg(index, value, "string")
    end
    return fs.canonical(table.concat(set, "/"))
end

function fs.mount(path, filesystem)
    --[[
    if fs.hasMountPoint(path) then
        error(path.." is already mounted")
    end
    ]]
    table.insert(fs.filesystems, {path, filesystem})
end

function fs.localPath(node, path)
    local localPath = path:gsub(node.path.."/", "")
    return localPath
end

function fs.getDrives(automount)
    local tab = {}
    -- TODO add support for drives when an standardized unmanaged filesystem is made for OC
    local i = 0
    for k, v in pairs(component.list("filesystem")) do
        -- uncorrect naming due to not knowing if it's floppy or disk drive
        table.insert(tab, "/dev/" .. "hd".. string.char(string.byte('a') + i) .. "/")
        if automount then
            if not fs.contains(component.proxy(v)) then
                fs.mount("/dev/" .. "hd".. string.char(string.byte('a') + i) .. "/", component.proxy(v))
            end
        end
        i = i + 1
    end
    return tab
end

function fs.exists(path)
    local node = fs.findNode(path)
    if node == nil then
        return false
    end
    local lp = fs.localPath(node, path)
    return node.exists(lp)
end

-- Also has compatibility for older versions
function fs.isReadOnly(path)
    local node = fs.findNode(path)
    if node == nil then
        return false
    end
    local lp = fs.localPath(node, path)
    if node.isReadOnly then
        return node.isReadOnly(lp)
    else
        return false
    end
end

function fs.getFile(path, mode)
    local node fs.findNode(path)
    local lp = fs.localPath(node, path)
    local file = {}
    file.handle = node.open(lp, mode)
    file.seek = function(whence, offset)
        return node.seek(file.handle, whence, offset)
    end
    file.write = function(value)
        return node.write(file.handle, value)
    end
    file.read = function(amount)
        return node.read(file.handle, amount)
    end
    file.size = function()
        return node.size(lp)
    end
    file.close = function()
        node.close(file.handle)
    end
    return file
end

function fs.size(path)
    local node = fs.findNode(path)
    if node == nil then
        return -1
    end
    local lp = fs.localPath(node, path)
    return node.size(lp)
end

function fs.findNode(path)
    local lastPath = ""
    local lastNode = nil
    local seg = fs.segments(path)
    for k, v in pairs(seg) do
        if k < table.maxn(seg) then
            lastPath = lastPath..v.."/"
        else
            lastPath = lastPath..v
        end
        local node = fs.getNode(lastPath)
        if node ~= nil then
            lastNode = node
            node.path = lastPath
        end
    end
    return lastNode
end

function fs.getNode(mountPath)
    for k, v in pairs(fs.filesystems) do
        local p = v[1]
        if p == mountPath then -- if is same path
            p = mountPath
            print(p)
            return p
        end
    end
    return nil
end

function fs.contains(node)
    for k, v in pairs(fs.filesystems) do
        local p = v[2]
        if p == node then
            return true
        end
    end
    return false
end

-- Start of the kernel specific section
kernel = {}

-- Get the boot time until kernel in case there is a bootloader delay
kernel.bootTime = computer.uptime()
-- Get the boot address
kernel.bootFs = computer.getBootAddress()

function kernel.execInit(init)
    write("Looking for init \""..init.."\"....    ")
    if fs.exists(init) then
        print("Init found!")
        initHandle = fs.open(init, "r")
        initC = fs.read(init, initHandle)
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
    end
    if not traceback then
        traceback = "None"
    end
    --  Zenith's tweak of the kernel panic error
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

-- Mount the boot device
fs.mount("/", kernel.bootFs)

for k, v in pairs(fs.getDrives(true)) do -- also auto-mount drives to dev/hd_
  print(v)
end

if not kernel.execInit("/sbin/init.lua") and not kernel.execInit("/etc/init.lua") and not kernel.execInit("/bin/init.lua") then
    kernel.panic("Init not found. You are on your own now, good luck!")
end

-- Halt the system, everything should be ok if there is no BSoD
kernel.panic("Init returned")


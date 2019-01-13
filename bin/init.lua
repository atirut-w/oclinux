-- Init version
_INITVER = "1.0"
local fslib, err = load(readFile(computer.getBootAddress(), "boot/kernel_modules/filesystem.lua"), "=filesystem.lua", nil, _G) -- load filesystem API
local filesystem

local vlib, arr = load(readFile(computer.getBootAddress(), "lib/vram.lua"), "=vram.lua", nil, _G) -- load Video RAM API
local vram
if fslib ~= nil then
	filesystem = fslib()
end
if vlib ~= nil then
	vram = vlib()
end
function printInfo(...)
    writeStatus("[ INFO ] ")
    printStatus(...)
end

function printWarning(...)
    writeStatus("[ WARNING ] ")
    printStatus(...)
end

function printError(...)
    writeStatus("[ ERROR! ] ")
    printStatus(...)
end
if err ~= nil then -- unable to load filesystem api
	printError(err)
end
if arr ~= nil then
	printError(err)
end
filesystem.mount("/", component.proxy(computer.getBootAddress()))
printStatus([[ (o<
//\
V_/]])
printStatus("Welcome to OCLinux!")
printStatus("Kernel version: ".._KERNELVER)
printStatus("Init version: ".._INITVER)
printStatus("Boot drive space usage: "..fs(bootDrive, "spaceUsed").."/"..fs(bootDrive, "spaceTotal").." bytes available")
printStatus("Memory: "..computer.freeMemory().."/"..computer.totalMemory().." bytes available")

printStatus("Drives:")
for k, v in pairs(filesystem.getDrives(true)) do -- also auto-mount drives to dev/hd_
	printStatus(v)
end

printStatus("Loading Video RAM..")
vram.setViewport(105, 33)
printStatus("VRAM Size: " .. vram.getSize())
printStatus(filesystem.exists("/dev/hda/init.lua"))
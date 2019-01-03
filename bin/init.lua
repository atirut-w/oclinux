-- Init version
_INITVER = "1.0"
local filesystem = load(readFile(computer.getBootAddress(), "boot/kernel_modules/filesystem.lua"), nil, nil, _G)() -- load filesystem API

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
filesystem.mount("/", component.proxy(computer.getBootAddress()))
printStatus([[ (o<
//\
V_/]])
printStatus("Welcome to OCLinux!")
printStatus("Kernel version: ".._KERNELVER)
printStatus("Init version: ".._INITVER)
printStatus("Boot drive space usage: "..fs(bootDrive, "spaceUsed").."/"..fs(bootDrive, "spaceTotal").." bytes available")
printStatus("Memory: "..computer.freeMemory().."/"..computer.totalMemory().." bytes available")


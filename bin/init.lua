-- Init version
_INITVER = "1.0"

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
printStatus([[ (o<
//\
V_/]])
printStatus("Welcome to OCLinux!")
printStatus("Kernel version: ".._KERNELVER)
printStatus("Init version: ".._INITVER)
printStatus("Boot drive space usage: "..fs(bootDrive, "spaceUsed").."/"..fs(bootDrive, "spaceTotal").." bytes available")
printStatus("Memory: "..computer.freeMemory().."/"..computer.totalMemory().." bytes available")


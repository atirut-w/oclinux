-- Init version
_INITVER = "1.0"

local gpu = component.list("gpu")()

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

printStatus("Welcome to OCLinux!")
printStatus([[    .--.
   |o_o |
   |:_/ |
  //   \ \
 (|     | )
/'\_   _/`\
\___)=(___/]])
printStatus("Kernel version: ".._KERNELVER)
printStatus("Init version: ".._INITVER)
printStatus("Boot drive spave usage: "..fs(bootDrive, "spaceUsed").." bytes used out of "..fs(bootDrive, "spaceTotal").." bytes")


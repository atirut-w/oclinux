-- Init version
_INITVER = "1.0"

local gpu = component.list("gpu")()

function printInfo(message)
    oldForeground = gpuInvoke("getForeground")
    writeStatus("[ ")
    gpuInvoke("setForeground", 0x00ff00)
    writeStatus("INFO")
    gpuInvoke("setForeground", 0xffffff)
    writeStatus(" ] "..message)
    
end

printStatus("Welcome to OCLinux !")
printStatus("Kernel version: ".._KERNELVER)
printStatus("Init version: ".._INITVER)
-- printStatus("Boot drive spave usage: "..fs.spaceUsed().." bytes used out of "..fs.spaceTotal().." bytes")
printInfo("Test")
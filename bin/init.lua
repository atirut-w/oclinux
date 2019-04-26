-- Init version
_INITVER = "1.0"

function printInfo(...)
    write("[ INFO ] ")
    print(...)
end

function printWarning(...)
    write("[ WARNING ] ")
    print(...)
end

function printError(...)
    write("[ ERROR! ] ")
    print(...)
end
print([[ (o<
//\
V_/_]])
print("Welcome to OCLinux!")
print("Kernel version: ".._KERNELVER)
print("Init version: ".._INITVER)
print("Boot drive space usage: "..fs.lowLevel.spaceUsed().."/"..fs.lowLevel.spaceTotal().." bytes available")
print("Memory: "..computer.freeMemory().."/"..computer.totalMemory().." bytes available")

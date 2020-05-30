-- OCLinux kernel by WattanaGaming
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3 beta"

-- These are needed to do literally anything.
component = component or require('component')
computer = computer or require('computer')
unicode = unicode or require('unicode')

-- Kernel related facilities. Can be accessed through ENVs
local display = {
    isInitialized = false
}
local filesystem = {}
local internal = {
    isInitialized = false
}

function display:initialize()
    if (self.isInitialized) then -- Prevent the function from running once initialized
        return false
    else
        self.isInitialized = true
    end
    self.gpu = component.proxy(component.list("gpu")())
end

function internal:initialize() -- This function have to be executed before the kernel can do anything useful.
    if (self.isInitialized) then -- Prevent the function from running once initialized
        return false
    else
        self.isInitialized = true
    end
    self.bootAddr = computer.getBootAddress()
    
    display:initialize()
end

internal:initialize()

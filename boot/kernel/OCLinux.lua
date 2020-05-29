-- OCLinux kernel by WattanaGaming
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3 beta"

-- These are needed to do literally anything.
component = component or require('component')
computer = computer or require('computer')
unicode = unicode or require('unicode')

-- Kernel's own namespace kinda thing.
local kernel = {
    display = {}
}

function kernel.display:initialize()
    self.gpu = component.proxy(component.list("gpu")())
end

function kernel:initialize() -- This function have to be executed before the kernel can do anything useful.
    self.display:initialize()
end

kernel:initialize()

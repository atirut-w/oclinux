-- OCLinux kernel by WattanaGaming
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3 beta"

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

-- Kernel related facilities. Can be accessed through ENVs. TODO: Consider moving these table declarations to the top of where the functions are.
local display = {
    isInitialized = false
}
local filesystem = {}
local internal = {
    isInitialized = false
}

function display:initialize()
    if (self.isInitialized) then
        return false
    else
        self.isInitialized = true
    end
    self.gpu = component.proxy(component.list("gpu")())
end

function internal.createSandbox(template)
    template = template or _G
    local seen = {} -- DO NOT define this inside the function.
    local function copy(tbl) -- Massive thanks to Ocawesome101 for this loop!
        local ret = {}
        for k, v in pairs(tbl) do -- TODO: Make this loop function-independent.
            if type(v) == "table" and not seen[v] then
                seen[v] = true
                ret[k] = copy(v)
            else
                ret[k] = v
            end
        end
        return ret
    end
    local sandbox = copy(template)
    sandbox._G = sandbox
    return sandbox
end

function internal:initialize() -- This function have to be executed before the kernel can do anything useful.
    if (self.isInitialized) then -- Prevent the function from running again once initialized
        return false
    else
        self.isInitialized = true
    end
    self.bootAddr = computer.getBootAddress()
    
    display:initialize()
end

internal:initialize()

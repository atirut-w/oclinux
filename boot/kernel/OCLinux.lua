-- OCLinux kernel by WattanaGaming
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3 beta"

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

-- Kernel related facilities. Can be accessed through ENVs. 
-- TODO: Consider moving these table declarations to the top of where the functions are.
local display = {
    isInitialized = false,
    resolution = {
        x = nil,
        y = nil
    }
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
    self.resolution.x, self.resolution.y = self.gpu.getResolution()
end

-- A very basic and barebone system for putting texts on the screen.
display.simpleBuffer = {
    lineBuffer = {}
}

function display.simpleBuffer:updateScreen()
    for i=1,#self.lineBuffer do
        display.gpu.set(1, i, self.lineBuffer[i])
    end
end

function display.simpleBuffer:line(text)
    text = text or ""
    table.insert(self.lineBuffer, tostring(text))
    if #self.lineBuffer > display.resolution.y then
        table.remove(self.lineBuffer, 1)
    end
    self:updateScreen()
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
    end
    self.bootAddr = computer.getBootAddress()
    
    display:initialize()
    self.isInitialized = true
end

internal:initialize()

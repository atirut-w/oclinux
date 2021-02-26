-- OCLinux kernel by Atirut Wattanamongkol(WattanaGaming)
_G.boot_invoke = nil

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
-- local unicode = unicode or require('unicode')

-- Kernel table containing built-in functions.
local kernel = {}
kernel.modules = {}
kernel.display = {
    isInitialized = false,
    gpu = nil,
    resolution = {
        w = 0,
        h = 0
    },
    
    initialize = function(self)
        if (self.isInitialized) then
            return false
        end
        self.gpu = component.proxy(component.list("gpu")())
        self.resolution.w, self.resolution.h = self.gpu.getResolution()
        
        self.isInitialized = true
        return true
    end,
    
    -- A very basic and barebone system for putting texts on the screen.
    simpleBuffer = {
        lineBuffer = {},
        
        updateScreen = function(self)
            local gpu = kernel.display.gpu
            local resolution = kernel.display.resolution
            if #self.lineBuffer > resolution.h then
                while #self.lineBuffer > resolution.h do
                    table.remove(self.lineBuffer, 1)
                end
                -- Scroll instead of redrawing the entire screen. This reduce screen flickering.
                gpu.copy(0, 1, resolution.w, resolution.h, 0, -1)
                gpu.fill(1, resolution.h, resolution.w, 1, " ")
                gpu.set(1, resolution.h, self.lineBuffer[resolution.h])
                return
            end
            gpu.set(1, #self.lineBuffer, self.lineBuffer[#self.lineBuffer])
        end,
        
        print = function(self, text)
            text = text or ""
            text = tostring(text)
            if text:len() > kernel.display.resolution.w then
                local function split(str, max_line_length)
                    local lines = {}
                    local line
                    str:gsub('(%s*)(%S+)',
                    function(spc, word)
                        if not line or #line + #spc + #word > max_line_length then
                            table.insert(lines, line)
                            line = word
                        else
                            line = line..spc..word
                        end
                    end
                )
                table.insert(lines, line)
                return lines
            end
            for _, line in ipairs(split(text, kernel.display.resolution.w)) do
                self:print(line)
            end
        else
            table.insert(self.lineBuffer, text)
        end
        self:updateScreen()
    end,
    
    write = function(self, text)
        text = text or ""
        text = tostring(text)
        self.lineBuffer[#self.lineBuffer] = self.lineBuffer[#self.lineBuffer]..text
        self:updateScreen()
    end
}
}

kernel.thread = {
    threads = {},
    nextPID = 1,
    
    new = function(self, func, name, options)
        local options = options or {}
        local pid = self.nextPID

        local threadData = {
            name = name,
            pid = pid,
            coroutine = coroutine.create(func),
            cpuTime = 0,

            errorHandler = (options.errorHandler or nil),
        }
        table.insert(self.threads, threadData)

        self.nextPID = self.nextPID + 1
        return pid
    end,
    
    cycle = function(self)
        for i,thread in ipairs(self.threads) do
            if coroutine.status(thread.coroutine) == "dead" then
                table.remove(self.threads, i)
                goto skipThread
            end

            local startTime = computer.uptime()
            local success, result = coroutine.resume(thread.coroutine)
            thread.cpuTime = computer.uptime() - startTime

            if not success and thread.errorHandler then
                thread.errorHandler(result)
            elseif not success then
                error(result)
            end
            ::skipThread::
        end
    end,

    exists = function(self, pid)
        for _,thread in ipairs(self.threads) do
            if thread.pid == pid and coroutine.status(thread.coroutine) ~= "dead" then
                return true
            end
        end
    end
}

kernel.internal = {
    isInitialized = false,
    
    readfile = function(file)
        local addr, invoke = computer.getBootAddress(), component.invoke
        local handle = assert(invoke(addr, "open", file), "Requested file "..file.." not found")
        local buffer = ""
        repeat
            local data = invoke(addr, "read", handle, math.huge)
            buffer = buffer .. (data or "")
        until not data
        invoke(addr, "close", handle)
        return buffer
    end,
    
    copy = function(obj, seen)
        if type(obj) ~= 'table' then return obj end
        if seen and seen[obj] then return seen[obj] end
        local s = seen or {}
        local res = setmetatable({}, getmetatable(obj))
        s[obj] = res
        for k, v in pairs(obj) do res[kernel.internal.copy(k, s)] = kernel.internal.copy(v, s) end
        return res
    end,
    
    loadfile = function(file, env, isSandbox)
        if isSandbox == true then
            local sandbox = kernel.internal.copy(env)
            sandbox._G = sandbox
            -- sandbox.component = nil
            -- sandbox.computer = nil
            return load(kernel.internal.readfile(file), "=" .. file, "bt", sandbox)
        else
            return load(kernel.internal.readfile(file), "=" .. file, "bt", env)
        end
    end,
    
    initialize = function(self)
        if (self.isInitialized) then -- Prevent the function from running again once initialized
            return false
        end
        self.bootAddr = computer.getBootAddress()
        kernel.display:initialize()
        
        kernel.display.simpleBuffer:print("Loading and executing /sbin/init.lua")
        kernel.thread:new(self.loadfile("/sbin/init.lua", _G, false), "init", {
            errorHandler = function(err) -- Special handler.
                computer.beep(1000, 0.1)
                local print = function(a) kernel.display.simpleBuffer:print(a) end
                print("Error whilst executing init:")
                print("  "..tostring(err))
                print("")
                print("Halted.")
                while true do computer.pullSignal() end
            end,
            sandbox = true
        })
        
        self.isInitialized = true
        return true
    end
}

system = {
    deviceInfo = (function() return computer.getDeviceInfo() end)(),
    architecture = (function() return computer.getArchitecture() end)(),
    bootAddress = (function() return computer.getBootAddress() end)(),
    display = {
        getGPU = function() return kernel.display.gpu end,
        simplePrint = function(message) kernel.display.simpleBuffer:print(message) end,
        simpleWrite = function(message) kernel.display.simpleBuffer:print(message) end,
    },
    kernel = {
        readfile = function(file) return kernel.internal.readfile(file) end,
        initModule = function(name, data, isSandbox)
            assert(name ~= "", "Module name cannot be blank or nil")
            assert(data ~= "", "Module data cannot be blank or nil")
            
            local modfunc = nil
            if isSandbox == true then
                modfunc = load(data, "=" .. name, "bt", kernel.internal.copy(_G))
            else
                modfunc = load(data, "=" .. name, "bt", _G)
            end
            local success, result = pcall(modfunc)
            
            if success and result then kernel.modules[name] = result return true
            elseif not success then error("Module execution error:\r"..result) end
        end,
        getModule = function(name)
            assert(kernel.modules[name], "Invalid module name")
            return kernel.modules[name]
        end,
        thread = {
            new = function(func, name, options) return kernel.thread:new(func, name, options) end,
            exists = function(pid) return kernel.thread:exists(pid) end,
            list = function() return kernel.thread.threads end,
        },
    },
}

kernel.internal:initialize()
while coroutine.status(kernel.thread.threads[1].coroutine) ~= "dead" do
    kernel.thread:cycle()
    
    -- Clean up nil threads
    -- for pid=1,#kernel.threads.coroutines do
    --   local thread = kernel.threads.coroutines[pid]
    --   if thread == nil then
    --     table.remove(kernel.threads.coroutines, pid)
    --   end
    -- end
end

kernel.display.simpleBuffer:print("Init has returned.")

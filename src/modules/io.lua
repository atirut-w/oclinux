-- io.lua: reimplementation of Lua's IO library
io = {}

-- Base object for file descriptors.
io.file = object:new({
    proxy = nil,
    handle = nil,

    read = function(self, mode)
        checkArg(1, mode, "string")
        return switch(mode, {
            ["default"] = function() error("unknown or unsupported read mode") end,
            ["a"] = function ()
                local buffer = ""
                repeat
                    -- local data, reason = component.invoke(fs,"read",handle,math.huge)
                    local data, reason = self.proxy.read(self.handle, math.huge)
                    if not data and reason then
                        error(reason)
                    end
                    buffer = buffer .. (data or "")
                until not data
                return buffer
            end,
        })
    end,

    write = function(self, value)
        self.proxy.write(self.handle, value)
    end,

    close = function(self)
        self.proxy.close(self.handle)
    end
})

function io.open(path, mode)
    checkArg(1, path, "string")
    mode = mode or "r"
    local fs = component.proxy(computer.getBootAddress())
    return io.file:new({
        proxy = fs,
        handle = fs.open(path, mode)
    })
end

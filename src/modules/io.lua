-- io.lua: reimplementation of Lua's IO library
io = {
    stderr = nil,
    stdin = nil,
    stdout = nil
}

-- Base object for file descriptors.
io.file = object:new({
    path = nil,
    temp = false,
    proxy = nil,
    handle = nil,
    buffer = "",

    close = function(self)
        self.proxy.close(self.handle)
        if self.temp == true then
            self.proxy.remove(self.path)
        end
    end,

    flush = function(self)
        self.proxy.write(self.handle, self.buffer)
    end,

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

    write = function(self, ...)
        self.buffer = self.buffer..table.concat({...})
    end,
})

function io.open(path, mode)
    checkArg(1, path, "string")
    mode = mode or "r"
    local fs = component.proxy(computer.getBootAddress())
    return io.file:new({
        path = path,
        proxy = fs,
        handle = fs.open(path, mode)
    })
end

function io.close(file)
    if file then
        file:close()
    else
        io.stdout:close()
    end
end

function io.flush(file)
    if file then
        file:flush()
    else
        io.stdout:flush()
    end
end

function io.input(file)
    if file then
        io.stdin = io.open(file, "r")
    else
        return io.stdin
    end
end

function io.output(file)
    if file then
        io.stdout = io.open(file, "w")
    else
        return io.stdout
    end
end

function io.tmpfile()
    local fs = component.proxy(computer.getBootAddress())
    local path = string.format("%x", math.random(0x0000, 0xFFFF))
    return io.file:new({
        path = path,
        temp = true,
        proxy = fs,
        handle = fs.open(path, "w")
    })
end

function io.write(...)
    io.output():write(...)
end

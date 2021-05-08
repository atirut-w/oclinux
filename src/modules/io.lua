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
    canRead = false,
    canWrite = false,
    proxy = nil,
    handle = nil,
    bufferSize = 256,
    readBuffer = "",
    writeBuffer = "",

    close = function(self)
        if self.canWrite then self:flush() end
        self.readBuffer = ""
        self.proxy.close(self.handle)
        if self.temp == true then
            self.proxy.remove(self.path)
        end
    end,

    flush = function(self)
        if self.canWrite then
            self.proxy.write(self.handle, self.writeBuffer)
            self.writeBuffer = ""
        else
            error("cannot flush stream using "..self.mode.." mode", 2)
        end
    end,

    read = function(self, mode)
        checkArg(1, mode, "string")
        local fileSize = self.proxy.size(self.path)
        local function capBuffer()
            self.readBuffer = self.readBuffer:sub(#self.readBuffer - self.bufferSize + 1)
        end
        if self.canRead then
            return switch(mode, {
                ["default"] = function() error("read mode "..mode.." is not supported") end,
                ["a"] = function()
                    local i = 0
                    if #self.readBuffer < fileSize then -- If there is not enough data in the read buffer.
                        repeat
                            local data, reason = self.proxy.read(self.handle, self.bufferSize)
                            if not data and reason then
                                error(reason)
                            end
                            self.readBuffer = self.readBuffer .. (data or "")
                        until not data
                    end
                    local ret = self.readBuffer:sub(#self.readBuffer - fileSize, #self.readBuffer)
                    capBuffer()
                    return ret
                end,
            })
        else
            error("cannot read stream using "..self.mode.." mode", 2)
        end
    end,

    write = function(self, ...)
        if self.canWrite then
            local data = table.concat({...})
            -- Is there enough space in the write buffer to accommodate data?
            if #data + #self.writeBuffer <= self.bufferSize then
                self.writeBuffer = self.writeBuffer .. data
            else
                self.writeBuffer = self.writeBuffer .. data
                self:flush()
            end
        else
            error("cannot write to stream using "..self.mode.." mode", 2)
        end
    end,
})

function io.open(path, mode)
    checkArg(1, path, "string")
    mode = mode or "r"
    local fs = component.proxy(computer.getBootAddress())
    if not fs.exists(path) then return nil end
    local file = io.file:new({
        path = path,
        mode = mode,
        proxy = fs,
        handle = fs.open(path, mode)
    })
    file.canRead = mode == ("r" or "r+" or "w+" or "a+")
    file.canWrite = mode == ("w" or "r+" or "w+" or "a+")

    return file
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

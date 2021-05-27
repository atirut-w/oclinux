-- io.lua: reimplementation of Lua's IO library
io = {
    stderr = nil,
    stdin = nil,
    stdout = nil,
}

do
    -- Base class for file descriptors.
    -- TOOD: Implement buffering
    local file = class("file")
    function file:initialize(path, mode, proxy, temp)
        assert(path and mode and proxy)
        self._path = path
        self._mode = mode
        self._proxy = proxy
        self._handle = proxy.open(path, mode)
        self._size = proxy.size(path)
        self._canRead = (mode == "r") or (mode == "r+") or (mode == "w+") or (mode == "a+")
        self._canWrite = (mode == "w") or (mode == "r+") or (mode == "w+") or (mode == "a+")
        self._temp = temp
    end

    function file:close()
        self._proxy.close(self._handle)
        if self._temp then
            self._proxy.remove(self._path)
        end
    end

    function file:flush()
        -- if self._canWrite then
        --     self._proxy.write(self._handle, self._writeBuffer)
        --     self._writeBuffer = ""
        -- else
        --     error("cannot flush stream because this file is opened with "..self._mode.." mode", 2)
        -- end
    end

    function file:read(mode)
        if self._canRead then
            local function read(count)
                if count <= 1024 then
                    return self._proxy.read(self._handle, count)
                else
                    local buffer = ""
                    repeat
                        local data, reason = self._proxy.read(self._handle, math.huge)
                        if not data and reason then
                            error(reason)
                        end
                        buffer = buffer .. (data or "")
                    until not data
                    return buffer
                end
            end

            if type(mode) == "string" then
                return switch(mode, {
                    ["default"] = function() error("read mode "..mode.." is unknown or not supported") end,
                    ["a"] = function()  return read(self._size) end,
                    ["*l"] = function()
                        -- Slow and inefficient but hey, it works:tm:.
                        -- TODO: Optimize this function.
                        local line = ""
                        local currentChar = ""
                        while true do
                            currentChar = read(1)
                            if currentChar == "\n" then -- screw \r
                                break
                            else
                                line = line .. currentChar
                            end
                        end
                        return line
                    end
                })
            elseif type(mode) == "number" then
                return read(mode)
            end
        else
            error("cannot read from stream because this file is opened with "..self._mode.." mode", 2)
        end
    end

    function file:write(...)
        if self._canWrite then
            self._proxy.write(self._handle, table.concat({...}))
        else
            error("cannot write to stream because this file is opened with "..self._mode.." mode", 2)
        end
    end

    io._file = file
end

function io.open(path, mode)
    checkArg(1, path, "string")
    mode = mode or "r"
    local fs = component.proxy(computer.getBootAddress())
    if not fs.exists(path) then return nil else return io._file:new(path, mode, fs) end
end

function io.close(file)
    if file then file:close() else io.stdout:close() end
end

function io.flush(file)
    if file then file:flush() else io.stdout:flush() end
end

function io.input(file)
    if file then io.stdin = io.open(file, "r") else return io.stdin end
end

function io.output(file)
    if file then io.stdout = io.open(file, "w") else return io.stdout end
end

function io.tmpfile()
    local fs = component.proxy(computer.getBootAddress())
    local path = string.format("%x", math.random(0x0000, 0xFFFF))
    return io._file:new(path, "w", fs, true)
end

function io.write(...)
    io.output():write(...)
end

local filesystem = system.kernel.getModule("filesystem")

function dofile(path)
    local file = filesystem.open(path, "r")
    assert(file, path.." not found")
    local script = ""
    do
        local buffer = ""
        repeat
            local data = file:read(math.huge)
            buffer = buffer .. (data or "")
        until not data
        script = buffer
        file:close()
    end

    local func = load(script, "=" .. path, "bt", _G)
    local success, result = pcall(func)

    if success and result then return result
    elseif not success then error("File execution error:\r"..result) end
end

function dofileThreaded(path, option)
    option = option or {}
    local file = filesystem.open(path, "r")
    assert(file, path.." not found")
    local script = ""
    do
        local buffer = ""
        repeat
            local data = file:read(math.huge)
            buffer = buffer .. (data or "")
        until not data
        script = buffer
        file:close()
    end

    local func = load(script, "=" .. path, "bt", _G)
    return system.kernel.thread.new(func, (option.threadName or "dofile thread"), {
        errorHandler = (option.errorHandler or function() end)
    })
end

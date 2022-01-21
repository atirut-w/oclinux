---@param path string
---@param env table
---@return function
function kernel.loadfile(path, env)
    local f, e = kernel.filesystem.open(path, "r")
    if not f then
        return nil, e
    end

    local exe = ""
    repeat
        local data = f:read(math.huge)
        exe = exe .. (data or "")
    until not data
    f:close()

    local chunk, e = load(exe, "=" .. path, "t", env or {})
    if not chunk then
        return nil, e
    end

    return chunk
end

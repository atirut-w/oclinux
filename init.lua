if computer.getArchitecture() ~= "Lua 5.3" then
    computer.setArchitecture("Lua 5.3")
end

component.proxy(component.list("gpu")()).set(1,1,"Loading kernel...")

---@type function
local kernel
do
    ---@type FilesystemProxy
    local fs = component.proxy(computer.getBootAddress())
    local handle = fs.open("/boot/kernel.lua")

    if not handle then
        error("Kernel not found", 0)
    end

    local k_content = ""
    repeat
        local data = fs.read(handle, math.huge)
        k_content = k_content .. (data or "")
    until not data

    local err
    kernel, err = load(k_content, "=kernel", "t", _G)
    if not kernel then
        error(err, 0)
    end
end

local k_coroutine = coroutine.create(kernel)
repeat
    local ok, err = coroutine.resume(k_coroutine)
    if not ok then
        error(debug.traceback(k_coroutine, err), 0)
    end
until coroutine.status(k_coroutine) == "dead"

---@diagnostic disable-next-line: lowercase-global
kernel = {}
kernel.syscalls = {}

do
    --#include "3rd/filesystem.lua" "filesystem"

    kernel.syscalls.open = filesystem.open
    kernel.syscalls.mount = filesystem.mount
    kernel.syscalls.umount = filesystem.umount

    kernel.filesystem = filesystem
end
do
    local success, err = kernel.filesystem.mount(computer.getBootAddress(), "/")
    assert(success, err)
end

--#include "devfs.lua"
--#include "console.lua"
--#include "printk.lua"
--#include "scheduler.lua"

local function gen_env(...)
    local env = {}
    for k, v in pairs(_G) do
        if k ~= "kernel" then
            env[k] = v
        end
    end
    for _, addition in ipairs({...}) do
        for k, v in pairs(addition) do
            env[k] = v
        end
    end
    return env
end

function kernel.panic(fmt, ...)
    kernel.printk("\aKERNEL PANIC")
    if fmt then
        kernel.printk(": %s\n", fmt:format(...))
    else
        kernel.printk("\n")
    end
    kernel.printk("System halted.\n")
    while true do
        computer.pullSignal()
    end
end

do
    local printk = kernel.printk
    local f = kernel.filesystem.open("/sbin/init.lua", "r")
    if not f then
        kernel.panic("Init not found")
    end

    printk("Loading init...\n")
    local chunk, err = load(f:read(math.huge), "=init", "t", gen_env(kernel.syscalls))
    if not chunk then
        kernel.panic("Could not load init: " .. err)
    end

    kernel.scheduler.spawn("init", chunk, {
        error = function(err, co)
            kernel.panic("Init crashed: " .. debug.traceback(co, tostring(err)))
        end
    })
end

local last_signal = {}
kernel.get_signal = setmetatable({}, {
    __call = function(self, sig)
        return table.unpack(last_signal)
    end
})

repeat
    last_signal = {computer.pullSignal(0)}
    kernel.scheduler.resume()
until not kernel.scheduler.threads[1]

computer.shutdown()

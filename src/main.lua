---@diagnostic disable-next-line: lowercase-global
kernel = {}
kernel.syscalls = {}

--#include "eventhooks.lua"
--#include "filesystem.lua"
--#include "loadfile.lua"

kernel.filesystem.mount(computer.getBootAddress(), "/")
--#include "devfs.lua"

--#include "3rd/tty.lua"
do
    local gpu = component.proxy(component.list("gpu")())
    kernel.create_tty(gpu, gpu.getScreen())
    kernel.filesystem.link("/dev/tty0", "/dev/console")
end

--#include "printk.lua"
--#include "scheduler.lua"

function kernel.gen_env(...)
    local env = {}
    for k, v in pairs(_G) do
        if not ({
            kernel = true,
            computer = true,
            component = true,
        })[k] then
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

kernel.scheduler.spawn("/sbin/init.lua", "/sbin/init.lua")

local last_signal = {}
kernel.get_signal = setmetatable({}, {
    __call = function(self, sig)
        return table.unpack(last_signal)
    end
})

local last_uptime = computer.uptime()
repeat
    last_signal = {computer.pullSignal(0)}
    if kernel.hooks[last_signal[1]] and last_signal[1] ~= "timer" then
        for _, hook in ipairs(kernel.hooks[last_signal[1]]) do
            hook(table.unpack(last_signal))
        end
    end
    if kernel.hooks.timer then
        for _, hook in ipairs(kernel.hooks.timer) do
            hook(computer.uptime() - last_uptime)
        end
    end
    last_uptime = computer.uptime()
until not kernel.scheduler.kill(1, 0)

while true do
    computer.pullSignal()
end

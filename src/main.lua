---@diagnostic disable-next-line: lowercase-global
kernel = {}
kernel.syscalls = {}

--#include "eventhooks.lua"

do
    --#include "3rd/filesystem.lua" "filesystem"

    kernel.syscalls.mount = filesystem.mount
    kernel.syscalls.umount = filesystem.umount

    function kernel.syscalls.chdir(path)
        assert(path, "missing path")
        path = filesystem.canonical(path)
        assert(filesystem.exists(path), "path does not exist")
        assert(filesystem.isDirectory(path), "path is not a directory")
        kernel.scheduler.threads[kernel.scheduler.current_pid].working_dir = path
    end

    ---@type file*[]
    local open_files = {}

    function kernel.syscalls.open(file, mode)
        file = filesystem.canonical(file)
        if file:sub(1, 1) ~= "/" then
            file = kernel.scheduler.threads[kernel.scheduler.current_pid].working_dir .. "/" .. file
        end
        local f, e = filesystem.open(file, mode)
        assert(f, e)
        open_files[#open_files + 1] = f
        return #open_files
    end

    function kernel.syscalls.close(fd)
        assert(open_files[fd], "bad file descriptor")
        open_files[fd]:close()
        open_files[fd] = nil
    end

    function kernel.syscalls.read(fd, size)
        assert(open_files[fd], "bad file descriptor")
        return open_files[fd]:read(size)
    end

    function kernel.syscalls.write(fd, data)
        assert(open_files[fd], "bad file descriptor")
        return open_files[fd]:write(data)
    end

    function kernel.syscalls.lseek(fd, offset, whence)
        assert(open_files[fd], "bad file descriptor")
        return open_files[fd]:seek(offset, whence)
    end

    kernel.filesystem = filesystem
end
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

local function gen_env(...)
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

do
    local printk = kernel.printk
    local f = kernel.filesystem.open("/sbin/init.lua", "r")
    if not f then
        kernel.panic("Init not found")
    end

    printk("Loading init...\n")
    local init_content = ""
    repeat
        local data = f:read(math.huge)
        init_content = init_content .. (data or "")
    until not data
    local chunk, err = load(init_content, "=init", "t", gen_env(kernel.syscalls))
    if not chunk then
        kernel.panic("Could not load init: " .. err)
    end

    kernel.scheduler.spawn("init", chunk, "/", nil, {
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

local last_uptime = computer.uptime()
repeat
    last_signal = {computer.pullSignal(0)}
    kernel.scheduler.resume()

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
until not kernel.scheduler.threads[1]

computer.shutdown()

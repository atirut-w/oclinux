-- Round-robin coroutine scheduler

do
    ---@class Thread
    ---@field coroutine thread
    ---@field cwd string
    ---@field comm string
    ---@field cmdline string[]
    ---@field environ string[]
    ---@field fd table<string, function>[]

    local scheduler = {}
    scheduler.threads = {}
    scheduler.current_pid = 0

    --- Spawn a new thread and return its PID.
    ---@param path string
    ---@param args string[]
    ---@param env string[]
    ---@return integer
    function scheduler.spawn(path, args, env)
        local chunk, e = kernel.loadfile(path, kernel.gen_env(kernel.syscalls))
        assert(chunk, e)

        ---@type Thread
        local thread = {}
        thread.coroutine = coroutine.create(chunk)
        thread.cwd = "/"
        thread.comm = (args or {})[1]
        thread.cmdline = args or {}
        thread.environ = env or {}
        thread.fd = {
            kernel.filesystem.open("/dev/console", "r"),
            kernel.filesystem.open("/dev/console", "w"),
            kernel.filesystem.open("/dev/console", "w"),
        }

        scheduler.threads[#scheduler.threads + 1] = thread
        return #scheduler.threads
    end

    --- Fork the current thread.
    ---@param func function
    ---@return integer
    function kernel.syscalls.fork(func)
        local thread = {}

        for k, v in pairs(scheduler.threads[scheduler.current_pid]) do
            thread[k] = v
        end
        thread.coroutine = coroutine.create(func)

        scheduler.threads[#scheduler.threads + 1] = thread
        return #scheduler.threads
    end

    --- Execute a program in the current thread, replacing the current program.
    ---@param path string
    ---@param args string[]
    ---@param env string[]
    function kernel.syscalls.execve(path, args, env)
        local chunk, e = kernel.loadfile(path, kernel.gen_env(kernel.syscalls))
        assert(chunk, e)

        local thread = scheduler.threads[scheduler.current_pid]
        thread.coroutine = coroutine.create(chunk)
        thread.comm = (args or {})[1]
        thread.cmdline = args or {}
        thread.environ = env or {}

        scheduler.threads[scheduler.current_pid] = thread
    end

    --- Kill a thread.
    ---@param pid number
    ---@param signal number
    function scheduler.kill(pid, signal)
        -- TODO: Actually implement signals
        if scheduler.threads[pid] then
            if signal ~= 0 then
                scheduler.threads[pid] = nil
            end
            return true
        else
            return false
        end
    end
    kernel.syscalls.kill = scheduler.kill

    kernel.register_hook("timer", function()
        for pid, thread in pairs(scheduler.threads) do
            scheduler.current_pid = pid
            if coroutine.status(thread.coroutine) == "dead" then
                scheduler.kill(pid)
            else
                local ok, e = coroutine.resume(thread.coroutine, table.unpack(thread.cmdline), table.unpack(thread.environ))
                if not ok then
                    thread.fd[3]:write(debug.traceback(thread.coroutine, e) .. "\n")
                end
            end
        end
        scheduler.current_pid = 0
    end)
    
    kernel.scheduler = scheduler
end

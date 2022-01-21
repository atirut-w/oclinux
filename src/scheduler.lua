-- Round-robin coroutine scheduler

do
    ---@class Thread
    ---@field name string
    ---@field coroutine thread
    ---@field args table
    ---@field working_dir string
    ---@field handlers table<string, function>

    local scheduler = {}
    scheduler.current_pid = 0
    ---@type Thread[]
    scheduler.threads = {}

    --- Spawn a new thread and return its PID.
    ---@param name string
    ---@param func function
    ---@param dir string
    ---@param args table
    ---@param handlers table<string, function>
    ---@return integer
    function scheduler.spawn(name, func, dir, args, handlers)
        scheduler.threads[#scheduler.threads + 1] = {
            coroutine = coroutine.create(func),
            name = name,
            args = args,
            working_dir = kernel.filesystem.canonical(dir),
            handlers = handlers or {},
        }
        return #scheduler.threads
    end

    --- Fork a new thread and return its PID. 
    --- Since it is impossible to fork a coroutine, a new function must be used instead of the original. The new thread will inherit other properties of the original thread.
    ---@param func function
    ---@return integer
    function kernel.syscalls.fork(func)
        assert(scheduler.current_pid ~= 0, "cannot fork from kernel")
        local thread = scheduler.threads[scheduler.current_pid]
        local new_thread = {
            coroutine = coroutine.create(func),
            name = thread.name,
            args = thread.args,
            working_dir = thread.working_dir,
            handlers = thread.handlers,
        }
        scheduler.threads[#scheduler.threads + 1] = new_thread
        return #scheduler.threads
    end

    kernel.register_hook("timer", function()
        local cleanup = {}
        for i = 1, #scheduler.threads do
            scheduler.current_pid = i
            local thread = scheduler.threads[i]
            if thread then
                if coroutine.status(thread.coroutine) == "dead" then
                    cleanup[#cleanup + 1] = i
                else
                    local ok, err = coroutine.resume(thread.coroutine, thread.args and table.unpack(thread.args))
                    if not ok then
                        table.insert(cleanup, i)

                        if thread.handlers.error then
                            thread.handlers.error(err, thread.coroutine)
                        else
                            kernel.printk("%s\n", debug.traceback(thread.coroutine, err))
                        end
                    end
                end
            end
        end
        scheduler.current_pid = 0
        for _, pid in ipairs(cleanup) do
            scheduler.threads[pid] = nil
        end
    end)

    --- Kill a thread.
    ---@param pid number
    function scheduler.kill(pid)
        scheduler.threads[pid] = nil
    end
    
    kernel.scheduler = scheduler
end

-- Round-robin coroutine scheduler

do

    ---@class Thread
    ---@field name string
    ---@field coroutine thread
    ---@field handlers table<string, function>

    local scheduler = {}
    scheduler.current_pid = 0
    ---@type Thread[]
    scheduler.threads = {}

    --- Spawn a new thread and return its PID.
    ---@param name string
    ---@param func function
    ---@param handlers table<string, function>
    ---@return number
    function scheduler.spawn(name, func, handlers)
        scheduler.threads[#scheduler.threads + 1] = {
            coroutine = coroutine.create(func),
            name = name,
            handlers = handlers or {},
        }
        return #scheduler.threads
    end

    --- Resume all threads.
    function scheduler.resume()
        local cleanup = {}
        for i = 1, #scheduler.threads do
            scheduler.current_pid = i
            local thread = scheduler.threads[i]
            if thread then
                if coroutine.status(thread.coroutine) == "dead" then
                    cleanup[#cleanup + 1] = i
                else
                    local ok, err = coroutine.resume(thread.coroutine)
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
    end

    --- Kill a thread.
    ---@param pid number
    function scheduler.kill(pid)
        scheduler.threads[pid] = nil
    end
    
    kernel.scheduler = scheduler
end

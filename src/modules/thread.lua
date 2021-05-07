os.thread = {
    threads = {},
    nextPID = 1,
    
    new = function(self, func, name, options)
        local options = options or {}
        local pid = self.nextPID

        local threadData = {
            name = name,
            pid = pid,
            status = "normal",
            coroutine = coroutine.create(func),
            cpuTime = 0,

            errorHandler = (options.errorHandler or nil),
            argument = (options.argument or nil)
        }
        table.insert(self.threads, threadData)

        self.nextPID = self.nextPID + 1
        return pid
    end,
    
    cycle = function(self)
        for i,thread in ipairs(self.threads) do
            if coroutine.status(thread.coroutine) == "dead" then
                table.remove(self.threads, i)
                goto skipThread
            elseif thread.status == "suspended" then
                goto skipThread
            end

            local startTime = computer.uptime()
            local success, result = coroutine.resume(thread.coroutine, thread.argument)
            thread.cpuTime = computer.uptime() - startTime

            if thread.argument ~= nil then thread.argument = nil end

            if not success and thread.errorHandler then
                thread.errorHandler(result)
            elseif not success then
                error(result)
            end
            ::skipThread::
        end
    end,

    getIndex = function(self, pid)
        for index,thread in ipairs(self.threads) do
            if thread.pid == pid then
                return index
            end
        end
    end,

    get = function(self, pid)
        if self:getIndex(pid) then return self.threads[self:getIndex(pid)] end
    end,

    kill = function(self, pid)
        if self:exists(pid) then self.threads[self:getIndex(pid)] = nil end
    end,

    exists = function(self, pid)
        if self:get(pid) then return true end
    end
}

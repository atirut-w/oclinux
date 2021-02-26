print("Computer status:")
print("\tAddress: "..computer.address())
print("\tUptime: "..computer.uptime())
print("\tTotal memory: "..computer.totalMemory().."("..computer.totalMemory() - computer.freeMemory().." used, "..computer.freeMemory().." free)")

local threadList = system.kernel.thread.list()
print("\tTotal thread(s): "..#threadList)
print("\t\tPID, NAME, CPU TIME, STATUS")
coroutine.yield() -- Make sure we get every task by waiting one cycle
for pid=1,#threadList do
    local thread = threadList[pid]
    if thread == nil then print("\t\t"..pid.."\tnil thread")
    else print("\t\t"..thread.pid.."\t"..thread.name.."\t"..thread.cpuTime.."\t"..coroutine.status(thread.coroutine)) end
    -- print("\t\t"..pid.."\t"..thread.cname.."\t"..thread.cpuTime.."\t"..coroutine.status(thread.co))
    coroutine.yield()
end

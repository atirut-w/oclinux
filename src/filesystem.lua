do
    --#include "3rd/filesystem.lua" "filesystem"
    kernel.syscalls.mount = filesystem.mount
    kernel.syscalls.umount = filesystem.umount

    ---@param path string
    ---@param mode string
    ---@return integer?, string?
    function kernel.syscalls.open(path, mode)
        local f, e = filesystem.open(path, mode)
        if f then
            local current_pid = kernel.scheduler.current_pid
            local fd = #kernel.scheduler.threads[current_pid].fd + 1
            kernel.scheduler.threads[current_pid].fd[fd] = f
            return fd, nil
        else
            return nil, e
        end
    end

    ---@param fd integer
    function kernel.syscalls.close(fd)
        local current_pid = kernel.scheduler.current_pid
        if not kernel.scheduler.threads[current_pid].fd[fd] then
            return nil, "bad file descriptor"
        end
        kernel.scheduler.threads[current_pid].fd[fd]:close()
        kernel.scheduler.threads[current_pid].fd[fd] = nil
    end

    ---@param fd integer
    ---@param count integer
    ---@return string?, string?
    function kernel.syscalls.read(fd, count)
        local current_pid = kernel.scheduler.current_pid
        if not kernel.scheduler.threads[current_pid].fd[fd] then
            return nil, "bad file descriptor"
        end
        return kernel.scheduler.threads[current_pid].fd[fd]:read(count)
    end

    ---@param fd integer
    ---@param data string
    ---@return boolean
    function kernel.syscalls.write(fd, data)
        local current_pid = kernel.scheduler.current_pid
        if not kernel.scheduler.threads[current_pid].fd[fd] then
            return nil, "bad file descriptor"
        end
        return kernel.scheduler.threads[current_pid].fd[fd]:write(data)
    end

    ---@param fd integer
    ---@param offset integer
    ---@param whence integer
    ---@return integer
    function kernel.syscalls.lseek(fd, offset, whence)
        local current_pid = kernel.scheduler.current_pid
        if not kernel.scheduler.threads[current_pid].fd[fd] then
            return nil, "bad file descriptor"
        end
        return kernel.scheduler.threads[current_pid].fd[fd]:lseek(offset, whence)
    end

    kernel.filesystem = filesystem
end

do
    ---@class DeviceFile
    ---@field read fun(count: integer): string
    ---@field write fun(data: string)

    --- List of device files.
    ---@type table<string, DeviceFile>
    local device_files = {}

    --- Register a device file.
    ---@param name string
    ---@param file DeviceFile
    function kernel.register_chrdev(name, file)
        assert(not name:match("/"), "device file name cannot contain '/'")
        assert(file, "file is nil")
        file.read = file.read or function() return "" end
        file.write = file.write or function() end

        device_files[name] = file
    end

    kernel.filesystem.mount({
        open = function(path, mode)
            assert(not path:match("/"), "device file name cannot contain '/'")
            assert(device_files[path], "no such device file")
            return path
        end,
        read = function(path, count)
            assert(not path:match("/"), "device file name cannot contain '/'")
            assert(device_files[path], "no such device file")
            return device_files[path].read(count)
        end,
        write = function(path, data)
            assert(not path:match("/"), "device file name cannot contain '/'")
            assert(device_files[path], "no such device file")
            return device_files[path].write(data)
        end,
        exists = function(path)
            assert(not path:match("/"), "device file name cannot contain '/'")
            return device_files[path] ~= nil
        end,
    }, "/dev")
end

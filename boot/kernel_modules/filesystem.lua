-- Simple filesystem API with multiple mount points

local filesystems = {}
local lib = {}

local function hasMountPoint(path)
    for k, v in pairs(filesystems) do
        local p = v[1]
        if p == path then -- if is same path
            return true
        end
    end
    return false
end

function lib.mount(path, fs)
    if hasMountPoint(path) then
		error(path .. " is arleady mounted")
	end
    table.insert(filesystems, {path, fs})
end

function lib.umount(path)
    for k, v in pairs(filesystems) do
        local p = v[1]
        if p == path then -- if is same path
            table.remove(filesystems, k)
        end
    end
end

return lib
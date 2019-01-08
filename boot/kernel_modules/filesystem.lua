-- Simple filesystem API with multiple mount points
local unicode = unicode or require("unicode")
local filesystems = {}
local lib = {}
local mtab = {name="", children={}, links={}}
local fstab = {}

function lib.segments(path)
    local parts = {}
    for part in path:gmatch("[^\\/]+") do
        local current, up = part:find("^%.?%.$")
        if current then
            if up == 2 then
                table.remove(parts)
            end
        else
            table.insert(parts, part)
        end
    end
    return parts
end

local function hasMountPoint(path)
    return lib.getNode(path) ~= nil
end

function lib.canonical(path)
  local result = table.concat(segments(path), "/")
  if unicode.sub(path, 1, 1) == "/" then
    return "/" .. result
  else
    return result
  end
end

function lib.concat(...)
  local set = table.pack(...)
  for index, value in ipairs(set) do
    checkArg(index, value, "string")
  end
  return lib.canonical(table.concat(set, "/"))
end


function lib.mount(path, fs)
    if hasMountPoint(path) then
        error(path .. " is arleady mounted")
    end
    table.insert(filesystems, {path, fs})
end

function lib.findNode(path)
    local lastPath = ""
    local lastNode = {}
    local seg = lib.segments(path)
    for k, v in pairs(seg) do
        if v < table.getn(seg) then
            lastPath = lastPath .. k .. "/"
        else
            lastPath = lastPath .. k
        end
        local node = lib.getNode(lastPath)
        if node ~= nil then
            lastNode = node
        end
    end
    return lastNode
end

function lib.getNode(mountPath)
    for k, v in pairs(filesystems) do
        local p = v[1]
        if p == mountPath then -- if is same path
            return p
        end
    end
    return nil
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
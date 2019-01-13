-- Simple filesystem API with multiple mount points
local unicode = unicode or require("unicode")
local component = component or require("component")
local filesystems = {}
local lib = {}
local mtab = {name="", children={}, links={}}
local fstab = {}

function table.maxn(tab)
	local i = 0
	for k, v in pairs(tab) do
		i = math.max(i, k)
	end
	return i
end

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

local function localPath(node, path)
	local localPath = path:gsub(node.path .. "/", "")
	return localPath
end

function lib.getDrives(automount)
	local tab = {}
	-- TODO add support for drives when an standardized unmanaged filesystem is made for OC
	local i = 0
	for k, v in pairs(component.list("filesystem")) do
		-- uncorrect naming due to not knowing if it's floppy or disk drive
		table.insert(tab, "/dev/" .. "hd".. string.char(string.byte('a') + i))
		if automount then
			if not lib.contains(component.proxy(v)) then
				lib.mount("/dev/" .. "hd".. string.char(string.byte('a') + i), component.proxy(v))
			end
		end
		i = i + 1
	end
	return tab
end

function lib.exists(path)
	local node = lib.findNode(path)
	if node == nil then
		return false
	end
	local lp = localPath(node, path)
	return node.exists(lp)
end

-- Also has compatibility for older versions
function lib.isReadOnly(path)
	local node = lib.findNode(path)
	if node == nil then
		return false
	end
	local lp = localPath(node, path)
	if node.isReadOnly then
		return node.isReadOnly(lp)
	else
		return false
	end
end

function lib.getFile(path, mode)
	local node = lib.findNode(path)
	local lp = localPath(node, path)
	local file = {}
	file.handle = node.open(lp, mode)
	file.seek = function(whence, offset)
		return node.seek(file.handle, whence, offset)
	end
	file.write = function(value)
		return node.write(file.handle, value)
	end
	file.read = function(amount)
		return node.read(file.handle, amount)
	end
	file.size = function()
		return node.size(lp)
	end
	file.close = function()
		node.close(file.handle)
	end
	return file
end

function lib.size(path)
	local node = lib.findNode(path)
	if node == nil then
		return -1
	end
	local lp = localPath(node, path)
	return node.size(lp)
end

function lib.findNode(path)
	local lastPath = ""
	local lastNode = nil
	local seg = lib.segments(path)
	for k, v in pairs(seg) do
		if k < table.maxn(seg) then
			lastPath = lastPath .. v .. "/"
		else
			lastPath = lastPath .. v
		end
		local node = lib.getNode(lastPath)
		if node ~= nil then
			lastNode = node
			node.path = lastPath
		end
	end
	return lastNode
end

function lib.getNode(mountPath)
	for k, v in pairs(filesystems) do
		local p = v[1]
		if p == mountPath then -- if is same path
			p.path = mountPath
			--printInfo(p.path)
			return p
		end
	end
	return nil
end

function lib.contains(node)
	for k, v in pairs(filesystems) do
		local p = v[2]
		if p == node then
			return true
		end
	end
	return false
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
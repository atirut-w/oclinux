-- off-screen memory api using viewports
-- Please note: VRAM API doesn't work with gamax92's OCEmu due to a wrong implementation of viewports

local lib = {}
local gpu = component.proxy(component.list("gpu")())

-- Storing methods
lib.COLOR_MODE = 0x01 -- store as color (more compact)
lib.CHAR_MODE  = 0x02
local mode = lib.COLOR_MODE -- best mode (if depth is 8bits)

function lib.getSize() -- size in bytes of the vram
	local vw, vh = gpu.getViewport()
	local w, h = gpu.getResolution()
	return (w * h) - (vw * vh)
end

-- Used to increase vram but decrease user resolution
-- or to decrease vram and increase user resolution
function lib.setViewport(vw, vh)
	gpu.setViewport(vw, vh)
end

function lib.storeByte(off, b)
	local vw, vh = gpu.getViewport()
	local w, h = gpu.getResolution()
	local x = off % (w - vw)
	local y = off / (w - vw)
	gpu.set(x, y, string.char(b))
end

function lib.readByte(off, b)
	local vw, vh = gpu.getViewport()
	local w, h = gpu.getResolution()
	local x = off % (w - vw)
	local y = off / (w - vw)
	local ch = gpu.get(x, y)
	return ch
end

return lib
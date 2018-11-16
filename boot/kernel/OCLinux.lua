--OCLinux kernel

--Kernel metadata
_G._OSNAME = "OCLinux"
_G._OSVER = "1.0.0"
_G._OSVERSION = _OSNAME.." ".._OSVER

--Initialize hardware and load important built-in APIS
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

--Initialize GPU and display device
local gpu = component.list("gpu")()
local screen = component.list("screen")()
screenRes = {}
cursorPos = {
  x = 1,
  y = 1
}
--GPU initialization function and invoke function from OpenLoader
function gpuInvoke(op, arg, ...)
    local res = {}
    local n = 1
    for address in component.list('screen') do
        component.invoke(gpu, "bind", address)
        if type(arg) == "table" then
            res[#res + 1] = {component.invoke(gpu, op, table.unpack(arg[n]))}
        else
            res[#res + 1] = {component.invoke(gpu, op, arg, ...)}
        end
        n = n + 1
    end
    return res
end
if gpu and screen then
    --component.invoke(gpu, "bind", screen)
    w, h = component.invoke(gpu, "getResolution")
    local res = gpuInvoke("getResolution")
    gpuInvoke("setResolution", res)
    gpuInvoke("setBackground", 0x000000)
    gpuInvoke("setForeground", 0xFFFFFF)
    for _, e in ipairs(res)do
        table.insert(e, 1, 1)
        table.insert(e, 1, 1)
        e[#e+1] = " "
    end
    gpuInvoke("fill", res)
    cls = function()gpuInvoke("fill", res)end
end
screenRes.w, screenRes.h = gpuInvoke("getResolution")

--System-wide functions

--A very low-level GPU powered print and write function
function gpuWrite(msg)
  gpuInvoke("set", cursorPos.x, cursorPos.y, msg)
  cursorPos.x = cursorPos.x + msg:len()
end

function gpuPrint(msg)
  gpuInvoke("set", cursorPos.x, cursorPos.y, msg)
  cursorPos.x = 1
  cursorPos.y = cursorPos.y + 1
end

--Kernel-own functions

local function runInit(init)
  dofile(init)
end

local function panic(reason)
  if not reason then
    reason = "no reason specified"
  end
  gpuPrint("Kernel panic: "..reason)
  gpuPrint("")
  gpuPrint("Kernel version: ".._OSVERSION)
  gpuPrint("System uptime: "..computer.uptime())
  while true do
    computer.pullSignal()
  end
end

panic("Filesystem and loading Init is not yet implemented(Kernel not fully usable yet)")

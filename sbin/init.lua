-- Test if init.lua is loaded and executed. Also to see if error handling is working properly.
local display = coroutine.yield({
  syscall = {
    call = "getDisplay"
  }
})
i = 0
for i=1,20 do
  display.simpleBuffer:line("test "..i)
end


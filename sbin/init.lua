-- Test if init.lua is loaded and executed. Also to see if error handling is working properly.
local display = coroutine.yield({
  syscall = {
    call = "getDisplay"
  }
})
local ctx, args coroutine.yield({
  syscall = {
    call = "testCall",
    args = "djsdavbjfdgfsdvfsdbj"
  }
})

display.simpleBuffer:line(args)

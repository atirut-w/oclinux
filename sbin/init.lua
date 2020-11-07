-- Test if init.lua is loaded and executed. Also to see if error handling is working properly.
i = 0
for i=1,20 do
  kernel.display.simpleBuffer:line("Hello from init(iteration "..i..")")
  coroutine.yield()
end


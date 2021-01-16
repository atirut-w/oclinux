local gpu = system.display.getGPU()
local screenWidth, screenHeight = gpu.getResolution()

local function rainbowSide()
    while true do
        for i=1,screenHeight do
            gpu.set(screenWidth, i, tostring(math.random(1, 9)))
            coroutine.yield()
        end
    end
end

print("Me tryna launch a thread")
system.kernel.thread.new(rainbowSide, "number strip")
print("Launched and ready to go!")

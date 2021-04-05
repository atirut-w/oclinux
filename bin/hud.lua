local gpu = os.simpleDisplay.gpu
local screenWidth, screenHeight = gpu.getResolution()
local updates = 0
local interval = 10

function hud()
    while true do
        if updates == interval then
            updates = 0
            
            local string = " MEM USAGE: "..tostring(computer.totalMemory() - computer.freeMemory()).."/"..tostring(computer.totalMemory())
            gpu.fill((screenWidth - #string) - 4, screenHeight, screenWidth, 1, " ")
            gpu.setBackground(0x00ff00)
            gpu.setForeground(0x000000)
            gpu.set((screenWidth - #string), screenHeight, string)
            gpu.setBackground(0x000000)
            gpu.setForeground(0xffffff)
        end
        
        updates = updates + 1
        coroutine.yield()
    end
end

os.thread:new(hud, "mem hud")

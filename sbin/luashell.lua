local gpu = system.display.gpu
local w, h = gpu.getResolution()
gpu.fill(1, 1, w, h, " ") -- clears the screen
gpu.setForeground(0x000000)
gpu.setBackground(0xFFFFFF)
gpu.fill(1, 1, w/2, h/2, "X") -- fill top left quarter of screen
gpu.copy(1, 1, w/2, h/2, w/2, h/2) -- copy top left quarter of screen to lower right
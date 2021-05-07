os.simpleDisplay = {
    gpu = nil,
    screenWidth = nil,
    screenHeight = nil,
    cursorY = 1,
}

function os.simpleDisplay.status(msg)
    local simpleDisplay = os.simpleDisplay
    simpleDisplay.gpu.set(1, simpleDisplay.cursorY, msg)
    if simpleDisplay.cursorY == simpleDisplay.screenHeight then
        simpleDisplay.gpu.copy(1, 2, simpleDisplay.screenWidth, simpleDisplay.screenHeight - 1, 0, -1)
        simpleDisplay.gpu.fill(1, simpleDisplay.screenHeight, simpleDisplay.screenWidth, 1, " ")
    else
        simpleDisplay.cursorY = simpleDisplay.cursorY + 1
    end
end

os.simpleDisplay.gpu = component.proxy(component.list("gpu")())
os.simpleDisplay.screenWidth, os.simpleDisplay.screenHeight = os.simpleDisplay.gpu.getResolution()

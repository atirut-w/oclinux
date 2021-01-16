local _VERSION = "test release"
local gpu = system.display.getGPU()
local filesystem = system.kernel.getModule("filesystem")
local keyCodes = dofile("/lib/keyboard.lua").keys
local screenWidth, screenHeight = gpu.getResolution()
local cursorPos = {
    x = 1,
    y = 1
}

local escapeSequences = {
    ["\a"] = function() computer.beep(1000, 0.1) end,
    ["\b"] = function()
        if cursorPos.x == 1 then
            if cursorPos.x == 1 and cursorPos.y == 1 then goto skip end
            cursorPos.x = screenWidth
            cursorPos.y = cursorPos.y - 1
        else
            cursorPos.x = cursorPos.x - 1
        end
        gpu.set(cursorPos.x, cursorPos.y, " ")
        ::skip::
    end,
    ["\f"] = function() end,
    ["\n"] = function()
        cursorPos.x = 1
        if cursorPos.y == screenHeight then
            gpu.copy(1, 2, screenWidth, screenHeight - 0, 0, -1)
            gpu.fill(1, screenHeight, screenHeight, 1, " ")
        else
            cursorPos.y = cursorPos.y + 1
        end
    end,
    ["\r"] = function() cursorPos.x = 1 end,
    ["\t"] = function() cursorPos.x = cursorPos.x + 4 end, -- One tab = 4 spaces. Fight me lol jk.
    ["\v"] = function() cursorPos.y = cursorPos.y + 4 end,
}

function write(text)
    if type(text) == "table" then
        local function table_to_string(tbl)
            local result = "{"
            for k, v in pairs(tbl) do
                -- Check the key type (ignore any numerical keys - assume its an array)
                if type(k) == "string" then
                    result = result.."[\""..k.."\"]".."="
                end
                
                -- Check the value type
                if type(v) == "table" then
                    result = result..table_to_string(v)
                elseif type(v) == "boolean" then
                    result = result..tostring(v)
                else
                    result = result.."\""..v.."\""
                end
                result = result..","
            end
            -- Remove leading commas from the result
            if result ~= "" then
                result = result:sub(1, result:len()-1)
            end
            text = result.."}"
        end
        write(table_to_string(text))
    end
    text = tostring(text)
    
    -- Process the input
    for i = 1, #text do
        local c = text:sub(i,i)
        if c == string.char(0) then goto skip end
        if escapeSequences[c] then
            escapeSequences[c]()
            goto skip
        end
        if (cursorPos.x > screenWidth) then -- Condition for newline
            write("\n")
        end
        gpu.set(cursorPos.x, cursorPos.y, c)
        cursorPos.x = cursorPos.x + 1
        ::skip::
    end
end
function print(text) write(text) write("\n") end

function input(prefix)
    write(prefix)

    local inputBuffer = ""
    local initialX = cursorPos.x
    local initialY = cursorPos.y
    while true do
        local eventType, addr, char, code, playerName = computer.pullSignal(0)
        if eventType == "key_down" then
            if char == string.byte("\b") then
                inputBuffer = inputBuffer:sub(1, #inputBuffer - 1)
                if initialX == cursorPos.x and initialY == cursorPos.y then
                    write(" \b")
                    goto skipDisplay
                end
                goto skipInput
            elseif char == string.byte("\r") then
                write("\n")
                goto done
            end
            
            inputBuffer = inputBuffer..string.char(char)
            ::skipInput::
            write(string.char(char))
            ::skipDisplay::
        end
        coroutine.yield() -- Let other coroutines do their stuff.
    end
    ::done::
    return inputBuffer
end

function clear()
    gpu.fill(1, 1, screenWidth, screenHeight, " ")
    cursorPos.x = 1
    cursorPos.y = 1
end
clear()

print("TinyShell " .. _VERSION)
print("Pro tip: execute a file by typing its full path. e.g. /bin/rickroll.lua")

local running = true
local isReadyForInput = true
while running do
    if isReadyForInput == true then
        local input = input("TinyShell> ")
        if #input ~= 0 then
            isReadyForInput = false

            if filesystem.exists(input) and filesystem.isDirectory(input) == false then
                local userCommandPID = dofileThreaded(input)
                while system.kernel.thread.exists(userCommandPID) do
                    coroutine.yield()
                end
            elseif filesystem.isDirectory(input) then
                print(input.." is a directory")
            else
                print(input.." not found")
            end

            ::done::
            isReadyForInput = true
        end
    end

    coroutine.yield() -- Let other coroutines do their stuff.
end

clear()

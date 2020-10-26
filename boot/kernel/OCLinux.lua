-- OCLinux kernel by WattanaGaming
_G.boot_invoke = nil
_G._KERNELNAME = "OCLinux"
_G._KERNELVER = "0.3 beta"

-- These are needed to do literally anything.
local component = component or require('component')
local computer = computer or require('computer')
local unicode = unicode or require('unicode')

-- Kernel table containing built-in functions. 
 kernel = {
    display = {
        isInitialized = false,
        resolution = {
            x = nil,
            y = nil
        },

        initialize = function(self)
            if (self.isInitialized) then
                return false
            end
            self.gpu = component.proxy(component.list("gpu")())
            self.resolution.x, self.resolution.y = self.gpu.getResolution()

            self.isInitialized = true
            return true
        end,

        -- A very basic and barebone system for putting texts on the screen.
        simpleBuffer = {
            lineBuffer = {},

            updateScreen = function(self)
                if #self.lineBuffer > kernel.display.resolution.y then
                    table.remove(self.lineBuffer, 1)
                    kernel.display.gpu.fill(1, 1, kernel.display.resolution.x, kernel.display.resolution.y, " ")
                end
                for i=1,#self.lineBuffer do
                    kernel.display.gpu.set(1, i, self.lineBuffer[i])
                end
            end,
            
            line = function(self, text)
                text = text or ""
                table.insert(self.lineBuffer, tostring(text))
                self:updateScreen()
            end
        }
    },

    filesystem = {},

    internal = {
        isInitialized = false,

        createSandbox = function(template)
            template = template or _G
            local seen = {} -- DO NOT define this inside the function.
            local function copy(tbl) -- Massive thanks to Ocawesome101 for this loop!
                local ret = {}
                for k, v in pairs(tbl) do -- TODO: Make this loop function-independent.
                    if type(v) == "table" and not seen[v] then
                        seen[v] = true
                        ret[k] = copy(v)
                    else
                        ret[k] = v
                    end
                end
                return ret
            end
            local sandbox = copy(template)
            sandbox._G = sandbox
            return sandbox
        end,

        initialize = function(self)
            if (self.isInitialized) then -- Prevent the function from running again once initialized
                return false
            end
            self.bootAddr = computer.getBootAddress()
            
            kernel.display:initialize()

            function Note(frequency, length)
                return {frequency = frequency, length = length}
            end

            local notes = {
                Note(440, 0.1),
                Note(490, 0.1),
                Note(590, 0.1),
                Note(490, 0.1),
                Note(730, 0.4),
                Note(730, 0.4),
                Note(660, 0.8),

                Note(440, 0.1),
                Note(490, 0.1),
                Note(590, 0.1),
                Note(490, 0.1),
                Note(660, 0.4),
                Note(660, 0.4),
                Note(590, 0.4),
                Note(560, 0.1),
                Note(490, 0.2),

                Note(440, 0.1),
                Note(490, 0.1),
                Note(590, 0.1),
                Note(490, 0.1),
                Note(590, 0.6),
                Note(660, 0.2),
                Note(560, 0.6),
                Note(490, 0.2),
                Note(440, 0.2),

                Note(440, 0.2),
                Note(660, 0.2),
                Note(590, 0.2),
                Note(590, 0.6),
            }

            local words = {
                "Ne", "ver", "gon", "na", "give", "you", "up.", "Ne", "ver", "gon", "na", "let", "you", "down", "", ".", "Ne", "ver", "gon", "na", "run", "a", "round", "", "and", "de", "sert", "", "you"
            }

            for i=1,#notes do
                kernel.display.simpleBuffer:line(words[i])
                computer.beep(notes[i].frequency, notes[i].length)
            end

            self.isInitialized = true
            return true
        end
    }
}

kernel.internal:initialize()

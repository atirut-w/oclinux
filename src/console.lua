do
    ---@type GPUProxy
    local gpu = component.proxy(component.list("gpu")())
    local w, h = gpu.getResolution()
    local x, y = 1, 1

    local function cr()
        x = 1
    end

    local function lf()
        y = y + 1
        if y > h then
            y = h
            gpu.copy(1, 1, w, h, 0, -1)
            gpu.fill(1, h, w, 1, " ")
        end
    end

    kernel.register_chrdev("tty", {
        read = function(count)
            local type, _, charcode, keycode = kernel.get_signal()
            if type == "key_down" and charcode ~= 0 then
                return utf8.char(charcode)
            end
        end,
        write = function(data)
            if data then
                for char in data:gmatch(".") do
                    if char == "\a" then
                        computer.beep(1000, 0.1)
                    elseif char == "\b" then
                        -- TODO: Implement backspace.
                    elseif char == "\f" then
                        lf()
                    elseif char == "\n" then
                        cr()
                        lf()
                    elseif char == "\r" then
                        cr()
                        lf()
                    elseif char == "\t" then
                        x = x + 4
                        if x > w then
                            cr()
                            lf()
                        end
                    elseif char == "\v" then
                        lf()
                    else
                        gpu.set(x, y, char)
                        x = x + 1
                        if x > w then
                            cr()
                            lf()
                        end
                    end
                end
            end
        end
    })
end

do
    ---@type GPUProxy
    local gpu = component.proxy(component.list("gpu")())
    local w, h = gpu.getResolution()
    local textbuffer = gpu.allocateBuffer(w, h)
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

    do
        local blink_interval = 0.5
        local blink_timer = 0
        local visible = true
        local last_x, last_y = x, y

        kernel.register_hook("timer", function(delta)
            blink_timer = blink_timer - delta
            if blink_timer <= 0 then
                blink_timer = blink_interval
                visible = not visible

                if visible then
                    gpu.set(x, y, "_")
                else
                    gpu.bitblt(0, 1, 1, w, h, textbuffer)
                end
            elseif x ~= last_x or y ~= last_y then
                visible = true
                blink_timer = blink_interval
                gpu.set(x, y, "_")

                last_x, last_y = x, y
            end
        end)
    end

    kernel.register_chrdev("console", {
        read = function(count)
            local type, _, charcode, keycode = kernel.get_signal()
            if type == "key_down" and charcode ~= 0 then
                return utf8.char(charcode)
            end
        end,
        write = function(data)
            if data then
                local prev_buffer = gpu.getActiveBuffer()
                gpu.setActiveBuffer(textbuffer)

                for char in data:gmatch(".") do
                    if char == "\a" then
                        computer.beep(1000, 0.1)
                    elseif char == "\b" then
                        x = x - 1
                        if x < 1 then
                            if y > 1 then
                                y = y - 1
                                x = w
                            else
                                x = 1
                            end
                        end
                        gpu.set(x, y, " ")
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

                gpu.bitblt(0, 1, 1, w, h, textbuffer)
                gpu.setActiveBuffer(prev_buffer)
            end
        end
    })
end

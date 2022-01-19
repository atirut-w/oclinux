do
    local tty = kernel.filesystem.open("/dev/tty", "w")

    function kernel.printk(fmt, ...)
        assert(type(fmt) == "string", "fmt is not a string")
        tty:write(string.format(fmt, ...))
    end
end
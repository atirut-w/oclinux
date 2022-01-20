do
    local console = kernel.filesystem.open("/dev/tty0", "w")

    function kernel.printk(fmt, ...)
        assert(type(fmt) == "string", "fmt is not a string")
        console:write(string.format(fmt, ...))
    end
end
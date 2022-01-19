--- Event hooks are used internally by the kernel and kernel modules as an alternative to setting up threads to handle events.

do
    ---@type table<string, function[]>
    kernel.hooks = {}

    --- Register an event hook and return its ID.
    ---@param event string
    ---@param callback function
    function kernel.register_hook(event, callback)
        if not kernel.hooks[event] then
            kernel.hooks[event] = {}
        end
        kernel.hooks[event][#kernel.hooks[event] + 1] = callback
        return #kernel.hooks[event]
    end

    --- Unregister an event hook.
    ---@param event string
    ---@param id number
    function kernel.unregister_hook(event, id)
        assert(kernel.hooks[event], "no such event")
        assert(kernel.hooks[event][id], "no such hook")
        table.remove(kernel.hooks[event], id)
    end
end

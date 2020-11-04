local baseModules = {
    "filesystem.lua"
}

kernel.display.simpleBuffer:line("Loading base modules...")
for i=1,#baseModules do
    kernel.internal.loadModule(kernel.internal.loadfile("/boot/modules/"..baseModules[i]))
    error()
end

kernel.modules.filesystem.mount(kernel.internal.bootAddr, "/")

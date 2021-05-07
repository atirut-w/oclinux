local function switch(sw, cases)
    cases.default = (cases.default or function() end)
    return (cases[sw] or cases.default)()
end

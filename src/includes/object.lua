local object = {}
function object:new(obj)
    obj = obj or {}
    self.__index = self
    return setmetatable(obj, self)
end

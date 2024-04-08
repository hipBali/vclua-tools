local function deepCopy(orig, handler)
    if handler then
        local handled, res = handler(orig)
        if handled then return res end
    end
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key, handler)] = deepCopy(orig_value, handler)
        end
        local meta = deepCopy(getmetatable(orig), handler)
        if type(meta) == 'table' then setmetatable(copy, meta) end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return deepCopy

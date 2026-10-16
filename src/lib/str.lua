-- /lib/str.lua: API de manipulación de cadenas para V-Project
local str = {}

function str.trim(s)
    if type(s) ~= "string" then return "" end
    return string.match(s, "^%s*(.-)%s*$") or ""
end

function str.split(s, sep)
    if type(s) ~= "string" then return {} end
    sep = sep or "%s+"
    local parts = {}
    local pattern = string.format("([^%s]+)", sep)
    for part in string.gmatch(s, pattern) do
        table.insert(parts, part)
    end
    return parts
end

function str.starts_with(s, prefix)
    if type(s) ~= "string" or type(prefix) ~= "string" then return false end
    return string.sub(s, 1, #prefix) == prefix
end

function str.ends_with(s, suffix)
    if type(s) ~= "string" or type(suffix) ~= "string" then return false end
    return suffix == "" or string.sub(s, -#suffix) == suffix
end

function str.pad_right(s, len, ch)
    s = tostring(s or "")
    ch = ch or " "
    if #s >= len then return s end
    return s .. string.rep(ch, len - #s)
end

function str.pad_left(s, len, ch)
    s = tostring(s or "")
    ch = ch or " "
    if #s >= len then return s end
    return string.rep(ch, len - #s) .. s
end

return str
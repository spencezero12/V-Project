-- /bin/rm.lua: Eliminar archivos o ramas de directorios (-r, -f)
local args = { ... }
local recursive = false
local force = false
local targets = {}

for _, arg in ipairs(args) do
    if string.sub(arg, 1, 1) == "-" then
        if string.find(arg, "r") or string.find(arg, "R") then recursive = true end
        if string.find(arg, "f") then force = true end
    else
        table.insert(targets, arg)
    end
end

if #targets == 0 then
    if not force then print("rm: missing operand") end
    return
end

for _, target in ipairs(targets) do
    local ok, err = fs.delete(target, recursive)
    if not ok and not force then
        print("rm: cannot remove '" .. target .. "': " .. tostring(err))
    end
end
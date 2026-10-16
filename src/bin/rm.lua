-- /bin/rm.lua: Eliminar archivos o árboles de directorios (-r, -f)
local args = { ... }
local recursive = false
local force = false
local targets = {}

for _, arg in ipairs(args) do
    if string.sub(arg, 1, 1) == "-" and #arg > 1 then
        if string.find(arg, "r") or string.find(arg, "R") then recursive = true end
        if string.find(arg, "f") then force = true end
    else
        table.insert(targets, arg)
    end
end

if #targets == 0 then
    if not force then
        printError("rm: missing operand")
        os.exit(1)
    end
    return
end

local had_error = false
for _, target in ipairs(targets) do
    local ok, err = fs.delete(target, recursive)
    if not ok and not force then
        printError("rm: cannot remove '" .. target .. "': " .. tostring(err))
        had_error = true
    end
end

if had_error then os.exit(1) end
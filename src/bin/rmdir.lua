-- /bin/rmdir.lua: Eliminar directorios vacíos
local args = { ... }

if #args == 0 then
    printError("rmdir: missing operand")
    os.exit(1)
end

local had_error = false
for _, dir in ipairs(args) do
    local ok, err = fs.removeDir(dir)
    if not ok then
        printError("rmdir: failed to remove '" .. dir .. "': " .. tostring(err))
        had_error = true
    end
end

if had_error then os.exit(1) end
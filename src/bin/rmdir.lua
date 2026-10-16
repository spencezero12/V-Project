-- /bin/rmdir.lua: Eliminar directorios vacíos
local args = { ... }

if #args == 0 then
    print("rmdir: missing operand")
    return
end

for _, dir in ipairs(args) do
    local ok, err = fs.removeDir(dir)
    if not ok then
        print("rmdir: failed to remove '" .. dir .. "': " .. tostring(err))
    end
end
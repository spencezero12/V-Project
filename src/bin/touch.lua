-- /bin/touch.lua: Crear archivos vacíos a través del VFS
local args = { ... }

if #args == 0 then
    printError("touch: missing file operand")
    return
end

for _, filename in ipairs(args) do
    if not fs.exists(filename) then
        local file, err = fs.open(filename, "w")
        if file then
            file.close()
        else
            printError("touch: cannot touch '" .. filename .. "': " .. tostring(err or "Permission denied"))
        end
    end
end
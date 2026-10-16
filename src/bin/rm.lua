-- /bin/rm.lua: Eliminar archivos o directorios
local args = { ... }
local current_pwd = _G.PWD or "/"

if #args == 0 then
    print("rm: missing operand")
    return
end

for _, target in ipairs(args) do
    local path = target
    if string.sub(path, 1, 1) ~= "/" then
        path = fs.combine(current_pwd, path)
    end
    
    if not fs.exists(path) then
        print("rm: cannot remove '" .. target .. "': No such file or directory")
    else
        fs.delete(path)
    end
end
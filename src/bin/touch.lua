-- /bin/touch.lua: Crear archivo vacio
local args = { ... }
local current_pwd = _G.PWD or "/"

if #args == 0 then
    print("touch: missing file operand")
    return
end

for _, filename in ipairs(args) do
    local path = filename
    if string.sub(path, 1, 1) ~= "/" then
        path = fs.combine(current_pwd, path)
    end
    
    if not fs.exists(path) then
        local file = fs.open(path, "w")
        if file then
            file.close()
        else
            print("touch: cannot touch '" .. filename .. "': Permission denied")
        end
    end
end
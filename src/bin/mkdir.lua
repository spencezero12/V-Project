-- /bin/mkdir.lua: Crear directorios
local args = { ... }
local current_pwd = _G.PWD or "/"

if #args == 0 then
    print("mkdir: missing operand")
    return
end

for _, dirname in ipairs(args) do
    local path = dirname
    if string.sub(path, 1, 1) ~= "/" then
        path = fs.combine(current_pwd, path)
    end
    
    if fs.exists(path) then
        print("mkdir: cannot create directory '" .. dirname .. "': File exists")
    else
        fs.makeDir(path)
    end
end
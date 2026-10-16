-- /bin/ls.lua: Listar archivos y directorios
local args = { ... }
local target_dir = args[1] or "/"

-- Normalizar ruta relativa a absoluta básica
if not string.find(target_dir, "^/") then
    target_dir = "/" .. target_dir
end

if not fs.exists(target_dir) then
    print("ls: cannot access '" .. target_dir .. "': No such file or directory")
    return
end

if not fs.isDir(target_dir) then
    print(fs.getName(target_dir))
    return
end

local items = fs.list(target_dir)
table.sort(items)

for _, item in ipairs(items) do
    local full_path = fs.combine(target_dir, item)
    if fs.isDir(full_path) then
        term.setTextColor(colors.blue or 1)
        write(item .. "/  ")
    else
        term.setTextColor(colors.white or 1)
        write(item .. "  ")
    end
end
print()
term.setTextColor(colors.white or 1)
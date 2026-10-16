-- /bin/ls.lua: Listar contenidos de directorio
local args = { ... }
local current_pwd = _G.PWD or "/"
local target_dir = args[1] or current_pwd

if string.sub(target_dir, 1, 1) ~= "/" then
    target_dir = fs.combine(current_pwd, target_dir)
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
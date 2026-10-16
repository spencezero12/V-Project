-- /bin/ls.lua: Listar contenido de directorios
local args = { ... }
local show_all = false
local target_dir = "."

for _, arg in ipairs(args) do
    if arg == "-a" then
        show_all = true
    else
        target_dir = arg
    end
end

if not fs.exists(target_dir) then
    print("ls: cannot access '" .. target_dir .. "': No such file or directory")
    return
end

if not fs.isDir(target_dir) then
    print(fs.getName(target_dir))
    return
end

local items, err = fs.list(target_dir)
if not items then
    print("ls: " .. tostring(err))
    return
end

table.sort(items)

if show_all then
    term.setTextColor(colors.blue or 1)
    write(".  ..  ")
end

for _, item in ipairs(items) do
    if show_all or string.sub(item, 1, 1) ~= "." then
        local full_path = fs.combine(target_dir, item)
        if fs.isDir(full_path) then
            term.setTextColor(colors.blue or 1)
            write(item .. "/  ")
        else
            term.setTextColor(colors.white or 1)
            write(item .. "  ")
        end
    end
end
print()
term.setTextColor(colors.white or 1)
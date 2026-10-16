-- /bin/mkdir.lua: Crear directorios
local args = { ... }
local parents = false
local targets = {}

for _, arg in ipairs(args) do
    if arg == "-p" then
        parents = true
    else
        table.insert(targets, arg)
    end
end

if #targets == 0 then
    print("mkdir: missing operand")
    return
end

for _, dirname in ipairs(targets) do
    local ok, err = fs.makeDir(dirname, parents)
    if not ok then
        print("mkdir: cannot create directory '" .. dirname .. "': " .. tostring(err))
    end
end
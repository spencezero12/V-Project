-- /bin/mkdir.lua: Crear directorios (-p)
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
    printError("mkdir: missing operand")
    os.exit(1)
end

local had_error = false
for _, dirname in ipairs(targets) do
    local ok, err = fs.makeDir(dirname, parents)
    if not ok then
        printError("mkdir: cannot create directory '" .. dirname .. "': " .. tostring(err))
        had_error = true
    end
end

if had_error then os.exit(1) end
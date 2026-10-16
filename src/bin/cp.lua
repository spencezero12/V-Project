-- /bin/cp.lua: Copiar archivos y directorios mediante VFS
local args = { ... }

if #args < 2 then
    printError("cp: missing file operand")
    return
end

local src = args[1]
local dest = args[2]

if not fs.exists(src) then
    printError("cp: cannot stat '" .. src .. "': No such file or directory")
    return
end

if fs.exists(dest) and fs.isDir(dest) then
    dest = fs.combine(dest, fs.getName(src))
end

if fs.exists(dest) then
    if fs.isDir(dest) then
        printError("cp: cannot overwrite directory '" .. dest .. "'")
        return
    end
    fs.delete(dest, false)
end

local ok, err = fs.copy(src, dest)
if not ok then
    printError("cp: failed to copy '" .. src .. "': " .. tostring(err))
end
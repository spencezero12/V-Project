-- /bin/mv.lua: Mover o renombrar archivos y directorios mediante VFS
local args = { ... }

if #args < 2 then
    printError("mv: missing file operand")
    return
end

local src = args[1]
local dest = args[2]

if not fs.exists(src) then
    printError("mv: cannot stat '" .. src .. "': No such file or directory")
    return
end

if fs.exists(dest) and fs.isDir(dest) then
    dest = fs.combine(dest, fs.getName(src))
end

if fs.exists(dest) then
    if fs.isDir(dest) then
        printError("mv: cannot overwrite directory '" .. dest .. "'")
        return
    end
    fs.delete(dest, false)
end

local ok, err = fs.move(src, dest)
if not ok then
    printError("mv: failed to move '" .. src .. "': " .. tostring(err))
end
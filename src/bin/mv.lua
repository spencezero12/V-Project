-- /bin/mv.lua: Mover o renombrar archivos y directorios
local args = { ... }

if #args < 2 then
    printError("mv: missing file operand")
    os.exit(1)
end

local dest = args[#args]
local sources = {}
for i = 1, #args - 1 do table.insert(sources, args[i]) end

if #sources > 1 and (not fs.exists(dest) or not fs.isDir(dest)) then
    printError("mv: target '" .. dest .. "' is not a directory")
    os.exit(1)
end

local had_error = false
for _, src in ipairs(sources) do
    if not fs.exists(src) then
        printError("mv: cannot stat '" .. src .. "': No such file or directory")
        had_error = true
    else
        local final_dest = dest
        if fs.exists(dest) and fs.isDir(dest) then
            final_dest = fs.combine(dest, fs.getName(src))
        end

        if fs.exists(final_dest) then
            if fs.isDir(final_dest) then
                printError("mv: cannot overwrite directory '" .. final_dest .. "'")
                had_error = true
            else
                fs.delete(final_dest, false)
            end
        end

        if not had_error then
            local ok, err = fs.move(src, final_dest)
            if not ok then
                printError("mv: cannot move '" .. src .. "': " .. tostring(err))
                had_error = true
            end
        end
    end
end

if had_error then os.exit(1) end
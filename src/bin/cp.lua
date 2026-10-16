-- /bin/cp.lua: Copiar uno o múltiples archivos/directorios
local args = { ... }

if #args < 2 then
    printError("cp: missing file operand")
    os.exit(1)
end

local dest = args[#args]
local sources = {}
for i = 1, #args - 1 do table.insert(sources, args[i]) end

if #sources > 1 and (not fs.exists(dest) or not fs.isDir(dest)) then
    printError("cp: target '" .. dest .. "' is not a directory")
    os.exit(1)
end

local had_error = false
for _, src in ipairs(sources) do
    if not fs.exists(src) then
        printError("cp: cannot stat '" .. src .. "': No such file or directory")
        had_error = true
    else
        local final_dest = dest
        if fs.exists(dest) and fs.isDir(dest) then
            final_dest = fs.combine(dest, fs.getName(src))
        end

        if fs.exists(final_dest) then
            if fs.isDir(final_dest) then
                printError("cp: cannot overwrite directory '" .. final_dest .. "'")
                had_error = true
            else
                fs.delete(final_dest, false)
            end
        end

        if not had_error then
            local ok, err = fs.copy(src, final_dest)
            if not ok then
                printError("cp: failed to copy '" .. src .. "': " .. tostring(err))
                had_error = true
            end
        end
    end
end

if had_error then os.exit(1) end
-- /bin/wc.lua: Conteo de líneas, palabras y caracteres
local str = require("str")

local args = { ... }
local count_lines = false
local count_words = false
local count_chars = false
local files = {}

for _, arg in ipairs(args) do
    if string.sub(arg, 1, 1) == "-" and #arg > 1 then
        if string.find(arg, "l") then count_lines = true end
        if string.find(arg, "w") then count_words = true end
        if string.find(arg, "c") then count_chars = true end
    else
        table.insert(files, arg)
    end
end

-- Si no se pasa ninguna opción, activar todas por defecto
if not count_lines and not count_words and not count_chars then
    count_lines = true
    count_words = true
    count_chars = true
end

local function count_buffer(lines)
    local l_count = #lines
    local w_count = 0
    local c_count = 0

    for _, line in ipairs(lines) do
        c_count = c_count + #line + 1 -- +1 por el salto de línea (\n)
        local words = str.split(line, "%s+")
        w_count = w_count + #words
    end

    local out = ""
    if count_lines then out = out .. str.pad_left(l_count, 6) .. " " end
    if count_words then out = out .. str.pad_left(w_count, 6) .. " " end
    if count_chars then out = out .. str.pad_left(c_count, 6) .. " " end
    return out
end

-- Procesar desde tubería (PIPE)
if #files == 0 then
    if __PIPE_INPUT__ then
        print(count_buffer(__PIPE_INPUT__))
    else
        printError("wc: missing file operand")
        os.exit(1)
    end
    return
end

-- Procesar archivos individuales
for _, path in ipairs(files) do
    if not fs.exists(path) then
        printError("wc: " .. path .. ": No such file or directory")
    elseif fs.isDir(path) then
        printError("wc: " .. path .. ": Is a directory")
    else
        local f = fs.open(path, "r")
        if f then
            local lines = {}
            local l = f.readLine()
            while l do
                table.insert(lines, l)
                l = f.readLine()
            end
            f.close()
            print(count_buffer(lines) .. path)
        else
            printError("wc: cannot open '" .. path .. "'")
        end
    end
end
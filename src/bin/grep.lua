-- /bin/grep.lua: Filtrado de patrones por linea
local args = { ... }
local current_pwd = _G.PWD or "/"

if #args == 0 then
    print("grep: missing pattern")
    return
end

local pattern = args[1]
local filepath = args[2]

local function match_line(line)
    if string.find(line, pattern) then
        print(line)
    end
end

-- Modo 1: Leer desde un archivo si se proporcionó la ruta
if filepath then
    local path = filepath
    if string.sub(path, 1, 1) ~= "/" then
        path = fs.combine(current_pwd, path)
    end

    if not fs.exists(path) or fs.isDir(path) then
        print("grep: " .. filepath .. ": No such file")
        return
    end

    local file = fs.open(path, "r")
    if file then
        local line = file.readLine()
        while line do
            match_line(line)
            line = file.readLine()
        end
        file.close()
    end
-- Modo 2: Leer desde el flujo de entrada (STDIN emulado mediante búfer de tubería)
elseif _G.__PIPE_INPUT__ then
    for _, line in ipairs(_G.__PIPE_INPUT__) do
        match_line(line)
    end
end
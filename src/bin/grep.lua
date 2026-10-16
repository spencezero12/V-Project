-- /bin/grep.lua: Búsqueda de patrones con códigos de salida y soporte -c
local args = { ... }
local count_only = false
local positional = {}

for _, arg in ipairs(args) do
    if arg == "-c" then
        count_only = true
    else
        table.insert(positional, arg)
    end
end

if #positional == 0 then
    printError("grep: missing pattern")
    os.exit(2)
    return
end

local pattern = positional[1]
local filepath = positional[2]
local matches = 0

local function match_line(line)
    local ok, found = pcall(string.find, line, pattern)
    if not ok then
        -- Si el patrón tiene caracteres especiales sin escapar, buscar como texto plano
        found = string.find(line, pattern, 1, true)
    end
    if found then
        matches = matches + 1
        if not count_only then
            print(line)
        end
    end
end

if filepath then
    if not fs.exists(filepath) then
        printError("grep: " .. filepath .. ": No such file or directory")
        os.exit(2)
        return
    elseif fs.isDir(filepath) then
        printError("grep: " .. filepath .. ": Is a directory")
        os.exit(2)
        return
    end

    local file = fs.open(filepath, "r")
    if file then
        local line = file.readLine()
        while line do
            match_line(line)
            line = file.readLine()
        end
        file.close()
    end
elseif __PIPE_INPUT__ then
    for _, line in ipairs(__PIPE_INPUT__) do
        match_line(line)
    end
else
    printError("grep: no input provided")
    os.exit(2)
    return
end

if count_only then
    print(tostring(matches))
end

-- En UNIX, grep devuelve 0 si encontró coincidencias y 1 si no encontró ninguna
if matches == 0 then
    os.exit(1)
else
    os.exit(0)
end
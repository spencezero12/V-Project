-- /bin/test.lua: Evaluación condicional de expresiones para scripts
local args = { ... }

if #args == 0 then
    os.exit(1)
end

-- Casos unarios: test -opcion valor
if #args == 2 then
    local op = args[1]
    local target = args[2]

    if op == "-e" then
        os.exit(fs.exists(target) and 0 or 1)
    elseif op == "-f" then
        os.exit((fs.exists(target) and not fs.isDir(target)) and 0 or 1)
    elseif op == "-d" then
        os.exit((fs.exists(target) and fs.isDir(target)) and 0 or 1)
    elseif op == "-z" then
        os.exit((#target == 0) and 0 or 1)
    elseif op == "-n" then
        os.exit((#target > 0) and 0 or 1)
    else
        printError("test: unknown unary operator: " .. op)
        os.exit(2)
    end
end

-- Casos binarios: test valor1 operador valor2
if #args == 3 then
    local left = args[1]
    local op = args[2]
    local right = args[3]

    if op == "=" or op == "==" then
        os.exit((left == right) and 0 or 1)
    elseif op == "!=" then
        os.exit((left ~= right) and 0 or 1)
    else
        printError("test: unknown binary operator: " .. op)
        os.exit(2)
    end
end

printError("test: invalid arguments")
os.exit(2)
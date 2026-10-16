-- /bin/echo.lua: Imprimir argumentos en la salida estándar
local args = { ... }
local no_newline = false
local start_idx = 1

if args[1] == "-n" then
    no_newline = true
    start_idx = 2
end

local out = {}
for i = start_idx, #args do
    table.insert(out, tostring(args[i]))
end

local text = table.concat(out, " ")
if no_newline then
    write(text)
else
    print(text)
end
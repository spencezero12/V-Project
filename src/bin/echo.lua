-- /bin/echo.lua: Imprimir argumentos en salida estandar
local args = { ... }
print(table.concat(args, " "))

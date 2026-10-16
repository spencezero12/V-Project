-- /bin/cat.lua: Visualizar contenido de archivos
local args = { ... }

if #args == 0 then
    print("cat: missing file operand")
    return
end

for _, filepath in ipairs(args) do
    if not fs.exists(filepath) then
        print("cat: " .. filepath .. ": No such file or directory")
    elseif fs.isDir(filepath) then
        print("cat: " .. filepath .. ": Is a directory")
    else
        local file = fs.open(filepath, "r")
        if file then
            local content = file.readAll()
            file.close()
            if content then
                print(content)
            end
        else
            print("cat: " .. filepath .. ": Permission denied")
        end
    end
end
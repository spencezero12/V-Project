-- /bin/cat.lua: Concatenar y mostrar archivos o entrada estándar
local args = { ... }
local number_lines = false
local files = {}

for _, arg in ipairs(args) do
    if arg == "-n" then
        number_lines = true
    else
        table.insert(files, arg)
    end
end

local line_num = 1
local function output_line(line)
    if number_lines then
        print(string.format("%4d  %s", line_num, line))
        line_num = line_num + 1
    else
        print(line)
    end
end

-- Si no hay archivos pero existe entrada por tubería (PIPE)
if #files == 0 then
    if __PIPE_INPUT__ then
        for _, line in ipairs(__PIPE_INPUT__) do
            output_line(line)
        end
        return
    else
        printError("cat: missing file operand")
        return
    end
end

for _, filepath in ipairs(files) do
    if not fs.exists(filepath) then
        printError("cat: " .. filepath .. ": No such file or directory")
    elseif fs.isDir(filepath) then
        printError("cat: " .. filepath .. ": Is a directory")
    else
        local file, err = fs.open(filepath, "r")
        if file then
            local line = file.readLine()
            while line do
                output_line(line)
                line = file.readLine()
            end
            file.close()
        else
            printError("cat: " .. filepath .. ": " .. tostring(err or "Permission denied"))
        end
    end
end
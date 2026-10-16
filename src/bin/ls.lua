-- /bin/ls.lua: Listado de directorios compatible con tuberías, -a, -l y múltiples rutas
local args = { ... }
local show_all = false
local long_format = false
local one_per_line = (__IS_PIPING__ == true) or (__IS_REDIRECTED__ == true)
local targets = {}

for _, arg in ipairs(args) do
    if string.sub(arg, 1, 1) == "-" and #arg > 1 then
        if string.find(arg, "a") then show_all = true end
        if string.find(arg, "l") then long_format = true end
        if string.find(arg, "1") then one_per_line = true end
    else
        table.insert(targets, arg)
    end
end

if #targets == 0 then
    table.insert(targets, ".")
end

local had_error = false

local function print_entry(parent_dir, name, is_virtual_dir)
    local is_dir = is_virtual_dir
    local size = 0
    if not is_virtual_dir then
        local full_path = fs.combine(parent_dir, name)
        is_dir = fs.isDir(full_path)
        size = is_dir and 4096 or (fs.getSize and fs.getSize(full_path) or 0)
    else
        size = 4096
    end

    if long_format then
        local perms = is_dir and "drwxr-xr-x" or "-rw-r--r--"
        local owner = (ENV and ENV.USER) or "user"
        local display_name = is_dir and (name .. "/") or name
        print(string.format("%s 1 %-6s %6d %s", perms, owner, size, display_name))
    elseif one_per_line then
        print(name)
    else
        if is_dir then
            term.setTextColor(colors.blue or 1)
            write(name .. "/  ")
        elseif string.sub(name, -4) == ".lua" or string.sub(name, -3) == ".sh" then
            term.setTextColor(colors.green or 1)
            write(name .. "  ")
        else
            term.setTextColor(colors.white or 1)
            write(name .. "  ")
        end
        term.setTextColor(colors.white or 1)
    end
end

for idx, target_dir in ipairs(targets) do
    if not fs.exists(target_dir) then
        printError("ls: cannot access '" .. target_dir .. "': No such file or directory")
        had_error = true
    elseif not fs.isDir(target_dir) then
        print_entry(".", target_dir, false)
        if not long_format and not one_per_line then print() end
    else
        if #targets > 1 then
            if idx > 1 then print() end
            print(target_dir .. ":")
        end

        local items, err = fs.list(target_dir)
        if not items then
            printError("ls: " .. tostring(err))
            had_error = true
        else
            table.sort(items)
            local printed_count = 0

            if show_all then
                print_entry(target_dir, ".", true)
                print_entry(target_dir, "..", true)
                printed_count = printed_count + 2
            end

            for _, item in ipairs(items) do
                if show_all or string.sub(item, 1, 1) ~= "." then
                    print_entry(target_dir, item, false)
                    printed_count = printed_count + 1
                end
            end

            -- Solo hacer salto de línea final si se imprimió algo en modo horizontal
            if printed_count > 0 and not long_format and not one_per_line then
                print()
            end
        end
    end
end

if had_error then os.exit(1) end
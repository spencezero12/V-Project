-- /bin/vi.lua: Editor visual interactivo adaptado al Kernel v0.2 de V-Project
local args = { ... }

if #args == 0 then
    print("vi: missing file operand")
    return
end

local filepath = args[1]

-- En UNIX vi no puede abrir directorios para edición
if fs.exists(filepath) and fs.isDir(filepath) then
    print("vi: " .. filepath .. ": Is a directory")
    return
end

-- Dimensiones dinámicas de la pantalla
local term_w, term_h = term.getSize()
local edit_h = term_h - 1

-- Búfer de edición en memoria RAM
local buffer = {}
local modified = false

-- Cargar archivo existente a través del VFS
if fs.exists(filepath) then
    local file, err = fs.open(filepath, "r")
    if file then
        local line = file.readLine()
        while line do
            table.insert(buffer, line)
            line = file.readLine()
        end
        file.close()
    else
        print("vi: cannot open '" .. filepath .. "': " .. tostring(err or "Permission denied"))
        return
    end
end

if #buffer == 0 then
    table.insert(buffer, "")
end

-- Modos de operación de vi: COMMAND, INSERT, LAST_LINE
local mode = "COMMAND"
local cursor_x = 1
local cursor_y = 1
local scroll_y = 0
local last_line_input = ""
local status_msg = '"' .. fs.getName(filepath) .. '" ' .. #buffer .. "L"
local running = true
local last_key_d = false

-- Detección de Escape compatible con GUI de Minecraft (Esc, Tab o F1)
local function is_escape_key(key)
    return key == keys.escape or key == keys.tab or key == keys.f1
end

-- Limitar cursor dentro de los márgenes del texto
local function clamp_cursor()
    if cursor_y < 1 then cursor_y = 1 end
    if cursor_y > #buffer then cursor_y = #buffer end

    local line_len = #buffer[cursor_y]
    local max_x = mode == "INSERT" and (line_len + 1) or math.max(1, line_len)
    if cursor_x < 1 then cursor_x = 1 end
    if cursor_x > max_x then cursor_x = max_x end

    -- Desplazamiento vertical automático
    if cursor_y <= scroll_y then
        scroll_y = cursor_y - 1
    elseif cursor_y > scroll_y + edit_h then
        scroll_y = cursor_y - edit_h
    end
end

-- Renderizado de la interfaz TUI
local function render()
    term.setCursorBlink(false)
    for row = 1, edit_h do
        local buf_idx = scroll_y + row
        term.setCursorPos(1, row)
        term.clearLine()
        if buf_idx <= #buffer then
            term.setTextColor(colors.white or 1)
            term.write(buffer[buf_idx])
        else
            term.setTextColor(colors.blue or 1)
            term.write("~")
        end
    end

    -- Barra de estado inferior
    term.setCursorPos(1, term_h)
    term.clearLine()
    if mode == "LAST_LINE" then
        term.setTextColor(colors.white or 1)
        term.write(":" .. last_line_input)
    else
        term.setTextColor(colors.black or 1)
        term.setBackgroundColor(colors.lightGray or 1)
        local mode_str = mode == "INSERT" and " -- INSERT -- " or " " .. status_msg .. " "
        term.write(mode_str)
        local pos_str = cursor_y .. "," .. cursor_x
        local pad = term_w - #mode_str - #pos_str
        if pad > 0 then term.write(string.rep(" ", pad)) end
        term.write(pos_str)
        term.setBackgroundColor(colors.black or 1)
    end

    -- Posicionamiento del cursor
    if mode == "LAST_LINE" then
        term.setCursorPos(2 + #last_line_input, term_h)
    else
        term.setCursorPos(cursor_x, cursor_y - scroll_y)
    end
    term.setCursorBlink(true)
end

-- Guardar el búfer en disco mediante llamadas al VFS
local function save_buffer()
    local file, err = fs.open(filepath, "w")
    if not file then
        status_msg = "Error: " .. tostring(err or "Cannot write file")
        return false
    end
    for _, l in ipairs(buffer) do
        file.writeLine(l)
    end
    file.close()
    modified = false
    status_msg = '"' .. fs.getName(filepath) .. '" written'
    return true
end

-- Bucle de eventos
term.clear()
while running do
    clamp_cursor()
    render()

    local event, p1 = os.pullEventRaw()

    if event == "key" then
        local key = p1

        if mode == "COMMAND" then
            if key == keys.i then
                mode = "INSERT"
                last_key_d = false
            elseif key == keys.a then
                mode = "INSERT"
                cursor_x = cursor_x + 1
                last_key_d = false
            elseif key == keys.o then
                table.insert(buffer, cursor_y + 1, "")
                cursor_y = cursor_y + 1
                cursor_x = 1
                mode = "INSERT"
                modified = true
                last_key_d = false
            elseif key == keys.x then
                local line = buffer[cursor_y]
                if #line > 0 and cursor_x <= #line then
                    buffer[cursor_y] = string.sub(line, 1, cursor_x - 1) .. string.sub(line, cursor_x + 1)
                    modified = true
                end
                last_key_d = false
            elseif key == keys.d then
                if last_key_d then
                    table.remove(buffer, cursor_y)
                    if #buffer == 0 then table.insert(buffer, "") end
                    modified = true
                    last_key_d = false
                else
                    last_key_d = true
                end
            elseif key == keys.up or key == keys.k then
                cursor_y = cursor_y - 1; last_key_d = false
            elseif key == keys.down or key == keys.j then
                cursor_y = cursor_y + 1; last_key_d = false
            elseif key == keys.left or key == keys.h then
                cursor_x = cursor_x - 1; last_key_d = false
            elseif key == keys.right or key == keys.l then
                cursor_x = cursor_x + 1; last_key_d = false
            end

        elseif mode == "INSERT" then
            if is_escape_key(key) then
                mode = "COMMAND"
                cursor_x = math.max(1, cursor_x - 1)
            elseif key == keys.enter then
                local line = buffer[cursor_y]
                local left = string.sub(line, 1, cursor_x - 1)
                local right = string.sub(line, cursor_x)
                buffer[cursor_y] = left
                table.insert(buffer, cursor_y + 1, right)
                cursor_y = cursor_y + 1
                cursor_x = 1
                modified = true
            elseif key == keys.backspace then
                if cursor_x > 1 then
                    local line = buffer[cursor_y]
                    buffer[cursor_y] = string.sub(line, 1, cursor_x - 2) .. string.sub(line, cursor_x)
                    cursor_x = cursor_x - 1
                    modified = true
                elseif cursor_y > 1 then
                    local prev_len = #buffer[cursor_y - 1]
                    buffer[cursor_y - 1] = buffer[cursor_y - 1] .. buffer[cursor_y]
                    table.remove(buffer, cursor_y)
                    cursor_y = cursor_y - 1
                    cursor_x = prev_len + 1
                    modified = true
                end
            elseif key == keys.up then cursor_y = cursor_y - 1
            elseif key == keys.down then cursor_y = cursor_y + 1
            elseif key == keys.left then cursor_x = cursor_x - 1
            elseif key == keys.right then cursor_x = cursor_x + 1
            end

        elseif mode == "LAST_LINE" then
            if key == keys.enter then
                local cmd = last_line_input
                if cmd == "w" then
                    save_buffer()
                    mode = "COMMAND"
                elseif cmd == "q" then
                    if modified then
                        status_msg = "No write since last change (use :q!)"
                        mode = "COMMAND"
                    else
                        running = false
                    end
                elseif cmd == "wq" then
                    if save_buffer() then running = false end
                elseif cmd == "q!" then
                    running = false
                else
                    status_msg = "Not an editor command: " .. cmd
                    mode = "COMMAND"
                end
            elseif is_escape_key(key) then
                mode = "COMMAND"
            elseif key == keys.backspace then
                if #last_line_input > 0 then
                    last_line_input = string.sub(last_line_input, 1, -2)
                else
                    mode = "COMMAND"
                end
            end
        end

    elseif event == "char" then
        local ch = p1
        if mode == "COMMAND" then
            if ch == ":" then
                mode = "LAST_LINE"
                last_line_input = ""
                last_key_d = false
            end
        elseif mode == "INSERT" then
            local line = buffer[cursor_y]
            buffer[cursor_y] = string.sub(line, 1, cursor_x - 1) .. ch .. string.sub(line, cursor_x)
            cursor_x = cursor_x + 1
            modified = true
        elseif mode == "LAST_LINE" then
            last_line_input = last_line_input .. ch
        end
    end
end

-- Limpieza y restauración de la terminal
term.setBackgroundColor(colors.black or 1)
term.setTextColor(colors.white or 1)
term.clear()
term.setCursorPos(1, 1)
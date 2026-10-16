-- /startup.lua: Bootloader y Kernel primitivo de V-Project con Redirecciones y Pipes
local native_term = _G.term
local native_fs = _G.fs
local native_os = _G.os
local pull_raw = native_os.pullEventRaw

native_term.clear()
native_term.setCursorPos(1, 1)
native_term.setTextColor(colors.green or 1)
print(":: Booting V-Project kernel (v0.1-barebones)...")
native_term.setTextColor(colors.white or 1)

local env = {
    HOSTNAME = "v-project",
    VERSION = "0.1.0-alpha",
    PATH = "/bin",
    PWD = "/"
}
_G.PWD = env.PWD
_G.__PIPE_INPUT__ = nil

local function resolve_path(target)
    if not target or target == "" then
        return env.PWD
    end
    if string.sub(target, 1, 1) == "/" then
        return native_fs.combine("/", target)
    else
        return native_fs.combine(env.PWD, target)
    end
end

-- Ejecutor de comandos con captura para pipes y redirección a disco
local function execute_segment(tokens, input_pipe)
    if #tokens == 0 then return {} end

    -- Parsear redirecciones > y >>
    local parts = {}
    local redirect_file = nil
    local append_mode = false
    local i = 1
    while i <= #tokens do
        local tok = tokens[i]
        if tok == ">" or tok == ">>" then
            append_mode = (tok == ">>")
            if tokens[i + 1] then
                redirect_file = resolve_path(tokens[i + 1])
                i = i + 1
            end
        else
            table.insert(parts, tok)
        end
        i = i + 1
    end

    local cmd = parts[1]
    local args = {}
    for k = 2, #parts do table.insert(args, parts[k]) end
    if not cmd then return {} end

    local output_buffer = {}
    local original_print = _G.print
    local original_write = _G.write
    _G.__PIPE_INPUT__ = input_pipe

    -- Interceptar salida para tuberías o archivos
    _G.print = function(...)
        local line_parts = { ... }
        for idx = 1, #line_parts do line_parts[idx] = tostring(line_parts[idx]) end
        local line = table.concat(line_parts, "    ")
        table.insert(output_buffer, line)
        if not redirect_file and not input_pipe and not _G.__IS_PIPING__ then
            original_print(line)
        end
    end

    _G.write = function(text)
        table.insert(output_buffer, tostring(text))
        if not redirect_file and not input_pipe and not _G.__IS_PIPING__ then
            original_write(text)
        end
    end

    -- Ejecutar comando (builtins o binarios externos)
    if cmd == "pwd" then
        print(env.PWD)
    elseif cmd == "cd" then
        local dest = args[1] or "/"
        local target_path = resolve_path(dest)
        if not native_fs.exists(target_path) then
            original_print("cd: " .. dest .. ": No such file or directory")
        elseif not native_fs.isDir(target_path) then
            original_print("cd: " .. dest .. ": Not a directory")
        else
            env.PWD = target_path == "" and "/" or "/" .. target_path
            _G.PWD = env.PWD
        end
    else
        local target = native_fs.combine(env.PATH, cmd .. ".lua")
        if not native_fs.exists(target) then target = native_fs.combine(env.PATH, cmd) end

        if not native_fs.exists(target) or native_fs.isDir(target) then
            original_print("sh: command not found: " .. cmd)
        else
            local chunk, err = loadfile(target)
            if not chunk then
                original_print("sh: syntax error: " .. tostring(err))
            else
                local ok, exec_err = pcall(chunk, unpack(args))
                if not ok then original_print("sh: runtime error: " .. tostring(exec_err)) end
            end
        end
    end

    -- Restaurar flujos de terminal
    _G.print = original_print
    _G.write = original_write
    _G.__PIPE_INPUT__ = nil

    -- Volcar a archivo si hubo operador > o >>
    if redirect_file then
        local mode = append_mode and "a" or "w"
        local f = native_fs.open(redirect_file, mode)
        if f then
            for _, l in ipairs(output_buffer) do f.writeLine(l) end
            f.close()
        else
            original_print("sh: cannot write to " .. redirect_file)
        end
        return {}
    end

    return output_buffer
end

-- Bucle principal del shell
local function kernel_main()
    while true do
        native_term.setTextColor(colors.yellow or 1)
        native_term.write(env.HOSTNAME .. ":" .. env.PWD .. "$ ")
        native_term.setTextColor(colors.white or 1)
        
        local input = read()
        if input and #input > 0 then
            -- Tokenizar entrada completa
            local all_tokens = {}
            for token in string.gmatch(input, "%S+") do table.insert(all_tokens, token) end

            if all_tokens[1] == "clear" then
                native_term.clear()
                native_term.setCursorPos(1, 1)
            elseif all_tokens[1] == "reboot" or all_tokens[1] == "exit" then
                print(":: Rebooting system...")
                native_os.reboot()
            else
                -- Dividir por tuberías (|)
                local pipeline = {}
                local current_stage = {}
                for _, tok in ipairs(all_tokens) do
                    if tok == "|" then
                        table.insert(pipeline, current_stage)
                        current_stage = {}
                    else
                        table.insert(current_stage, tok)
                    end
                end
                table.insert(pipeline, current_stage)

                -- Ejecución encadenada
                local pipe_data = nil
                _G.__IS_PIPING__ = #pipeline > 1
                for idx, stage in ipairs(pipeline) do
                    -- El último comando debe imprimir su resultado en pantalla si no hay redirección
                    if idx == #pipeline then _G.__IS_PIPING__ = false end
                    pipe_data = execute_segment(stage, pipe_data)
                end
                _G.__IS_PIPING__ = false
            end
        end
    end
end

local success, fatal = pcall(kernel_main)
if not success then
    native_term.setTextColor(colors.red or 1)
    print("\n[ KERNEL PANIC ] " .. tostring(fatal))
    print("Halting system. Press any key to reboot.")
    pull_raw("key")
    native_os.reboot()
end
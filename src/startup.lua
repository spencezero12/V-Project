-- /startup.lua: Kernel v0.2.1 - Sandbox Blindado, VFS Consistente y Tuberías Multilínea
local native_term = _G.term
local native_fs = _G.fs
local native_os = _G.os
local pull_raw = native_os.pullEventRaw

-- Estrictamente necesario para el bootstrap inicial
local BOOT_DIRS_CONF = "/etc/dirs"
local BOOT_PROFILE_CONF = "/etc/profile"

-- Clonar tablas para impedir que un proceso altere las librerías globales del Kernel
local function shallow_copy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do copy[k] = v end
    return copy
end

-- Cargar configuración clave=valor desde /etc
local function load_config(filepath, defaults)
    local conf = shallow_copy(defaults or {})
    if native_fs.exists(filepath) and not native_fs.isDir(filepath) then
        local f = native_fs.open(filepath, "r")
        if f then
            local line = f.readLine()
            while line do
                line = string.gsub(line, "^%s*(.-)%s*$", "%1")
                if #line > 0 and string.sub(line, 1, 1) ~= "#" then
                    local k, v = string.match(line, "^([^=]+)=(.*)$")
                    if k and v then conf[k] = v end
                end
                line = f.readLine()
            end
            f.close()
        end
    end
    return conf
end

-- Rutina fsck: Verifica el árbol de directorios y limpia /tmp y /run al arrancar
local function run_boot_fsck()
    local required_dirs = {
        "/bin", "/boot", "/dev", "/etc", "/home", "/home/user",
        "/root", "/tmp", "/var", "/var/tmp", "/run"
    }
    if native_fs.exists(BOOT_DIRS_CONF) and not native_fs.isDir(BOOT_DIRS_CONF) then
        required_dirs = {}
        local f = native_fs.open(BOOT_DIRS_CONF, "r")
        if f then
            local line = f.readLine()
            while line do
                line = string.gsub(line, "^%s*(.-)%s*$", "%1")
                if #line > 0 and string.sub(line, 1, 1) ~= "#" then
                    table.insert(required_dirs, line)
                end
                line = f.readLine()
            end
            f.close()
        end
    end

    local repaired = 0
    for _, dir in ipairs(required_dirs) do
        local clean_dir = native_fs.combine("/", dir)
        if not native_fs.exists(clean_dir) then
            native_fs.makeDir(clean_dir)
            repaired = repaired + 1
        end
    end

    -- Limpieza de directorios volátiles en arranque (cleanfs)
    local volatile_dirs = { "tmp", "run" }
    for _, vdir in ipairs(volatile_dirs) do
        if native_fs.exists(vdir) and native_fs.isDir(vdir) then
            for _, item in ipairs(native_fs.list(vdir)) do
                native_fs.delete(native_fs.combine(vdir, item))
            end
        end
    end
    return repaired
end

native_term.clear()
native_term.setCursorPos(1, 1)

local env = load_config(BOOT_PROFILE_CONF, {
    HOSTNAME = "v-project",
    VERSION = "0.2.1-beta",
    ARCH = "cobalt-lua5.1",
    PATH = "/bin",
    HOME = "/home/user",
    USER = "user"
})

local fixed_dirs = run_boot_fsck()
env.PWD = native_fs.exists(native_fs.combine("/", env.HOME)) and env.HOME or "/"
env["?"] = "0"

native_term.setTextColor(colors.green or 1)
print(":: Booting " .. env.HOSTNAME .. " (" .. env.VERSION .. ")...")
print(":: fsck: tree verified (" .. fixed_dirs .. " created, /tmp & /run cleared).")
native_term.setTextColor(colors.white or 1)

-- Syscall: Resolución universal de rutas
local function vfs_resolve(target, current_pwd)
    current_pwd = current_pwd or env.PWD
    if not target or target == "" or target == "." then
        return native_fs.combine("/", current_pwd)
    end
    if target == "~" then
        return native_fs.combine("/", env.HOME)
    elseif string.sub(target, 1, 2) == "~/" then
        return native_fs.combine(env.HOME, string.sub(target, 3))
    elseif string.sub(target, 1, 1) == "/" then
        return native_fs.combine("/", target)
    else
        return native_fs.combine(current_pwd, target)
    end
end

-- Protección de rutas críticas del sistema operativo
local PROTECTED_PATHS = {
    [""] = true, ["rom"] = true, ["bin"] = true,
    ["boot"] = true, ["dev"] = true, ["etc"] = true,
    ["startup.lua"] = true
}

local function is_protected_path(resolved)
    return PROTECTED_PATHS[resolved] == true
end

-- Syscall: Generador de entorno aislado (Sandbox estricto)
local function create_process_env(input_pipe, redirect_file, append_mode)
    local proc_env = {}

    -- Copias independientes de librerías estándar (impide contaminación de _G)
    proc_env.string = shallow_copy(_G.string)
    proc_env.table = shallow_copy(_G.table)
    proc_env.math = shallow_copy(_G.math)
    proc_env.coroutine = shallow_copy(_G.coroutine)
    proc_env.keys = shallow_copy(_G.keys)
    proc_env.colors = shallow_copy(_G.colors)
    proc_env.colours = shallow_copy(_G.colours)
    proc_env.term = shallow_copy(native_term)

    proc_env.tonumber = _G.tonumber
    proc_env.tostring = _G.tostring
    proc_env.ipairs = _G.ipairs
    proc_env.pairs = _G.pairs
    proc_env.next = _G.next
    proc_env.select = _G.select
    proc_env.type = _G.type
    proc_env.unpack = _G.unpack
    proc_env.pcall = _G.pcall
    proc_env.xpcall = _G.xpcall
    proc_env.error = _G.error
    proc_env.read = _G.read

    proc_env.ENV = shallow_copy(env)
    proc_env.PWD = env.PWD
    proc_env.__PIPE_INPUT__ = input_pipe
    proc_env.EXIT_CODE = 0

    -- VFS con preservación de rutas absolutas/relativas y validación de errores
    proc_env.fs = {
        resolve = function(p) return "/" .. vfs_resolve(p, proc_env.PWD) end,
        exists = function(p) return native_fs.exists(vfs_resolve(p, proc_env.PWD)) end,
        isDir = function(p) return native_fs.isDir(vfs_resolve(p, proc_env.PWD)) end,
        getName = native_fs.getName,
        getDir = native_fs.getDir,
        combine = function(base, ...)
            local combined = native_fs.combine(base or "", ...)
            if type(base) == "string" and string.sub(base, 1, 1) == "/" then
                return "/" .. combined
            end
            return combined
        end,
        list = function(p)
            local resolved = vfs_resolve(p, proc_env.PWD)
            if not native_fs.exists(resolved) then return nil, "No such file or directory" end
            if not native_fs.isDir(resolved) then return nil, "Not a directory" end
            return native_fs.list(resolved)
        end,
        makeDir = function(p, parents)
            local resolved = vfs_resolve(p, proc_env.PWD)
            if native_fs.exists(resolved) then
                if parents and native_fs.isDir(resolved) then return true end
                return false, "File exists"
            end
            local parent = native_fs.getDir(resolved)
            if parent ~= "" and not native_fs.exists(parent) and not parents then
                return false, "No such file or directory"
            end
            native_fs.makeDir(resolved)
            return true
        end,
        removeDir = function(p)
            local resolved = vfs_resolve(p, proc_env.PWD)
            if is_protected_path(resolved) then return false, "Permission denied (system directory)" end
            if not native_fs.exists(resolved) then return false, "No such file or directory" end
            if not native_fs.isDir(resolved) then return false, "Not a directory" end
            if #native_fs.list(resolved) > 0 then return false, "Directory not empty" end
            native_fs.delete(resolved)
            return true
        end,
        delete = function(p, recursive)
            local resolved = vfs_resolve(p, proc_env.PWD)
            if is_protected_path(resolved) then return false, "Permission denied (protected path)" end
            if not native_fs.exists(resolved) then return false, "No such file or directory" end
            if native_fs.isDir(resolved) and not recursive then return false, "Is a directory" end
            native_fs.delete(resolved)
            return true
        end,
        copy = function(s, d)
            local rs = vfs_resolve(s, proc_env.PWD)
            local rd = vfs_resolve(d, proc_env.PWD)
            if not native_fs.exists(rs) then return false, "No such file or directory" end
            if rs == rd or string.sub(rd, 1, #rs + 1) == rs .. "/" then
                return false, "Cannot copy a directory into itself"
            end
            local parent = native_fs.getDir(rd)
            if parent ~= "" and not native_fs.exists(parent) then
                return false, "No such file or directory"
            end
            local ok, err = pcall(native_fs.copy, rs, rd)
            if not ok then return false, tostring(err) end
            return true
        end,
        move = function(s, d)
            local rs = vfs_resolve(s, proc_env.PWD)
            local rd = vfs_resolve(d, proc_env.PWD)
            if is_protected_path(rs) then return false, "Permission denied (protected path)" end
            if not native_fs.exists(rs) then return false, "No such file or directory" end
            if rs == rd or string.sub(rd, 1, #rs + 1) == rs .. "/" then
                return false, "Cannot move a directory into itself"
            end
            local parent = native_fs.getDir(rd)
            if parent ~= "" and not native_fs.exists(parent) then
                return false, "No such file or directory"
            end
            local ok, err = pcall(native_fs.move, rs, rd)
            if not ok then return false, tostring(err) end
            return true
        end,
        open = function(p, m)
            local resolved = vfs_resolve(p, proc_env.PWD)
            local parent = native_fs.getDir(resolved)
            if (m == "w" or m == "a") and parent ~= "" and not native_fs.exists(parent) then
                return nil, "No such file or directory"
            end
            return native_fs.open(resolved, m)
        end
    }

    proc_env.os = {
        pullEvent = native_os.pullEvent,
        pullEventRaw = native_os.pullEventRaw,
        sleep = native_os.sleep,
        clock = native_os.clock,
        time = native_os.time,
        startTimer = native_os.startTimer,
        cancelTimer = native_os.cancelTimer,
        exit = function(code)
            proc_env.EXIT_CODE = tonumber(code) or 0
            error("__PROC_EXIT__", 0)
        end
    }

    proc_env.output_buffer = {}
    local line_accumulator = ""

    local function push_text_lines(str)
        local full = line_accumulator .. str
        line_accumulator = ""
        local start = 1
        while true do
            local nl = string.find(full, "\n", start, true)
            if not nl then
                line_accumulator = string.sub(full, start)
                break
            end
            table.insert(proc_env.output_buffer, string.sub(full, start, nl - 1))
            start = nl + 1
        end
    end

    proc_env.flush_output = function()
        if #line_accumulator > 0 then
            table.insert(proc_env.output_buffer, line_accumulator)
            line_accumulator = ""
        end
    end

    proc_env.write = function(text)
        local s = tostring(text or "")
        push_text_lines(s)
        if not redirect_file and not proc_env.__IS_PIPING__ then
            return _G.write(s) or 0
        end
        return 0
    end

    proc_env.print = function(...)
        local parts = { ... }
        for i = 1, #parts do parts[i] = tostring(parts[i]) end
        local line = table.concat(parts, "    ")
        push_text_lines(line .. "\n")
        if not redirect_file and not proc_env.__IS_PIPING__ then
            return _G.print(line) or 1
        end
        return 1
    end

    -- Canal de diagnóstico (STDERR): imprime en consola sin contaminar tuberías
    proc_env.printError = function(...)
        local parts = { ... }
        for i = 1, #parts do parts[i] = tostring(parts[i]) end
        local msg = table.concat(parts, " ")
        proc_env.EXIT_CODE = 1
        local prev_color = native_term.getTextColor and native_term.getTextColor() or (colors.white or 1)
        native_term.setTextColor(colors.red or 1)
        _G.print(msg)
        native_term.setTextColor(prev_color)
    end

    proc_env._G = proc_env
    return proc_env
end

-- Tokenizador con soporte de comillas ("..." y '...') y expansión de variables ($VAR, $?)
local function tokenize_input(input)
    local tokens = {}
    local current = ""
    local in_quote = nil
    local i = 1
    while i <= #input do
        local ch = string.sub(input, i, i)
        if in_quote then
            if ch == in_quote then
                in_quote = nil
            else
                current = current .. ch
            end
        else
            if ch == '"' or ch == "'" then
                in_quote = ch
            elseif string.match(ch, "%s") then
                if #current > 0 then
                    table.insert(tokens, current)
                    current = ""
                end
            elseif ch == "|" then
                if #current > 0 then
                    table.insert(tokens, current)
                    current = ""
                end
                table.insert(tokens, "|")
            else
                current = current .. ch
            end
        end
        i = i + 1
    end
    if #current > 0 then table.insert(tokens, current) end

    -- Expandir variables de entorno ($?, $USER, $HOME, $PWD, etc.)
    for idx, tok in ipairs(tokens) do
        tok = string.gsub(tok, "%$(%w+)", function(var) return env[var] or "" end)
        tok = string.gsub(tok, "%$%?", function() return env["?"] or "0" end)
        tokens[idx] = tok
    end
    return tokens
end

local function find_executable(cmd)
    for path_entry in string.gmatch(env.PATH, "[^:]+") do
        local candidate_lua = native_fs.combine(path_entry, cmd .. ".lua")
        if native_fs.exists(candidate_lua) and not native_fs.isDir(candidate_lua) then
            return candidate_lua
        end
        local candidate_raw = native_fs.combine(path_entry, cmd)
        if native_fs.exists(candidate_raw) and not native_fs.isDir(candidate_raw) then
            return candidate_raw
        end
    end
    return nil
end

local function execute_segment(tokens, input_pipe)
    if #tokens == 0 then return {} end

    local parts = {}
    local redirect_file = nil
    local append_mode = false
    local i = 1
    while i <= #tokens do
        local tok = tokens[i]
        if tok == ">" or tok == ">>" then
            append_mode = (tok == ">>")
            if tokens[i + 1] then
                redirect_file = vfs_resolve(tokens[i + 1], env.PWD)
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

    local proc_env = create_process_env(input_pipe, redirect_file, append_mode)
    proc_env.__IS_PIPING__ = _G.__IS_PIPING__
    local exec_error = nil

    if cmd == "pwd" then
        proc_env.print(env.PWD)
    elseif cmd == "cd" then
        local dest = args[1] or env.HOME
        local target_path = vfs_resolve(dest, env.PWD)
        if not native_fs.exists(target_path) then
            exec_error = "cd: " .. dest .. ": No such file or directory"
        elseif not native_fs.isDir(target_path) then
            exec_error = "cd: " .. dest .. ": Not a directory"
        else
            env.PWD = target_path == "" and "/" or "/" .. target_path
        end
    elseif cmd == "sync" then
        proc_env.print(":: VFS buffers synchronized.")
    elseif cmd == "true" then
        proc_env.EXIT_CODE = 0
    elseif cmd == "false" then
        proc_env.EXIT_CODE = 1
    else
        local target = find_executable(cmd)
        if not target then
            exec_error = "sh: command not found: " .. cmd
        else
            local chunk, err = loadfile(target)
            if not chunk then
                exec_error = "sh: syntax error: " .. tostring(err)
            else
                setfenv(chunk, proc_env)
                local ok, run_err = pcall(chunk, unpack(args))
                if not ok and tostring(run_err) ~= "__PROC_EXIT__" then
                    exec_error = "sh: runtime error: " .. tostring(run_err)
                end
            end
        end
    end

    proc_env.flush_output()

    if exec_error then
        proc_env.printError(exec_error)
        env["?"] = "1"
        return {}
    end

    env["?"] = tostring(proc_env.EXIT_CODE or 0)

    if redirect_file then
        local parent = native_fs.getDir(redirect_file)
        if parent ~= "" and not native_fs.exists(parent) then
            proc_env.printError("sh: " .. redirect_file .. ": No such file or directory")
            env["?"] = "1"
            return {}
        end
        local mode = append_mode and "a" or "w"
        local f = native_fs.open(redirect_file, mode)
        if f then
            for _, l in ipairs(proc_env.output_buffer) do f.writeLine(l) end
            f.close()
        else
            proc_env.printError("sh: cannot write to " .. redirect_file)
            env["?"] = "1"
        end
        return {}
    end

    return proc_env.output_buffer
end

local function kernel_main()
    while true do
        native_term.setTextColor(colors.yellow or 1)
        local display_pwd = env.PWD
        if env.PWD == env.HOME then display_pwd = "~" end
        local prompt_symbol = (env.USER == "root") and "# " or "$ "
        native_term.write(env.USER .. "@" .. env.HOSTNAME .. ":" .. display_pwd .. prompt_symbol)
        native_term.setTextColor(colors.white or 1)

        local input = read()
        if input and #input > 0 then
            local all_tokens = tokenize_input(input)

            if all_tokens[1] == "clear" then
                native_term.clear()
                native_term.setCursorPos(1, 1)
                env["?"] = "0"
            elseif all_tokens[1] == "reboot" or all_tokens[1] == "shutdown" or all_tokens[1] == "exit" then
                print(":: Synchronizing filesystems and halting...")
                native_os.reboot()
            elseif #all_tokens > 0 then
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

                local pipe_data = nil
                _G.__IS_PIPING__ = #pipeline > 1
                for idx, stage in ipairs(pipeline) do
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
-- /startup.lua: Bootloader y Kernel primitivo de V-Project con soporte de PWD
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

-- Función auxiliar para normalizar rutas relativas a absolutas
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

-- Ejecutor de binarios en espacio aislado
local function execute_binary(path, args)
    if not native_fs.exists(path) or native_fs.isDir(path) then
        print("sh: command not found: " .. path)
        return false
    end
    
    local chunk, err = loadfile(path)
    if not chunk then
        print("sh: syntax error: " .. tostring(err))
        return false
    end
    
    _G.PWD = env.PWD
    local ok, exec_err = pcall(chunk, unpack(args or {}))
    if not ok then
        print("sh: runtime error: " .. tostring(exec_err))
        return false
    end
    return true
end

-- Bucle principal del shell
local function kernel_main()
    while true do
        native_term.setTextColor(colors.yellow or 1)
        native_term.write(env.HOSTNAME .. ":" .. env.PWD .. "$ ")
        native_term.setTextColor(colors.white or 1)
        
        local input = read()
        if input and #input > 0 then
            local parts = {}
            for token in string.gmatch(input, "%S+") do
                table.insert(parts, token)
            end
            
            local cmd = parts[1]
            local args = {}
            for i = 2, #parts do
                table.insert(args, parts[i])
            end
            
            -- Comandos integrados (Built-ins)
            if cmd == "exit" or cmd == "reboot" then
                print(":: Rebooting system...")
                native_os.reboot()
            elseif cmd == "clear" then
                native_term.clear()
                native_term.setCursorPos(1, 1)
            elseif cmd == "pwd" then
                print(env.PWD)
            elseif cmd == "cd" then
                local dest = args[1] or "/"
                local target_path = resolve_path(dest)
                if not native_fs.exists(target_path) then
                    print("cd: " .. dest .. ": No such file or directory")
                elseif not native_fs.isDir(target_path) then
                    print("cd: " .. dest .. ": Not a directory")
                else
                    env.PWD = target_path == "" and "/" or "/" .. target_path
                    _G.PWD = env.PWD
                end
            else
                -- Buscar el ejecutable en /bin
                local target = native_fs.combine(env.PATH, cmd .. ".lua")
                if not native_fs.exists(target) then
                    target = native_fs.combine(env.PATH, cmd)
                end
                execute_binary(target, args)
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
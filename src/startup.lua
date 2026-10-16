-- /startup.lua: Bootloader y Kernel primitivo de V-Project
local native_term = _G.term
local native_fs = _G.fs
local native_os = _G.os

-- Inmunidad ante terminacion forzada (Ctrl + T)
local pull_raw = native_os.pullEventRaw

native_term.clear()
native_term.setCursorPos(1, 1)
native_term.setTextColor(colors.green or 1)
print(":: Booting V-Project kernel (v0.1-barebones)...")
native_term.setTextColor(colors.white or 1)

local env = {
    HOSTNAME = "v-project",
    VERSION = "0.1.0-alpha",
    PATH = "/bin"
}

-- Cargador basico de binarios en espacio aislado
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
    
    local ok, exec_err = pcall(chunk, unpack(args or {}))
    if not ok then
        print("sh: runtime error: " .. tostring(exec_err))
        return false
    end
    return true
end

-- Bucle principal interactivo
local function kernel_main()
    while true do
        native_term.setTextColor(colors.yellow or 1)
        native_term.write(env.HOSTNAME .. ":/$ ")
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
            
            if cmd == "exit" or cmd == "reboot" then
                print(":: Rebooting system...")
                native_os.reboot()
            elseif cmd == "clear" then
                native_term.clear()
                native_term.setCursorPos(1, 1)
            else
                local target = native_fs.combine(env.PATH, cmd .. ".lua")
                if not native_fs.exists(target) then
                    target = native_fs.combine(env.PATH, cmd)
                end
                execute_binary(target, args)
            end
        end
    end
end

-- Captura global ante Kernel Panic
local success, fatal = pcall(kernel_main)
if not success then
    native_term.setTextColor(colors.red or 1)
    print("\n[ KERNEL PANIC ] " .. tostring(fatal))
    print("Halting system. Press any key to reboot.")
    pull_raw("key")
    native_os.reboot()
end

-- /bin/uname.lua: Información dinámica del sistema
local args = { ... }
local sys_name = (ENV and ENV.HOSTNAME) or "V-Project"
local sys_ver = (ENV and ENV.VERSION) or "unknown"
local sys_arch = (ENV and ENV.ARCH) or "lua"

if args[1] == "-a" then
    print(sys_name .. " " .. sys_ver .. " " .. sys_arch)
else
    print(sys_name)
end
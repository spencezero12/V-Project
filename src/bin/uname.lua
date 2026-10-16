-- /bin/uname.lua: Informacion del sistema
local args = { ... }

if args[1] == "-a" then
    print("V-Project 0.1.0-alpha CC-Tweaked-1.20.1 cobalt-lua5.1")
else
    print("V-Project")
end

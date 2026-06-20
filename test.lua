local config_dir = "C:\\dev\\entorno"
local portable_root = config_dir:gsub("[\\]+", "/")
if not portable_root:match("/$") then
  portable_root = portable_root .. "/"
end

local path_env = "C:\\Windows\\System32;C:\\Windows"
if path_env then path_env = path_env:gsub("[\\]+", "/") else path_env = "" end

local custom_path = portable_root .. "bin;" .. portable_root .. "msys64/clang64/bin;" .. portable_root .. "msys64/usr/bin;" .. path_env
print(custom_path)

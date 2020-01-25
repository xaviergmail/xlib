rename-session mobdebug
neww
send-keys 'lua mobdebug.lua server' C-m
split-window -v
send-keys 'lua mobdebug.lua client' C-m

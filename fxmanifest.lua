fx_version "cerulean"
game "gta5"
lua54 "yes"

author "iHitachi"
description "Play YouTube videos through 17mov_Phone"
version "2.1.0"

shared_scripts {
    "config.lua",
    "locales/main.lua",
    "locales/en.lua",
    "locales/de.lua",
    "shared/core.lua",
}

client_scripts {
    "client/music.lua",
    "phone/core.lua",
    "phone/main.lua",
}

server_script "server/main.lua"

-- Dev: ui_page "http://localhost:1717"
ui_page "web/build/index.html"

files {
    "web/build/**.*",
    "web/build/**/**.*",
    "web/build/**/**/**.*",
}

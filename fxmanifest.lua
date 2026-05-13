fx_version "cerulean"
game "gta5"
lua54 "yes"

author "iHitachi"
description "Play YouTube videos through 17mov_Phone"
version "3.0.0"

shared_scripts {
    "@ox_lib/init.lua",
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

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- Dev: ui_page "http://localhost:1717"
ui_page "web/build/index.html"

files {
    "web/build/**.*",
    "web/build/**/**.*",
    "web/build/**/**/**.*",
}

dependencies {
    "ox_lib",
    "oxmysql",
}

-- By using this script, you agree to the EULA provided by LuckyyFishyy

fx_version 'cerulean'
game 'gta5'

author 'LuckyyFishyy'
description 'Business card printer for QBX'
version '1.0.0'

ui_page 'html/index.html'

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}

-- Main
client_scripts {
    'client/main.lua',
}

-- Server
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- Config
shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',

}

-- HTML
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

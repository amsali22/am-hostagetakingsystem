fx_version 'cerulean'
game 'gta5'

description 'Hostage taking System'
author 'Markow'
repository ''
version '1.0.0'


shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

files {
    'config.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

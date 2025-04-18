fx_version 'cerulean'
games { 'gta5', 'rdr3' }

author 'Pixelated <codemeapixel.dev>'
description 'Advanced Discord logging system for FiveM and RedM'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
repository 'https://github.com/ByteBrushStudios/pixel_logs'
version '1.px0001a'

lua54 'yes'

shared_scripts {
    'configs/config.lua',
    'configs/messages.lua'
}

client_scripts {
    'client/c_chat.lua',
    'client/c_events.lua',
    'client/c_exports.lua'
}

server_scripts {
    'server/s_init.lua',
    'server/s_utils.lua',
    'server/s_exports.lua',
    'server/s_chat.lua',
    'server/s_events.lua',
    'server/s_debug.lua'
}

server_exports {
    'GetUtils',
    'SendCustomLog',
    'SendCustomEmbed',
    'AddDebugLog',
    'GetDebugLog',
    'GetAllDebugLogs',
    'ClearDebugLogs',
    'CatchError'
}

client_exports {
    'SendCustomLog',
    'SendCustomEmbed'
}
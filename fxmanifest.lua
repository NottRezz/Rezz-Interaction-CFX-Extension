fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rezz-interaction'
description 'ox_target-style interaction/targeting system for RedM'
version '1.0.0'
author 'Rezz'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

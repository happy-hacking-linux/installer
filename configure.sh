configure () {
    cp ./config/.gitconfig ~/.
    configureX
    configureXmonad
}

configureX () {
    cp ./config/.Xresources ~/.
    cp ./config/.xinitrc ~/.
    cp ./config/.Xmodmap ~/.
}

configureXmonad () {
    mkdir ~/.xmonad
    cp ./config/xmonad.hs ~/.xmonad/.
    cp ./config/xmobar.hs ~/.xmonad/.
}

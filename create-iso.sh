TMP=./iso

prepare () {
    sudo pacman -S archiso
    git clone https://github.com/happy-hacking-linux/iso.git $TMP
    cp dist/install $TMP/airootfs/root/autorun.sh
    cp .zshrc $TMP/airootfs/root/.zshrc
    build
}

build () {
    cd $TMP
    sudo ./build.sh -v
}

prepare

prepare () {
    title "Welcome to installation of Happy Hacking Linux distro."
    read -p "Choose a username: " $username
    timedatectl set-ntp true
    success "Ready for the installation for " $username
}

formatDisk () {
    title "Disk Format"
    confirm "Your disk will be completely erased. Do you wish to continue?"
    if [ $notconfirmed ]; then
        info "Setup your disk partition and hit Control+C when you're done."
        parted
        read -p "Boot Partition: /dev/" $bootpt
    else
        parted /dev/sda --script <<EOF
mklabel msdos
mkpart primary ext4 0% 100%
set 1 boot on
print
exit
EOF

        mkfs.ext4 /dev/sda1
        bootpt=sda1
        success "Disk has been formatted."
    fi
}

installSystem () {
    title "Installing System Packages"
    info "This will take some time depending on your internet connection."

    pacstrap -y /mnt base
    genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot /mnt
}

afterInstallingSystem () {
    title "Localization"
    tzselect
    hwclock --systohc
    sed -i -e '/^#en_US/s/^#//' /etc/locale.gen # uncomment lines starting with #en_US
    locale-gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
    echo $username > /etc/hostname
    echo "127.0.1.1	$(username).localdomain	$(username)" >> /etc/hosts
}

installGRUB () {
    pacman -S --noconfirm grub
    grub-install --target=i386-pc /dev/$bootpt
}

installPackages () {
    pacman -S --noconfirm base-devel \
           curl \
           wget \
           git \
           tmux \
           zsh \
           checkinstall \
           firefox \
           xmonad \
           xmobar \
           feh \
           scrot \
           moc \
           newsbeuter \
           dmenu \
           rxvt-unicode \
           emacs \
           vim
}

installNode () {
    curl https://raw.github.com/creationix/nvm/master/install.sh | bash
	  source ~/.nvm/nvm.sh
    nvm install 7.1.0
	  nvm use 7.1.0
	  nvm alias default 0.10
}

installZSH () {
	  curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
	  echo "source ~/dotfiles/.zshrc \nsource ~/dotfiles/.nvm \nsource ~/localbin/bashmarks/bashmarks.sh\nsource ~/.nvm/nvm.sh" > ~/.zshrc
	  chsh -s $(which zsh)
}

installFonts () {
    pacman -S --noconfirm ttf-inconsolata ttf-symbola ttf-ancient-fonts ttf-bitstream-vera
    installMonacoFont
    installEmojiFont
}

installMonacoFont () {
    ../install-font http://jorrel.googlepages.com/Monaco_Linux.ttf
}

installEmojiFont () {
    wget https://github.com/eosrei/emojione-color-font/releases/download/v1.3/EmojiOneColor-SVGinOT-Linux-1.3.tar.gz -O /tmp/emojione-font.tar.gz
    cd /tmp
    tar zxf emojione-font.tar.gz
    cd Emoji* && ./install.sh
}

installSpacemacs () {
    git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
}

installAwesomeVim () {
    git clone git://github.com/amix/vimrc.git ~/.vim_runtime
    sh ~/.vim_runtime/install_awesome_vimrc.sh
}

info () {
    colored "$1" "90"
}

title () {
    echo ""
    echo "$1"
    echo ""
}

colored () {
    #local color="\033[$2m"
    #local nc='\033[0m'
    #FIXME: colors are not working
    echo "$1"
}

error () {
    colored "Error: $1" "31"
    echo ""
    exit 1
}

success () {
    colored "$1" "32"
    echo ""
}

confirm () {
    read -p "$1 (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        confirmed=1
        notconfirmed=""
    else
        confirmed=""
        notconfirmed=1
    fi
}

prepare
formatDisk
installArch
installGRUB
installPackages
installNode
installZSH
installFonts
installSpacemacs
installAwesomeVim

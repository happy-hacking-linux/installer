DISTRO_DL="https://git.io/v1JNj"

init () {
    timedetect1 set-ntp true
}

autoPartition () {
    parted $1 --script mklabel msdos \
           mkpart primary ext4 3MiB 100% \
           set 1 boot on 2> /tmp/err || errorDialog "Failed to create disk partitions"

    yes | mkfs.ext4 "${1}1" > /dev/null 2> /tmp/err || error "Failed to format the boot partition"
    yes | mkfs.ext4 "${1}2" > /dev/null 2> /tmp/err || error "Failed to format the root partition"

    mount "${1}1" /mnt
    setvar "system-partition" "${1}2"
}

installCoreSystem () {
    getvar "system-partition"
    systempt=$value

    getvar "disk"
    disk=$value

    pacstrap /mnt base
    genfstab -U /mnt >> /mnt/etc/fstab

    mkdir -p /mnt/usr/local/installer
    cp install-vars /mnt/usr/local/installer/.

    arch-chroot /mnt <<EOF
cd /usr/local/installer
curl -L $DISTRO_DL > ./install
chmod +x ./install
pacman -S --noconfirm dialog
./install continue 2> ./error-logs
EOF
}

installGRUB () {
    pacman -S --noconfirm grub > /dev/null 2> /tmp/err || errorDialog "Failed to install GRUB. Are you connected to internet?"
    getvar "disk"
    grub-install --target=i386-pc --recheck $value > /dev/null 2> /tmp/err || errorDialog "Failed to run grub-install"
}

localize () {
    yes | pip install tzupdate > /dev/null 2> /dev/null # ignore if it fails, let user choose tz

    tzSelectionMenu "Happy Hacking Linux"

    hwclock --systohc
    sed -i -e '/^#en_US/s/^#//' /etc/locale.gen # uncomment lines starting with #en_US
    locale-gen 2> /tmp/err || errorDialog "locale-gen is missing"

    # FIX ME: Allow user to choose language and keyboard
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
}

createUser () {
    useradd -m -s /usr/bin/zsh $1
    echo "$1:$2" | chpasswd

    echo "$1 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    echo $1 > /etc/hostname
    echo "127.0.1.1	$1.localdomain	$1" >> /etc/hosts
}

linkDotFiles () {
    getvar "username"
    username=$value

    dotFilesBase=$(basename "$1" | cut -f 1 -d '.')
    runuser -l $username -c "git clone $1 ~/${dotFilesBase} && ln -f -s ~/${dotFilesBase}/.* ~/." > /dev/null 2> /tmp/err || errorDialog "Can not install dotfiles at $1 :/"
}

linkDefaultDotFiles () {
    getvar "username"
    username=$value
    repo="https://github.com/happy-hacking-linux/dotfiles.git"
    runuser -l $username -c "git clone $1 /tmp/dotfiles && ln -f -s /tmp/dotfiles/.* ~/." > /dev/null 2> /tmp/err || errorDialog "Can not install dotfiles at $1 :/"
}

installZSH () {
    pacman --noconfirm -S zsh > /dev/null 2> /tmp/err || errorDialog "Can not install ZSH. Are you connected to internet?"
    chsh -s $(which zsh) > /dev/null 2> /tmp/err || errorDialog "Something got screwed up, we can't change the default shell to ZSH."
}

installOhMyZSH () {
    getvar "$username"
    username=$value

    runuser -l $username -c 'yaourt --noconfirm -S oh-my-zsh-git > /dev/null 3> /tmp/err || errorDialog "Cannot install oh-my-zsh, are your connected to internet?"'
}

installVirtualBox () {
    if lspci | grep -i virtualbox -q; then
        pacman --noconfirm -S virtualbox-guest-utils virtualbox-guest-modules-arch virtualbox-guest-dkms
        echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
        systemctl enable vboxservice.service
    fi
}

installBasicPackages () {
    pacman --noconfirm -Syu > /dev/null 2> /tmp/err || errorDialog "Failed to install some basic packages."
    pacman -S --noconfirm \
           base-devel \
           net-tools \
           pkgfile \
           xf86-video-vesa \
           openssh \
           wget \
           git \
           grep  > /dev/null 2> /tmp/err || errorDialog "Failed to install basic packages. Check your internet connection please."

    installZSH
}

installYaourt () {
    getvar "username"
    username=$value

    runuser -l $username -c "git clone https://aur.archlinux.org/package-query.git /tmp/package-query" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runuser -l $username -c "cd /tmp/package-query && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build package-query."
    runuser -l $username -c "git clone https://aur.archlinux.org/yaourt.git /tmp/yaourt" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runuser -l $username -c "cd /tmp/yaourt && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build Yaourt"
}

installDesktop () {
    pacman -S --noconfirm \
           xorg \
           xorg-init \
           xmonad \
           xmonad-contrib \
           xmobar \
           feh \
           unclutter \
           firefox \
           scrot \
           dmenu > /dev/null 2> /tmp/err || errorDialog "Failed to install desktop packages. Are you connected to internet?"

    systemctl enable slim /dev/null 2> /tmp/err || errorDialog "Can not enable the login manager, SLIM."
}

installDevTools () {
    pacman -S --noconfirm go \
           emacs \
           vim \
           nodejs \
           python \
           python-pip \
           mariadb > /dev/null 2> /tmp/err || errorDialog "Failed to install programming packages. Are you connected to internet?"
}

installCLITools () {
    pacman -S --noconfirm \
           tmux \
           acpi \
           newsbeuter \
           htop > /dev/null 2> /tmp/err || errorDialog "Failed to install command-line utilities. Are you connected to internet?"
}

installMedia () {
    pacman -S alsa-utils mplayer moc > /dev/null 2> /tmp/err || errorDialog "Failed to install media"
}

installFonts () {
    pacman -S ttf-dejavu \
        ttf-droid \
        ttf-inconsolata \
        ttf-symbola \
        ttf-bitstream-vera \
        terminus-font \
        ttf-fira-mono \
        ttf-fira-sans \
        adobe-source-code-pro-fonts > /dev/null 2> /tmp/err || errorDialog "Failed to install fonts"

    getvar "$username"
    username=$value
    runuser -l $username -c 'yaourt -S --noconfirm \
           ttf-mac-fonts \
           system-san-francisco-font-git \
           ttf-monaco > /dev/null 2> /tmp/err || errorDialog "Failed to install Mac fonts. Are you connected to internet?"'
}

installURXVT () {
    getvar "$username"
    username=$value
    runuser -l $username -c 'yaourt --noconfirm -S rxvt-unicode-256xresources > /dev/null 2> /tmp/err || errorDialog "Failed to install RXVT-Unicode with 256 colors"'
}

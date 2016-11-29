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

    setvar "core-install-step" "done"

    mkdir -p /mnt/usr/local/installer
    cp install-vars /mnt/usr/local/installer/.

    arch-chroot /mnt <<EOF
cd /usr/local/installer
curl -L $DISTRO_DL > ./install
chmod +x ./install
pacman -S --noconfirm dialog
./install continue 2> ./error-logs
EOF

    if [ -f /tmp/reboot ]; then
        echo "Ciao!"
        reboot
    fi
}

installGRUB () {
    pacman -S --noconfirm grub > /dev/null 2> /tmp/err || errorDialog "Failed to install GRUB. Are you connected to internet?"
    getvar "disk"
    grub-install --target=i386-pc --recheck $value > /dev/null 2> /tmp/err || errorDialog "Something got screwed and we failed to run grub-install"
    grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2> /tmp/err || errorDiaolog "Something got screwed up and we failed to create GRUB config."
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
    target=/home/$username/$dotFilesBase
    runuser -l $username -c "git clone $1 $target && cd $target && for file in .*; do cd /home/$username && rm -rf \$file && ln -s $target/\$file \$file; done" > /dev/null 2> /tmp/err || errorDialog "Can not install dotfiles at $1 :/"
}

installDefaultDotFiles () {
    getvar "username"
    username=$value
    runuser -l $username -c "git clone https://github.com/happy-hacking-linux/dotfiles.git /tmp/dotfiles && cp -rf /tmp/dotfiles/.* /home/$username/. && rm -rf ~/.git" > /dev/null 2> /tmp/err || errorDialog "Failed to install the default Happy Hacking dotfiles :/"
}

installZSH () {
    pacman --noconfirm -S zsh > /dev/null 2> /tmp/err || errorDialog "Can not install ZSH. Are you connected to internet?"
    chsh -s $(which zsh) > /dev/null 2> /tmp/err || errorDialog "Something got screwed up, we can't change the default shell to ZSH."
}

installOhMyZSH () {
    runAsUser 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"'
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
           reflector \
           grep > /dev/null 2> /tmp/err || errorDialog "Failed to install basic packages. Check your internet connection please."

    installZSH
}

findBestMirrors () {
    reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist > /dev/null 2> /tmp/err || errorDialog "Something got screwed up and we couldn't accomplish finding some fast and up-to-date servers :("
}

installYaourt () {
    runAsUser "git clone https://aur.archlinux.org/package-query.git /tmp/package-query" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runAsUser "cd /tmp/package-query && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build package-query."
    runAsUser "git clone https://aur.archlinux.org/yaourt.git /tmp/yaourt" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runAsUser "cd /tmp/yaourt && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build Yaourt"
}

installDesktop () {
    pacman -S --noconfirm \
           xorg \
           xorg-xinit \
           xmonad \
           xmonad-contrib \
           xmobar \
           feh \
           unclutter \
           scrot \
           dmenu > /dev/null 2> /tmp/err || errorDialog "Failed to install desktop packages. Are you connected to internet?"
}

installDevTools () {
    pacman -S --noconfirm \
           python \
           python-pip > /dev/null 2> /tmp/err || errorDialog "Failed to install programming packages. Are you connected to internet?"
}

installCLITools () {
    pacman -S --noconfirm \
           acpi \
           powertop \
           htop > /dev/null 2> /tmp/err || errorDialog "Failed to install command-line utilities. Are you connected to internet?"
}

installMedia () {
    pacman -S --noconfirm \
        alsa-utils \
        mplayer \
        moc > /dev/null 2> /tmp/err || errorDialog "Failed to install media"
}

installFonts () {
    pacman -S --noconfirm \
           ttf-symbola> /dev/null 2> /tmp/err || errorDialog "Failed to install fonts"

    runAsUser 'yaourt -S --noconfirm \
           ttf-mac-fonts \
           system-san-francisco-font-git \
           noto-fonts-emoji \
           ttf-emojione-color \
           adobe-base-14-fonts \
           ttf-monaco > /dev/null 2> /tmp/err || errorDialog "Failed to install Mac fonts. Are you connected to internet?"'
}

installURXVT () {
    runAsUser 'yaourt --noconfirm -S rxvt-unicode-256xresources > /dev/null 2> /tmp/err || errorDialog "Failed to install RXVT-Unicode with 256 colors"'
}

runAsUser () {
    # run given command as a non-root user
    getvar "username"
    username=$value
    runuser -l $username -c "$1"
}

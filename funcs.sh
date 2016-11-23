DISTRO_DL="https://git.io/vXbTE"

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

    arch-chroot /mnt <<EOF
mkdir -p /usr/local/installer && cd /usr/local/installer
curl -L $DISTRO_DL > ./install
echo -e "system-partition=$systempt\ndisk=$disk\ncore-install-step=done\npartition-step=done" > ./install-vars
chmod +x ./install
pacman -S --noconfirm dialog
./install continue
EOF
}

installGRUB () {
    pacman -S --noconfirm grub 2> /tmp/err || errorDialog "Failed to install GRUB"
    getvar "disk"
    grub-install --target=i386-pc --recheck $value 2> /tmp/err || errorDialog "Failed to install GRUB"
}

localize () {
    tzselect 2> /tmp/err || errorDialog "tzselect is missing"
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
    getvar "dot-files-repo"
    dotFilesRepo=$value

    getvar "username"
    username=$value

    dotFilesBase=$(basename "$dotFilesRepo")
    runuser -l $username -c "git clone $dotFilesRepo ~/${dotFilesBase} && ln -s ~/${dotFilesBase}/.* ~/." > /dev/null 2> /tmp/err || errorDialog "Can not install dotfiles :/"
}

installLTSKernel () {
    pacman -S --noconfirm linux-lts linux-lts-headers 2> /tmp/err || errorDialog "Can not install Linux LTS Kernel"
    sed -i '/GRUB_DEFAULT=0/c\GRUB_DEFAULT=saved' /etc/default/grub
    sed -i '/GRUB_GFXMODE=auto/c\GRUB_GFXMODE=1024x768x32' /etc/default/grub
    sed -i -e '/^#GRUB_COLOR_NORMAL/s/^#//' /etc/default/grub
    sed -i -e '/^#GRUB_COLOR_HIGHLIGHT/s/^#//' /etc/default/grub
    echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
    echo "GRUB_DISABLE_SUBMENU=y" >> /etc/default/grub
}

installNode () {
	  runuser -l azer -c <<EOF
curl https://raw.github.com/creationix/nvm/master/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 7.1.0
nvm use 7.1.0
nvm alias default 0.10
EOF
}

installOhMyZSH () {
    runuser -l azer -c '$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)'
}

installSpacemacs () {
    git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
}

installVimrc () {
    git clone git://github.com/amix/vimrc.git ~/.vim_runtime
    sh ~/.vim_runtime/install_awesome_vimrc.sh
}

installVimJanus () {
    curl -L https://bit.ly/janus-bootstrap | bash
}

installVirtualBox () {
    pacman --noconfirm -Sy virtualbox-guest-utils virtualbox-guest-modules virtualbox-guest-modules-lts virtualbox-guest-dkms
    echo "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
    systemctl enable vboxservice.service
}

installExtraPackages () {
    pacman --noconfirm -Syu 2> /tmp/err || errorDialog "Can not install updates."
    pacman -S \
           --noconfirm \
           base-devel \
           net-tools \
           pkgfile \
           xf86-video-vesa \
           xorg-server \
           xorg-server-utils \
           xorg-apps \
           ttf-dejavu \
           ttf-droid \
           ttf-inconsolata \
           ttf-symbola \
           ttf-bitstream-vera \
           terminus-font \
           curl \
           wget \
           git \
           tmux \
           zsh \
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
           vim \
           htop \
           go 2> /tmp/err || errorDialog "Failed to complete installing extra packages"
}

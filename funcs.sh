DISTRO_DL="https://git.io/vXbTE"

autoPartition () {
    parted /dev/sda --script mklabel msdos \
           mkpart primary ext4 0% 100% \
           set 1 boot on 2> /tmp/err || errorDialog "Failed to create disk partitions"
    mkfs.ext4 /dev/sda1 > /dev/null 2> /tmp/error || error "Failed to format the root partition"
}

installCoreSystem () {
    getvar "system-partition"
    mount $value /mnt
    pacstrap /mnt base
    genfstab -U /mnt >> /mnt/etc/fstab

    mkdir /mnt/usr/local/installer
    curl -L $DISTRO_DL > /mnt/usr/local/installer/install
    chmod +x /mnt/usr/local/installer/install.sh
    cp ./install-vars /mnt/usr/local/installer/.

    arch-chroot /mnt <<EOF
pacman -Sy --noconfirm dialog
cd /usr/local/installer
./install
EOF
}

installGRUB () {
    pacman -Sy --noconfirm grub 2> /tmp/err || errorDialog "Failed to install GRUB"
    getvar "boot-partition"
    grub-install --target=i386-pc $value 2> /tmp/err || errorDialog "Failed to install GRUB"
}

localize () {
    tzselect 2> /tmp/error || errorDialog "tzselect is missing"
    hwclock --systohc
    sed -i -e '/^#en_US/s/^#//' /etc/locale.gen # uncomment lines starting with #en_US
    locale-gen 2> /tmp/error || errorDialog "locale-gen is missing"

    # FIX ME: Allow user to choose language and keyboard
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
}

createUser () {
    useradd -m -s /bin/bash $1
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

    su - $username
    git clone $dotFilesRepo ~/.
    dotFilesBase=$(basename "$dotFilesRepo")
    ln -s ~/$dotFilesBase/.* ~/
    exit
}

installLTSKernel () {
    pacman -S --noconfirm linux-lts linux-lts-headers 2> /tmp/err || error "Can not install Linux LTS Kernel"
    sed -i '/GRUB_DEFAULT=0/c\GRUB_DEFAULT=saved' /etc/default/grub
    sed -i '/GRUB_GFXMODE=auto/c\GRUB_GFXMODE=1024x768x32' /etc/default/grub
    sed -i -e '/^#GRUB_COLOR_NORMAL/s/^#//' /etc/locale.gen
    sed -i -e '/^#GRUB_COLOR_HIGHLIGHT/s/^#//' /etc/locale.gen
    echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
    echo "GRUB_DISABLE_SUBMENU=y" >> /etc/default/grub
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
    sudo pacman --no-confirm -Syu 2> /tmp/err || errorDialog "Can not install updates."
    sudo pacman -Sy --noconfirm base-devel \
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
         ttf-ancient-fonts \
         ttf-bitstream-vera \
         terminus-font \
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
v         moc \
         newsbeuter \
         dmenu \
         rxvt-unicode \
         emacs \
         vim \
         htop \
         go 2> /tmp/err || errorDialog "Failed to complete installing extra packages"
}

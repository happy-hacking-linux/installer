prepare () {
    echo "                        =^.^="
    echo "Welcome to installation of Happy Hacking Linux distro."
    echo "                      v11.2016"
    echo ""

    read -p "    Choose a username > " $username
    read -p "    Dotfiles repo if you have one > " $dotfilesRepo
    timedatectl set-ntp true > /dev/null
    success "Cool!"
}

formatDisk () {
    title "Setup Disk Partitions"
    confirm "Your disk will be completely erased. Do you wish to continue?"

    if [ $notconfirmed ]; then
        info "Customize your disk partition with GNU Parted, exit when you're done."
        parted || error "Disk partitioning was failed, try again."
        read -p "    Boot Partition > /dev/" $bootpt
        read -p "    System Partition > /dev/" $systempt
    else
        parted /dev/sda --script mklabel msdos \
               mkpart primary ext4 0% 100% \
               set 1 boot on > /dev/null || error "Failed to setup disk partitions"
        mkfs.ext4 /dev/sda1 > /dev/null || error "Failed to format the disk"
        bootpt=sda1
        systempt=sda1
        success "Disk has been formatted."
    fi
}

installSystem () {
    title "Installing System Packages"

    mount /dev/$systempt /mnt
    pacstrap /mnt base > /dev/null || error "Can not install the base system into your disk"
    genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot /mnt

    success "Core system has been installed."
}

installGRUB () {
    title "Installing system boot (GRUB)..."

    pacman -Sy --noconfirm grub > /dev/null
    grub-install --target=i386-pc /dev/$bootpt
}

installPackages () {
    title "Install Extras"

    info "Installing updates..."
    sudo pacman -Syu > /dev/null || error "Can not install updates."

    info "Installing extra packages for happy hacking"
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
         moc \
         newsbeuter \
         dmenu \
         rxvt-unicode \
         emacs \
         vim \
         go > /dev/null || error "Failed to complete installing extra packages"

    installZSH > /dev/null || error "Can not install ZSH"
    installNode > /dev/null || error "Can not install NodeJS"
    installFonts > /dev/null || error "Can not install fonts"
    installSpacemacs > /dev/null || error "Can not install Spacemacs"
    installVim > /dev/null || error "Can not install Vim"

    success "Hacking packages installed successfully."
}

installVirtualBox () {
    confirm "Is this a VirtualBox installation?"
    if [ $confirmed ]; then
        title "VirtualBox Setup"
        info "Installing VirtualBox Guest Additions..."
        sudo pacman -S virtualbox-guest-utils virtualbox-guest-modules virtualbox-guest-modules-lts virtualbox-guest-dkms

        info "Configuring..."
        echo "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
        sudo systemctl enable vboxservice.service
    fi
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

installVim () {
    git clone git://github.com/amix/vimrc.git ~/.vim_runtime
    sh ~/.vim_runtime/install_awesome_vimrc.sh
}

installDotfiles () {
    if [[ -z "${dotfilesRepo// }" ]]; then
        title "Installing your dotfiles"

        cd /home/$username
        git clone $dotfiles
        ln -s /home/$username/dotfiles/.* /home/$username

        success "Linked all your dotfiles!"
    fi

    if [ -f /home/$username/dotfiles/happy-hacking-post-install.sh ]; then {
        title "Running Your Personal Install Script"
        sh ./dotfiles/happy-hacking-post-install.sh
        success "Done!"
    }
}

configureLocalization () {
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

configureUsers () {
    title "Create User $(username)"
    pacman -

    useradd -m -s /bin/zsh $username
    echo "$(username) ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    su - $username

    success "Now you're logged in as $(username). Let's set you a password."
    passwd $username

    success "Done, now we can continue installing."
}

switchToLTSKernel () {
    title "Finally, we're switching to Linux LTS Kernel..."
    pacman -S --noconfirm linux-lts linux-lts-headers > /dev/null || error "Can not install Linux LTS Kernel"

    sed -i '/GRUB_DEFAULT=0/c\GRUB_DEFAULT=saved' /etc/default/grub
    sed -i '/GRUB_GFXMODE=auto/c\GRUB_GFXMODE=1024x768x32' /etc/default/grub
    sed -i -e '/^#GRUB_COLOR_NORMAL/s/^#//' /etc/locale.gen
    sed -i -e '/^#GRUB_COLOR_HIGHLIGHT/s/^#//' /etc/locale.gen
    echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
    echo "GRUB_DISABLE_SUBMENU=y" >> /etc/default/grub

    success "Done, we got a more stable kernel now."
}

row () {
    echo -e "    $1"
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
    row "$1"
}

error () {
    echo ""
    colored "Error: $1" "31"
    echo ""
    exit 1
}

success () {
    echo ""
    colored "$1" "32"
    echo ""
}

confirm () {
    read -p "    $1 (y/n) " -n 1 -r
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
installSystem
installGRUB
configureLocalization
configureUsers
installPackages
installDotfiles
switchToLTSKernel

echo ""
echo "         =^.^="
echo "Installation is Complete!"

confirm "Would you like to restart the system?"
if [ $confirmed ]; then
    sudo reboot
else
    row "Ok, you can reboot whenever you want. Bye!"
fi

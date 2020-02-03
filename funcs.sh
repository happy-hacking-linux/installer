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

    dialog --infobox "Looking for faster and more up-to-date mirrors for rest of the installation..." 6 50; findBestMirrors

    pacstrap /mnt base linux linux-firmware
    genfstab -U /mnt >> /mnt/etc/fstab

    setvar "core-install-step" "done"

    mkdir -p /mnt/usr/local/installer
    cp install-vars /mnt/usr/local/installer/.
    cp autorun.sh /mnt/usr/local/installer/install
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

    mkdir -p /mnt/etc/netctl
    cp /etc/netctl/* /mnt/etc/netctl/.

    arch-chroot /mnt <<EOF
cd /usr/local/installer
pacman -S --noconfirm zsh dialog
./install continue 2> ./error-logs
EOF

    if [ -f /mnt/tmp/reboot ]; then
        echo "Ciao!"
        reboot
    fi
}

installGRUB () {
    installPkg "grub"
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
    runuser -l $username -c "git clone $1 $target"
    #runuser -l $username -c "git clone $1 $target && cd $target && for file in .*; do cd /home/$username && rm -rf \$file && ln -s $target/\$file \$file; done" > /dev/null 2> /tmp/err || errorDialog "Can not install dotfiles at $1 :/"
}

installHappyDesktopConfig () {
    getvar "username"
    username=$value
    runuser -l $username -c "git clone https://github.com/happy-hacking-linux/happy-desktop.git /home/$username/.happy-desktop" > /dev/null 2> /tmp/err || errorDialog "Failed to clone the default desktop configuration. Please check your connection."
    runuser -l $username -c "mkdir -p /home/$username/.config"
    runuser -l $username -c "cd /home/$username/.config && ln -sf /home/$username/.happy-desktop/config/* ." > /dev/null 2>> /tmp/err || errorDialog "Failed to link desktop configuration."
    runuser -l $username -c "cd /home/$username && ln -sf /home/$username/.happy-desktop/dotfiles/.* ." > /dev/null 2>> /tmp/err || errorDialog "Failed to link default dotfiles."
}

installZSH () {
    installPkg "zsh"

    chsh -s $(which zsh) > /dev/null 2> /tmp/err || errorDialog "Something got screwed up, we can't change the default shell to ZSH."
    getvar "username"
    username=$value
    chsh -s $(which zsh) $username > /dev/null 2> /tmp/err || errorDialog "Something got screwed up, we can't change the default shell to ZSH."
}

installOhMyZSH () {
    getvar "username"
    username=$value

    installAurPkg "oh-my-zsh-git"
    cp /usr/share/oh-my-zsh/zshrc /home/$username/.zshrc
}

installYay () {
    installAurPkg "yay"
}

installVirtualBox () {
    installPkg "virtualbox-guest-modules-arch"
    installPkg "virtualbox-guest-utils"
    echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
    systemctl enable vboxservice.service
}

installMacbook () {
    # Fix sound
    echo "options snd-hda-intel index=1,0" > /etc/modprobe.d/alsa.conf

    # Create a service to make fix suspend issues
    cat <<EOT >> /etc/systemd/system/suspend-fix.service
[Unit]
Description=System service that makes sure Macbook Pro doesn't wake up when lid is closed

[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo XHC1 > /proc/acpi/wakeup && echo LID0 > /proc/acpi/wakeup"

[Install]
WantedBy=multi-user.target
EOT

    systemctl enable suspend-fix

    # Create a service to make fix suspend issues
    cat <<EOT >> /etc/systemd/system/restart-network-after-suspend.service
[Unit]
Description=Restart network when resumed after suspend

[Service]
ExecStart=/bin/sh -c "modprobe -r brcmfmac && modprobe brcmfmac && sleep 1 && systemctl restart netctl"

[Install]
WantedBy=suspend.target
EOT

    systemctl enable restart-network-after-suspend

    installAurPkg "bcwc-pcie-git" # Webcam support
    systemctl enable bluetooth

}

installBasicPackages () {
    installPkg "base-devel"
    installPkg "net-tools"
    installPkg "pkgfile"
    installPkg "xf86-video-vesa"
    installPkg "openssh"
    installPkg "wget"
    installPkg "git"
    installPkg "acpi"
    installPkg "powertop"
    installPkg "htop"
    installPkg "python"
    installPkg "python-pip"
    installPkg "wpa_supplicant"
    installPkg "mc"
    installPkg "httpie"
    installPkg "dnsutils"
    installPkg "tlp"
    installPkg "unzip"
    installPkg "xf86-input-synaptics"
    installPkg "bat"
    installPkg "prettyping"
    installPkg "fzf"
    installPkg "tldr"
    installPkg "ack"
    installPkg "tmux"
    installPkg "ranger"
    installPkg "lsd"
    installPkg "fd"
    installPkg "ripgrep"
    installPkg "irssi"
    installPkg "tree"
    installPkg "bandwhich"
    installPkg "wireless-regdb"
    installPkg "wireless_tools"
    installPkg "netctl"
    installPkg "ntfs-3g"
    installPkg "dhclient"
    installPkg "dhcpcd"
    installPkg "b43-fwcutter"
    installPkg "broadcom-wl"
    installPkg "vim"
    installAurPkg "skm"
    installZSH
}

installPrinterSupport () {
    installPkg "cups"
    installPkg "avahi"
}

upgrade () {
    pacman --noconfirm -Syu > /dev/null 2> /tmp/err || errorDialog "Failed to upgrade the system. Make sure being connected to internet."
}

findBestMirrors () {
    createMirrorList > /dev/null 2> /tmp/err || errorDialog "Something got screwed up and we couldn't accomplish finding some fast and up-to-date servers :("
}

installYaourt () {
    runAsUser "git clone https://aur.archlinux.org/package-query.git /tmp/package-query" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runAsUser "cd /tmp/package-query && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build package-query."
    runAsUser "git clone https://aur.archlinux.org/yaourt.git /tmp/yaourt" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runAsUser "cd /tmp/yaourt && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build Yaourt"
}

installSwayDesktop () {
    installPkg "sway"
    installPkg "swaybg"
    installPkg "swayidle"
    installPkg "swaylock"
    installPkg "alacritty"
    installPkg "grim"
    installPkg "rofi"
    installPkg "waybar"
    installPkg "feh"
    installPkg "alsa-utils"
    installPkg "playerctl"
    installPkg "mako"
    installPkg "qalculate-gtk"
    installPkg "waybar"
    installPkg "ffmpeg"
    installPkg "jq"
    installPkg "xorg-server-xwayland"
    installPkg "imagemagick"
    installPkg "xdpyinfo"
}

installI3Desktop () {
    installPkg "xorg"
    installPkg "xorg-xinit"
    installPkg "compton"
    installPkg "i3-gaps"
    installPkg "i3status"
    installPkg "i3lock"
    installPkg "rofi"
    installPkg "feh"
    installPkg "unclutter"
    installPkg "scrot"
    installPkg "dmenu"
    installPkg "alsa-utils"
    installPkg "moc"
    installPkg "slop"
    installPkg "playerctl"
    installPkg "libnotify"
    installPkg "dunst"
    installPkg "qalculate-gtk"
    installPkg "compton"
    installPkg "udisks2"
    installPkg "udiskie"
    installPkg "imagemagick"
    installPkg "maim"
    installAurPkg "polybar"
    installAurPkg "light-git"
}

installXfce4Desktop () {
    installPkg "xfce4"
}

installFonts () {
    installPkg "ttf-dejavu"
    installPkg "adobe-source-han-serif-otc-fonts"
    installPkg "adobe-source-han-sans-otc-fonts"
    installAurPkg "ttf-monaco"
    installAurPkg "noto-fonts-emoji"
    installAurPkg "system-san-francisco-font-git"
}

installURXVT () {
    installAurPkg "rxvt-unicode-256xresources"  > /dev/null 2> /tmp/err || errorDialog "Failed to install RXVT-Unicode with 256 colors"
    installPkg "urxvt-perls"
}

installRefind () {
    installPkg "refind-efi"
    runuser -l $username -c "refind-install" > /dev/null 2> /tmp/err
    getvar "system-partition"
    systempt=$value
    getUUID $systempt
    echo "\"Boot using default options\"     \"root=UUID=$uuid rw add_efi_memmap\"" > /boot/refind_linux.conf
    echo "\"Boot using fallback initramfs\"  \"root=UUID=$uuid rw add_efi_memmap initrd=/boot/initramfs-linux-fallback.img\"" >> /boot/refind_linux.conf
    echo "\"Boot to terminal\"               \"root=UUID=$uuid rw add_efi_memmap systemd.unit=multi-user.target\"" >> /boot/refind_linux.conf
}

installPkg () {
    installationProgress "$1"
    pacman -S --noconfirm "$1" > /dev/null 2> /tmp/err || errorDialog "Something went wrong with installing $1. Try again."
}

installAurPkg () {
    installationProgress "$1"
    runAsUser "yaourt -S --noconfirm $1" > /dev/null 2> /tmp/err || errorDialog "Something went wrong with installing $1. Try again."
}

runAsUser () {
    # run given command as a non-root user
    getvar "username"
    username=$value
    runuser -l $username -c "$1"
}

getUUID() {
    name=$(sed  's/^\/dev\///' <<< $1)
    uuid=$(/bin/ls -la /dev/disk/by-uuid | grep "$name"  | awk '{print $9}')
}

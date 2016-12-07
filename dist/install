touch ./install-vars

setvar () {
    grep -v "^$1=" ./install-vars > ./install-vars.new && mv ./install-vars.new ./install-vars
    echo "$1=$2" >> ./install-vars
}

getvar () {
    value=$(grep "^$1=" ./install-vars | tail -n 1 | sed "s/^$1=//")
}
detectTimezone () {
    if command_exists tzupdate ; then
        dialog --infobox "Please wait, detecting your timezone... " 5 50; detected=$(tzupdate -p | sed "s/Detected timezone is //" | sed "s/\.//")
        return
    fi

    detected=""
}

tzOptionsByRegion () {
    options=$(cd /usr/share/zoneinfo/$1 && find . | sed "s|^\./||" | sed "s/^\.//" | sed '/^$/d')
}

tzRegions () {
    regions=$(find /usr/share/zoneinfo/. -maxdepth 1 -type d | cut -d "/" -f6 | sed '/^$/d')
}

tzSelectionMenu () {
    detectTimezone

    if [[ -n "${detected// }" ]]; then
        if [ -f "/usr/share/zoneinfo/$detected" ]; then
           offset=$(TZ="$detected" date +%z | sed "s/00$/:00/g")

           dialog --title "Timezones" \
                  --backtitle "Happy Hacking Linux" \
                  --yes-label "Yes, correct" \
                  --no-label "No, I'll choose it" \
                  --yesno "Your timezone was detected as $detected ($offset). Is it correct?" 7 50
           selected=$?

           if [ "$selected" = "0" ]; then
               tzupdate > /dev/null
               return
           fi
        fi
    fi

    tzRegions
    regionsArray=()
    while read name; do
        regionsArray+=($name "")
    done <<< "$regions"

    region=$(dialog --stdout \
                      --title "Timezones" \
                      --backtitle "$1" \
                      --ok-label "Next" \
                      --no-cancel \
                      --menu "Select a continent or ocean from the menu:" \
                      20 30 30 \
                      "${regionsArray[@]}")

    tzOptionsByRegion $region

    optionsArray=()
    while read name; do
        offset=$(TZ="$region/$name" date +%z | sed "s/00$/:00/g")
        optionsArray+=($name "($offset)")
    done <<< "$options"

    tz=$(dialog --stdout \
                    --title "Timezones" \
                    --backtitle "$1" \
                    --ok-label "Next" \
                    --cancel-label "Back to Regions" \
                    --menu "Select your timezone in ${region}:" \
                    20 40 30 \
                    "${optionsArray[@]}")

    if [[ -z "${tz// }" ]]; then
        tzSelectionMenu
    else
        selected="/usr/share/zoneinfo/$region/$tz"
    fi
}

command_exists () {
    type "$1" &> /dev/null ;
}
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
    runuser -l $username -c "git clone $1 $target && cd $target && for file in .*; do cd /home/$username && rm -rf \$file && ln -s $target/\$file \$file; done" > /dev/null 2> /tmp/err || errorDialog "Can not install dotfiles at $1 :/"
}

installDefaultDotFiles () {
    getvar "username"
    username=$value
    runuser -l $username -c "git clone https://github.com/happy-hacking-linux/dotfiles.git /tmp/dotfiles && cp -rf /tmp/dotfiles/.* /home/$username/. && rm -rf ~/.git" > /dev/null 2> /tmp/err || errorDialog "Failed to install the default Happy Hacking dotfiles :/"
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

installVirtualBox () {
    installPkg "virtualbox-guest-modules-arch"
    installPkg "virtualbox-guest-utils"
    echo -e "vboxguest\nvboxsf\nvboxvideo" > /etc/modules-load.d/virtualbox.conf
    systemctl enable vboxservice.service
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
    installZSH
}

upgrade () {
    pacman --noconfirm -Syu > /dev/null 2> /tmp/err || errorDialog "Failed to upgrade the system. Make sure being connected to internet."
}

findBestMirrors () {
    installPkg "reflector"

    reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist > /dev/null 2> /tmp/err || errorDialog "Something got screwed up and we couldn't accomplish finding some fast and up-to-date servers :("
}

installYaourt () {
    runAsUser "git clone https://aur.archlinux.org/package-query.git /tmp/package-query" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runAsUser "cd /tmp/package-query && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build package-query."
    runAsUser "git clone https://aur.archlinux.org/yaourt.git /tmp/yaourt" > /dev/null 2> /tmp/err || errorDialog "Can not access Arch Linux repositories, check your internet connection."
    runAsUser "cd /tmp/yaourt && yes | makepkg -si" > /dev/null 2> /tmp/err || errorDialog "Failed to build Yaourt"
}

installXmonadDesktop () {
    installPkg "xorg"
    installPkg "xorg-xinit"
    installPkg "xmonad"
    installPkg "xmonad-contrib"
    installPkg "xmobar"
    installPkg "feh"
    installPkg "unclutter"
    installPkg "scrot"
    installPkg "dmenu"
    installPkg "alsa-utils"
    installPkg "mplayer"
    installPkg "moc"
}

installXfce4Desktop () {
    installPkg "xfce4"
}

installFonts () {
    installPkg "ttf-symbola"
    installPkg "ttf-dejavu"
    installAurPkg "ttf-monaco"
    installAurPkg "noto-fonts-emoji"
    installAurPkg "ttf-emojione-color"
}

installURXVT () {
    installAurPkg "rxvt-unicode-256xresources"  > /dev/null 2> /tmp/err || errorDialog "Failed to install RXVT-Unicode with 256 colors"
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

connectToInternet () {
    if ip link show | grep -i eth0 -q; then
        systemctl enable dhcpcd@eth0.service
    fi

    if ip link show | grep -i enp0s3 -q; then
        systemctl enable dhcpcd@enp0s3.service
    fi
}
CHECK="[OK]"

startingDialogs () {
    nameDialog
    usernameDialog

    dotFilesRepo=$(dialog --stdout \
                      --title "=^.^=" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Next" \
                      --cancel-label "Skip" \
                      --inputbox "Where is your dotfiles, $name?" 8 55 "https://github.com/$username/dotfiles.git")
}

mainMenu () {
    icon1=""
    icon2=""
    icon3=""
    icon4=""
    icon5=""

    getvar "partition-step"
    if [ "$value" = "done" ]; then
        icon1="${CHECK} "
    fi

    getvar "core-install-step"
    if [ "$value" = "done" ]; then
        icon2="${CHECK} "
    fi

    getvar "users-step"
    if [ "$value" = "done" ]; then
        icon3="${CHECK} "
    fi

    getvar "install-packages-step"
    if [ "$value" = "done" ]; then
        icon4="${CHECK} "
    fi

    getvar "localization-step"
    if [ "$value" = "done" ]; then
        icon5="${CHECK} "
    fi

    selected=$(dialog --stdout \
                      --title "=^.^=" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Select" \
                      --cancel-label "Welcome Screen" \
                      --menu "Complete the following installation steps one by one." 16 55 8 \
                      1 "${icon1}Setup Disk Partitions" \
                      2 "${icon2}Install Core System" \
                      3 "${icon3}Create Users" \
                      4 "${icon4}Install Packages" \
                      5 "${icon5}Localize" \
                      6 "Reboot")

    button=$?
}

diskMenu () {
    disks=$(lsblk -r | grep disk | cut -d" " -f1,4 | nl)
    disksArray=()
    while read i name size; do
        disksArray+=($i "/dev/$name ($size)")
    done <<< "$disks"

    selected=$(dialog --stdout \
                      --title "Installation Disk" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Next" \
                      --cancel-label "Main Menu" \
                      --menu "Select A Disk" \
                      15 30 30 \
                      "${disksArray[@]}")

    button=$?

    selected=$(lsblk -r | grep disk | cut -d" " -f1 | sed -n "${selected}p")
    selected="/dev/${selected}"
    setvar "disk" "$selected"
}

partitionMenu () {
    selected=$(dialog --stdout \
                      --title "Setup Disk Partitions" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Select" \
                      --cancel-label "Main Menu" \
                      --menu "How do you want to create partitions? If you got nothing to lose in $1, just go with the simple option and format the disk completely. Or, choose one of the tools to modify your disk in your own risk." 17 55 5 \
                      1 "Simple: Erase Everything on $1" \
                      2 "Manual: Using cfdisk" \
                      3 "Manual: Using fdisk" \
                      4 "Manual: Using GNU Parted")
}

partitionSelectionForm () {
    values=$(dialog --stdout \
                    --ok-label "Done" \
	                  --backtitle "Happy Hacking Linux" \
	                  --title "Select Partitions" \
                    --nocancel \
	                  --form "" \
                    7 50 0 \
	                  "Root: "    2 1	"${1}1"  	2 10 45 0)

    systempt=$(echo "$values" | tail -n1)

    if [[ -z "${systempt// }" ]]; then
        dialog --title "Select System Partition" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "Sorry, you have to choose the partition you'd like to install the system." 6 50
        partitionSelectionForm
    else
        setvar "system-partition" $systempt
    fi
}



nameDialog () {
    name=$(dialog --stdout \
                      --title "=^.^" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Next" \
                      --nocancel \
                      --inputbox "Oh, hai! What's your name?" 8 55)

    if [[ -z "${name// }" ]]; then
        dialog --title "=^.^=" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "Type your name please, or make something up" 5 55
        nameDialog
    fi
}

usernameDialog () {
    username=$(echo "$name" | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr A-Z a-z)

    username=$(dialog --stdout \
                      --title "=^.^" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Next" \
                      --nocancel \
                      --inputbox "...and your favorite username?" 8 55 "$username")

    if [[ -z "${username// }" ]]; then
        dialog --title "=^.^=" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "A username is required, try again" 5 55
        usernamedDialog
    fi
}

passwordDialog () {
    password=$(dialog --stdout \
                           --title "Creating User" \
                           --backtitle "Happy Hacking Linux" \
                           --ok-label "Done" \
                           --nocancel \
                           --passwordbox "Type a new password:" 8 50)

    passwordRepeat=$(dialog --stdout \
                            --title "Creating User" \
                            --backtitle "Happy Hacking Linux" \
                            --ok-label "Done" \
                            --nocancel \
                            --passwordbox "Verify your new password:" 8 50)

    if [ "$password" != "$passwordRepeat" ]; then
        dialog --title "Password" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "Passwords you've typed don't match. Try again." 5 50
        passwordDialog
    fi

    if [[ -z "${password// }" ]]; then
        dialog --title "Password" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "A password is required. Try again please." 5 50
        passwordDialog
    fi
}

errorDialog () {
    echo "$1\n\n" > ./install-errors.log
    [[ -f /tmp/err ]] && cat /tmp/err >> ./install-errors.log

    echo "Message: $1\nOutput: \n" | cat - /tmp/err > /tmp/err.bak && mv /tmp/err.bak /tmp/err

    dialog --title "Oops, there was an error" \
           --backtitle "Happy Hacking Linux" \
           --textbox /tmp/err 20 50

    rm /tmp/err
    mainMenuStep
}

installationProgress () {
    total=37
    instcounter=$((instcounter+1))
    percent=$((100*$instcounter/$total))

    echo $percent | dialog --title "Installation" \
                           --backtitle "Happy Hacking Linux" \
                           --gauge "Downloading package: $1" \
                           7 70 0
}
command=$1

mainMenuStep () {
    mainMenu

    if [ "$button" = "1" ]; then
        setvar "starting-step" ""
        startingStep
        return
    fi

    if [ "$selected" = "1" ]; then
        partitionStep
    elif [ "$selected" = "2" ]; then
        coreInstallStep
    elif [ "$selected" = "3" ]; then
        usersStep
    elif [ "$selected" = "4" ]; then
        installPackagesStep
    elif [ "$selected" = "5" ]; then
        localizeStep
    elif [ "$selected" = "6" ]; then
        connectToInternetStep
        exitStep
    fi
}

installVirtualBoxStep () {
    # Install VirtualBox Guest additions if the installation is running in a VirtualBox machine
    if lspci | grep -i virtualbox -q; then
        dialog --infobox "Looks like this is a VirtualBox setup, hold on please..." 5 50; installVirtualBox
    fi
}

installDotFilesStep () {
    getvar "dot-files-repo"
    dotFilesRepo=$value

    if [[ -n "${dotFilesRepo// }" ]]; then
        dialog --infobox "Fingers crossed, we're linking your dotfiles into ~/" 5 50; linkDotFiles $dotFilesRepo

        dotFilesBase=$(basename "$dotFilesRepo" | cut -f 1 -d '.')
        if [ -f /home/$username/$dotFilesBase/post-install.sh ]; then
            dialog --infobox "Running personal post-install commands, I hope we won't screw up anything" 5 50; runuser -l $username -c "sh /home/$username/$dotFilesBase/post-install.sh"
        fi
    fi
}

installBootStep () {
    getvar "boot-install-step"
    if [ "$value" != "done" ]; then
        dialog --infobox "Installing GRUB for /boot" 5 50; installGRUB
        setvar "boot-install-step" "done"
    fi
}

installYaourtStep () {
    getvar "install-yaourt-step"
    if [ "$value" == "done" ]; then
        return
    fi

    dialog --infobox "Installing AUR and Yaourt..." 5 50; installYaourt
    setvar "install-yaourt-step" "done"
}

findBestMirrorsStep () {
    getvar "find-best-mirrors-step"
    if [ "$value" == "done" ]; then
        return
    fi

    dialog --infobox "Looking for faster and more up-to-date mirrors for rest of the installation..." 6 50; findBestMirrors

    setvar "find-best-mirrors-step" "done"
}

installBasicPackagesStep () {
    getvar "install-basic-packages-step"
    if [ "$value" == "done" ]; then
        return
    fi

    installBasicPackages "Basic Packages"
    setvar "install-basic-packages-step" "done"
}

upgradeStep () {
    getvar "upgrade-step"
    if [ "$value" == "done" ]; then
        return
    fi

    dialog --infobox "Upgrading the system..." 5 50; upgrade

    setvar "upgrade-step" "done"
}

installPackagesStep () {
    getvar "install-packages-step"
    if [ "$value" == "done" ]; then
        localizeStep
        return
    fi

    upgradeStep
    findBestMirrorsStep

    installBasicPackagesStep
    installYaourtStep
    installOhMyZSH
    installFonts
    installURXVT
    installXmonadDesktop
    dialog --infobox "Installing Default Configuration..." 5 50; installDefaultDotFiles
    installDotFilesStep
    installVirtualBoxStep
    installBootStep

    setvar "install-packages-step" "done"

    localizeStep
}

connectToInternetStep () {
    # currently just enables eth0 or enp0s3
    dialog --infobox "Connecting to internet..." 5 50; connectToInternet
}

exitStep () {
    dialog --title "=^.^=" \
           --backtitle "Happy Hacking Linux" \
           --yes-label "Reboot" \
           --no-label "Main Menu" \
           --yesno "Installation seems to be done, let's reboot your system. Don't forget ejecting the installation disk." 13 55
    if [ "$?" = "0" ]; then
        touch /tmp/reboot
        exit
    else
        mainMenuStep
    fi
}

usersStep () {
  getvar "users-step"

  if [ "$value" == "done" ]; then
      installPackagesStep
      return
  fi

  passwordDialog

  getvar "username"
  username=$value

  createUser $username $password

  setvar "users-step" "done"
  installPackagesStep
}

localizeStep () {
    getvar "localization-step"
    if [ "$value" != "done" ]; then
        localize
        setvar "localization-step" "done"
    fi

    exitStep
}

coreInstallStep () {
    getvar "core-install-step"
    if [ "$value" != "done" ]; then
        dialog --infobox "Bootstrapping the core system, it may take a while depending on your connection." 6 50; installCoreSystem
        setvar "core-install-step" "done"
    fi

    usersStep
}

partitionStep () {
    diskMenu

    if [ "$button" = "1" ]; then
        mainMenuStep
        return
    fi

    disk=$selected

    partitionMenu $disk

    if [ "$selected" = "1" ]; then
        autoPartition $disk
    elif [ "$selected" = "2" ]; then
        cfdisk $disk
        partitionSelectionForm $disk
    elif [ "$selected" = "3" ]; then
        fdisk $disk
        partitionSelectionForm $disk
    elif [ "$selected" = "4" ]; then
        parted $disk
        partitionSelectionForm $disk
    elif [ "$selected" = "5" ]; then
        mainMenuStep
        return
    else
        mainMenuStep
        return
    fi

    setvar "partition-step" "done"
    coreInstallStep
}

startingStep () {
    getvar "starting-step"
    if [ "$value" == "done" ]; then
        mainMenuStep
    fi

    init
    startingDialogs

    setvar "name" $name
    setvar "username" $username
    setvar "dot-files-repo" $dotFilesRepo

    setvar "starting-step" "done"
    partitionStep
}

if [ "$command" = "continue" ]; then
    usersStep
else
    startingStep
fi

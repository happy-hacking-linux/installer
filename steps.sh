command=$1

mainMenuStep () {
    mainMenu

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
        rebootStep
    else
        startingStep
    fi
}

installVirtualBoxStep () {
    # Install VirtualBox Guest additions if the installation is running in a VirtualBox machine
    if lspci | grep -i virtualbox -q; then
        dialog --infobox "Installing VirtualBox Guest Additions" 10 50; installVirtualBox
    fi
}

installDotFilesStep () {
    getvar "dot-files-repo"
    dotFilesRepo=$value

    if [[ -n "${dotFilesRepo// }" ]]; then
        dialog --infobox "Linking your dotfiles into ~/" 10 50; linkDotFiles $1

        if [ -f /home/$username/$dotFilesBase/post-install.sh ]; then
            dialog --infobox "Running personal post-install commands..." 10 50; sh /home/$username/$dotFilesBase/post-install.sh
        fi
    fi
}

installBootStep () {
    getvar "boot-install-step"
    if [ "$value" != "done" ]; then
        dialog --infobox "Installing GRUB for /boot" 10 50; installGRUB
        setvar "boot-install-step" "done"
    fi
}

installPackagesStep () {
    getvar "install-packages-step"
    if [ "$value" == "done" ]; then
        return
    fi

    dialog --infobox "Upgrading system" 10 50; upgradeSystem
    dialog --infobox "Installing Oh My ZSH" 10 50; installOhMyZSH
    dialog --infobox "Installing AUR and Yaourt" 10 50; installYaourt
    dialog --infobox "Installing Programming Packages" 10 50; installDevTools
    dialog --infobox "Installing CLI Utilities" 10 50; installDevTools
    dialog --infobox "Installing Fonts" 10 50; installFonts
    dialog --infobox "Installing 256 Color Terminal (URXVT)" 10 50; installURXVT
    dialog --infobox "Installing Xmonad Desktop" 10 50; installDesktop
    dialog --infobox "Installing Default Configuration" 10 50; linkDefaultDotFiles

    installDotFilesStep
    installVirtualBoxStep
    installBootStep

    setvar "install-packages-step" "done"
}

rebootStep () {
    dialog --infobox "Cya!" 10 50; sleep 3 && reboot
}

usersStep () {
  getvar "users-step"
  if [ "$value" != "done" ]; then
      getvar "username"
      username=$value

      getvar "name"
      name=$value

      passwordDialog
      createUser $username $password $name

      setvar "users-step" "done"
  fi

  mainMenuStep
}

localizationStep () {
    getvar "localization-step"
    if [ "$value" != "done" ]; then
        localize
        setvar "localization-step" "done"
    fi

    usersStep
}

coreInstallStep () {
    getvar "core-install-step"
    if [ "$value" != "done" ]; then
        dialog --infobox "Installing core system packages, please wait..." 10 50; installCoreSystem
        afterCoreInstallStep
        setvar "core-install-step" "done"
    fi
}

partitionStep () {
    diskMenu
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
    else
        mainMenuStep
    fi

    setvar "partition-step" "done"
    coreInstallStep
}

startingStep () {
    init
    startingDialogs

    setvar "name" $name
    setvar "username" $username
    setvar "dotFilesRepo" $dotFilesRepo

    if [ "$selected" = "1" ]; then
        partitionStep
    else
        mainMenuStep
    fi
}

if [ "$command" = "continue" ]; then
    afterCoreInstallStep
else
    startingStep
fi

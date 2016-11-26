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
        rebootStep
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

    dialog --infobox "Installing Oh My ZSH..." 5 50; installOhMyZSH
    dialog --infobox "Installing AUR and Yaourt..." 5 50; installYaourt
    dialog --infobox "Installing Programming Packages..." 5 50; installDevTools
    dialog --infobox "Installing CLI Utilities..." 5 50; installDevTools
    dialog --infobox "Installing Fonts..." 5 50; installFonts
    dialog --infobox "Installing 256 Color Terminal (URXVT)..." 5 50; installURXVT
    dialog --infobox "Installing Xmonad Desktop..." 5 50; installDesktop
    dialog --infobox "Installing Default Configuration..." 5 50; linkDefaultDotFiles

    installDotFilesStep
    installVirtualBoxStep
    installBootStep

    setvar "install-packages-step" "done"

    localizeStep
}

rebootStep () {
    rebootDialog

    if [ "$selected" = "0" ]; then
        dialog --infobox "Cya!" 10 50; sleep 3 && reboot
    else
        mainMenu
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

  dialog --infobox "Installing some basic packages before creating users..." 5 50; installBasicPackages

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

    rebootStep
}

coreInstallStep () {
    getvar "core-install-step"
    if [ "$value" != "done" ]; then
        dialog --infobox "Installing core system packages, please wait..." 10 50; installCoreSystem
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
        mainMenu
    fi

    init
    startingDialogs

    setvar "name" $name
    setvar "username" $username
    setvar "dotFilesRepo" $dotFilesRepo

    setvar "starting-step" "done"
    partitionStep
}

if [ "$command" = "continue" ]; then
    usersStep
else
    startingStep
fi

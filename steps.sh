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

installMacbookStep () {
    # Install Macbook if the installation is running in a Macbook
    if lspci | grep -i thunderbolt -q; then
        dialog --infobox "Looks like this is a Macbook, I'll do some adjustments for you..." 5 50; installMacbook
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
        dialog --title "Setup Boot" --yesno "Do you want me to override existing boot with new one ? Warning: You may lose access to a parallel system if exists." 8 40

        if [ "$?" == "0" ]; then
            dialog --infobox "Installing GRUB for /boot" 5 50; installGRUB
            setvar "boot-install-step" "done"
        fi
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
    installMacbookStep
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
        dialog --title "Select Partitions" --yesno "Warning: Disk $disk will be formatted, continue?" 5 40
        if [ "$?" != "0" ]; then
            autoPartition $disk
        else
            partitionStep
        fi
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

networkStep () {
    getvar "network-step"
    if [ "$value" == "done" ]; then
        partitionStep
    fi

    gateway=`ip r | grep default | cut -d ' ' -f 3`
    test=$(ping -q -w 1 -c 1 $gateway> /dev/null && echo 1 || echo 0)

    if [ $test -eq 1 ]; then
        setvar "network-step" "done"
        partitionStep
    else
        wifi-menu
        networkStep
    fi
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
    networkStep
}

if [ "$command" = "continue" ]; then
    usersStep
else
    startingStep
fi

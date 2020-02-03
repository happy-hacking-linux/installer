
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
    fi
}

installBootStep () {
    getvar "boot-install-step"
    if [ "$value" != "done" ]; then
        dialog --title "Setup Boot" --yesno "Do you want me to override existing boot with new one ? Warning: You may lose access to a parallel system if exists." 8 40

        if [ "$?" == "0" ]; then
            dialog --infobox "Installing GRUB for /boot" 5 50; installGRUB
            setvar "boot-install-step" "done"
        else
            installRefindStep
        fi
    fi
}

installRefindStep () {
    getvar "boot-install-step"
    if [ "$value" != "done" ]; then
        dialog --title "Setup rEFInd" --yesno "Do you need rEFInd to be installed?" 8 40

        if [ "$?" == "0" ]; then
            dialog --infobox "Installing rEFInd" 5 50; installRefind
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
    installBasicPackagesStep
    installYaourtStep
    installYay
    installOhMyZSH
    installFonts
    installSwayDesktop
    installDotFilesStep
    dialog --infobox "Configuring Happy Desktop..." 5 50; installHappyDesktopConfig
    installVirtualBoxStep
    installMacbookStep
    installBootStep

    setvar "install-packages-step" "done"

    localizeStep
}

finishingStep() {
    # Make sure brcmfmac is not blacklisted
    sed -i '/brcmfmac/d' /usr/lib/modprobe.d/broadcom-wl.conf 2> /dev/null
    # Enable the wifi interface
    systemctl enable netctl-auto@$(iw dev | awk '$1=="Interface"{print $2}')
    tlp start
}

exitStep () {
    dialog --infobox "Finishing touches..." 5 50; finishingStep

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
        dialog --title "Select Partitions" --yesno "Warning: Disk $disk will be formatted, continue?" 7 40
        if [ "$?" == "0" ]; then
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
        sleep 1
        ./autorun.sh network
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
elif [ "$command" = "network" ]; then
    networkStep
else
    startingStep
fi

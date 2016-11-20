command=$1

mainMenuStep () {
    mainMenu

    if [ "$selected" = "1" ]; then
        partitionStep
    elif [ "$selected" = "2" ]; then
        coreInstallStep
    elif [ "$selected" = "3" ]; then
        installBootStep
    elif [ "$selected" = "4" ]; then
        localizationStep
    elif [ "$selected" = "5" ]; then
        usersStep
    elif [ "$selected" = "6" ]; then
        extrasMenuStep
    elif [ "$selected" = "7" ]; then
        rebootStep
    else
        mainMenuStep
    fi
}

extrasMenuStep () {
    extrasMenu

    if [ "$selected" = "1" ]; then
        dotFilesStep
    elif [ "$selected" = "2" ]; then
        installZSHStep
    elif [ "$selected" = "3" ]; then
        installSpacemacsStep
    elif [ "$selected" = "4" ]; then
        installVimrcStep
    elif [ "$selected" = "5" ]; then
        installVimJanusStep
    elif [ "$selected" = "6" ]; then
        installVirtualBoxStep
    elif [ "$selected" = "7" ]; then
        ltsStep
    else
        mainMenuStep
    fi
}

installVirtualBoxStep () {
    dialog --infobox "Installing VirtualBox Guest Additions" 10 50; installVirtualBox
    extrasMenuStep
}

installVimJanusStep () {
    dialog --infobox "Installing Janus Distro for Vim" 10 50; installVimJanus
    extrasMenuStep
}

installVimrc () {
    dialog --infobox "Installing amix/vimrc" 10 50; installVimrc
    extrasMenuStep
}

installSpacemacs () {
    dialog --infobox "Installing spacemacs" 10 50; installSpacemacs
    extrasMenuStep
}

installZSHStep () {
    dialog --infobox "Installing ZSH" 10 50; installZSH
    extrasMenuStep
}

dotFilesStep () {
    dotFilesDialog

    if [[ -n "${dotFilesRepo// }" ]]; then
        setvar "dot-files-repo" $dotFilesRepo

        dialog --infobox "Linking dotfiles" 10 50; linkDotFiles

        if [ -f /home/$username/$dotFilesBase/happy-hacking-post-install.sh ]; then
            dialog --infobox "Running personal post-install commands..." 10 50; sh /home/$username/$dotFilesBase/happy-hacking-post-install.sh
        fi
    fi

    extrasMenuStep
}

rebootStep () {
    dialog --infobox "Cya!" 10 50; reboot
}

usersStep () {
  usernameDialog
  setvar "username" $username

  passwordDialog
  createUser $username $password

  mainMenuStep
}

localizationStep () {
    localize
    usersStep
}

installBootStep () {
    dialog --infobox "Installing GRUB for /boot" 10 50; installGRUB
    localizationStep
}

switchToLTSStep () {
    dialog --infobox "Switching to Linux LTS Kernel as it's more stable." 10 50; installLTSKernel
}

installExtraPackagesStep () {
    dialog --infobox "Installing some additional packages, this may take some time" 10 50; installExtraPackages
}

coreInstallStep () {
    dialog --infobox "Installing core system packages, please wait..." 10 50; installCoreSystem
    switchToLTSStep
    installExtraPackagesStep
    installBootStep
}

partitionStep () {
    partitionMenu

    if [ "$selected" = "1" ]; then
        autoPartition
        mkfs.ext4 /dev/sda1 > /dev/null 2> /tmp/error || error "Failed to format the disk"
        setvar "boot-partition" "/dev/sda1"
        setvar "system-partition" "/dev/sda1"
    elif [ "$selected" = "2" ]; then
        cfdisk
        partitionSelectionForm
    elif [ "$selected" = "3" ]; then
        fdisk /dev/sda
        partitionSelectionForm
    elif [ "$selected" = "4" ]; then
        parted /dev/sda
        partitionSelectionForm
    elif [ "$selected" = "5" ]; then
        mainMenuStep
    else
        mainMenuStep
    fi

    coreInstallStep
}

startingStep () {
    welcomeMenu

    if [ "$selected" = "1" ]; then
        partitionStep
    else
        mainMenuStep
    fi
}

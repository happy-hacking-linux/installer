welcomeMenu () {
    dialog --title "=^.^=" \
           --backtitle "Happy Hacking Linux" \
           --defaultno \
           --no-label "Next Step" \
           --yes-label "Main Menu" \
           --yesno "Oh, hai. This is the installation wizard of Happy Hacking Linux. If you already started the installation, you can jump to the main menu and run a specific installation step. Otherwise, just hit the next button. \n\nIf you need help or wanna report an issue, go to github.com/azer/happy-hacking-linux" 13 55

    selected=$?
}

mainMenu () {
    selected=$(dialog --stdout \
                      --title "=^.^=" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Select" \
                      --nocancel \
                      --menu "Complete the following installation steps one by one." 16 55 8 \
                      1 "Setup Disk Partitions" \
                      2 "Install Core Packages" \
                      3 "Install Boot (GRUB)" \
                      4 "Localization" \
                      5 "Users" \
                      6 "Install Extras" \
                      7 "Reboot")
}

extrasMenu () {
    selected=$(dialog --stdout \
                      --title "Install Extras" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Install" \
                      --cancel-label "Main Menu" \
                      --menu "You can optionally setup some extra stuff, or return to main menu and reboot." 16 55 7 \
                      1 "dotfiles" \
                      2 "ZSH" \
                      3 "spacemacs: emacs distribution" \
                      4 "amix/vimrc: popular vim distributon" \
                      5 "janus: another popular vim distro" \
                      6 "VirtualBox Guest Additions")
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
                      "${ar[@]}")

    selected=$(lsblk -r | grep part | cut -d" " -f1 | sed -n "${selected}p")
    selected="/dev/${selected}"
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
	                  "/boot" 1 1	"${1}1" 	1 10 45 0 \
	                  "/"    2 1	"${1}1"  	2 10 45 0)

    bootpt=$(echo "$values" | head -n1)
    systempt=$(echo "$values" | tail -n1)

    if [[ (-z "${bootpt// }") || (-z "${systempt// }") ]]; then
        echo "bad input $bootpt and $systempt"
        dialog --title "Select Partitions" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "You need to fill both fields" 6 50
        partitionForm
    else
        setvar "boot-partition" $bootpt
        setvar "system-partition" $systempt
    fi
}

usernameDialog () {
    username=$(dialog --stdout \
                      --title "Creating Users" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Done" \
                      --nocancel \
                      --inputbox "Choose your username" 8 50)

    if [[ -z "${username// }" ]]; then
        dialog --title "Creating Users" \
               --backtitle "Happy Hacking Linux" \
               --msgbox "A username is required, try again" 5 50
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
               --msgbox "A password is required. Try again." 5 50
        passwordDialog
    fi
}

errorDialog () {
    echo "Message: $1\nOutput: \n" | cat - /tmp/err > /tmp/err.bak && mv /tmp/err.bak /tmp/err

    dialog --title "Oops, there was an error" \
           --backtitle "Happy Hacking Linux" \
           --textbox /tmp/err 20 50

    rm /tmp/err
    mainMenuStep
}

dotFilesDialog () {
    getvar "username"

    dotFilesRepo=$(dialog --stdout \
                          --title "dotfiles" \
                          --backtitle "Happy Hacking Linux" \
                          --cancel-label "Skip" \
                          --ok-label "Clone & Link All" \
                          --inputbox "Where is your dotfiles located?" 8 50 "git@github.com:"$username"/dotfiles.git")
}

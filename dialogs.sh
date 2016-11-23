CHECK="[OK]"

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

    getvar "boot-install-step"
    if [ "$value" = "done" ]; then
        icon3="${CHECK} "
    fi

    getvar "localization-step"
    if [ "$value" = "done" ]; then
        icon4="${CHECK} "
    fi

    getvar "users-step"
    if [ "$value" = "done" ]; then
        icon5="${CHECK} "
    fi

    selected=$(dialog --stdout \
                      --title "=^.^=" \
                      --backtitle "Happy Hacking Linux" \
                      --ok-label "Select" \
                      --nocancel \
                      --menu "Complete the following installation steps one by one." 16 55 8 \
                      1 "${icon1}Setup Disk Partitions" \
                      2 "${icon2}Install Core Packages" \
                      3 "${icon3}Install Boot (GRUB)" \
                      4 "${icon4}Localization" \
                      5 "${icon5}Users" \
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
                      2 "spacemacs: emacs distribution" \
                      3 "amix/vimrc: popular vim distributon" \
                      4 "VirtualBox Guest Additions")
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
    echo "$1\n\n" > ./install-errors.log
    [[ -f ~/tmp/err ]] && cat /tmp/err >> ./install-errors.log

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

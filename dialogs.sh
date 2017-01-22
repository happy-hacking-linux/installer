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
        mount $systempt /mnt
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
    total=42
    instcounter=$((instcounter+1))
    percent=$((100*$instcounter/$total))

    echo $percent | dialog --title "Installation" \
                           --backtitle "Happy Hacking Linux" \
                           --gauge "Downloading package: $1" \
                           7 70 0
}

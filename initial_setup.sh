#!/bin/bash

## ----------------------------------
# Step #1: Define variables
# ----------------------------------
RED='\033[0;41;30m'
STD='\033[0;0;39m'

PITYPE="0"
AVRDUDE="FALSE"
SCRIPTDIR="$(dirname "${BASH_SOURCE[0]}")"

# ----------------------------------
# Step #2: User defined function
# ----------------------------------

backUp() {
  DIR=`dirname "${1}"`
  #pushd "${DIR}"
  cp "${1}" "${1}"-`date +%Y%m%d%H%M`.backup
  #popd
}

choosePi() {
  CHOICE=$(whiptail --title "Raspberry Pi - LaserWeb4 Installer" --menu "Which kind of Pi do you have?" 30 78 5 \
"1)" "Raspberry Pi 1 - Model A/B" \
"2)" "Raspberry Pi 2 - Model B+/B+" \
"3)" "Raspberry Pi 3" \
"4)" "Compute Module" \
"5)" "Zero" 3>&2 2>&1 1>&3)

  case $CHOICE in
    "3)")
      PITYPE="3";;
    *)
      return;;
  esac
}

# We need sudo permissions for some things. Explain and ask for it
checkPermissions() {
  #Password Input
  PSW=$(whiptail --title "Sudo Required" --passwordbox "Enter your sudo password and choose Ok to continue." 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    #sudo -S <<< $PSW script.sh
    return
  else
    whiptail --title "Cancel" --msgbox "This script requires sudo permissions to install some programs." 10 60
    exit 1
  fi
}

progressBar() {
  declare TODO=("${@}")
  TITLE=("$TODO")
  NUM_TODO=${#TODO[*]}
  STEP=$((100/(NUM_TODO-1)))
  IDX=1
  COUNTER=0
  (
  while :
  do
    cat <<EOF
XXX
$COUNTER
${TODO[$IDX]}
XXX
EOF
    COMMAND="${TODO[$IDX]}"
    [[ $IDX -lt $NUM_TODO ]] && $COMMAND
    (( IDX+=1 ))
    (( COUNTER+=STEP ))
    [ $COUNTER -gt 100 ] && break
    sleep 1
  done
  ) |
  whiptail --title "${TITLE}" --gauge "Please wait..." 6 70 0
}


# ttyAMA0 => bluetooth on the Pi3, we need a real uart for the cnc hat to work reliably.
# See the link below if you want to know more.
# http://spellfoundry.com/2016/05/29/configuring-gpio-serial-port-raspbian-jessie-including-pi-3/
pi3Setup() {
  progressBar "Setup Pi3's Serial Ports"\
    "sudo cp /boot/config.txt /boot/config.txt-`date +%Y%m%d%H%M`.backup"\
    "sudo echo 'dtoverlay=pi3-miniuart-bt' >> /boot/config.txt"\
    "sudo echo 'enable_uart=1' >> /boot/config.txt"\
    "sudo systemctl disable hciuart >/dev/null 2>&1"\
    "sudo systemctl stop serial-getty@ttyS0.service >/dev/null 2>&1"\
    "sudo systemctl disable serial-getty@ttyS0.service >/dev/null 2>&1"
}

pi3Explain() {
  MSG="Pi3 specific system changes:

Out of the box ttyS0 => bluetooth via the hardware uart and
ttyAMA0 => GPIO using softwareSerial. We need high speed,
reliable comms with the CNC hat or gcodes may be dropped.
If you have modified your system and require high speed
bluetooth then stop now and do some research. More info at:

http://spellfoundry.com/2016/05/29/configuring-gpio-serial-port-raspbian-jessie-including-pi-3"
  if (whiptail --title "DISCLAIMER" --yesno "$MSG" 25 78) then
    return
  else
    exit -1
  fi
}

# Stop the console from outputting ot hardware serial pins
kernMsgDisable() {
  progressBar "Disabling kernel console messages"\
  "sudo cp /boot/cmdline.txt /boot/cmdline.txt-`date +%Y%m%d%H%M`.backup"\
  "sudo sed -i 's/ console=[^ ]*//' /boot/cmdline.txt"
}

ttyPermissions() {
  progressBar "Updating uDev rules for tty permissions"\
  "rm -f /etc/udev/rules.d/99-user-com.rules"\
  "echo '# /etc/udev/rules.d/99-my-com.rules' >> /etc/udev/rules.d/99-user-com.rules"\
  "echo '# These rules make the ttys accesable to the standard user, no sudo required' >> /etc/udev/rules.d/99-user-com.rules"\
  "echo "" >> /etc/udev/rules.d/99-user-com.rules"\
  "echo 'SUBSYSTEM=="tty", KERNEL=="ttyS0", GROUP:="users", MODE="0660"' >> /etc/udev/rules.d/99-user-com.rules"\
  "echo 'SUBSYSTEM=="tty", KERNEL=="ttyAMA0", GROUP:="users", MODE="0660"' >> /etc/udev/rules.d/99-user-com.rules"
}

restart() {
  if(whiptail --title "Setup Complete" --yesno "Restart required to finilize instilation, Reboot now?" 8 78) then
    shutdown -r now
  else
    exit 0
  fi
}
# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
#trap '' SIGINT SIGQUIT SIGTSTP

# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------
while true
do
  #checkPermissions

  # System setup
  choosePi
  if [ "$PITYPE" = "3" ]; then
    pi3Explain
    pi3Setup
  fi
  kernMsgDisable
  ttyPermissions

  restart
  exit 0
done

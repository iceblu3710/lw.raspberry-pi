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
pause(){
  echo ""
  read -p " Press [Enter] key to continue..." fackEnterKey
}

function backUp() {
  echo ""
  echo " Backing up "${1}"..."
  echo ""
  DIR=`dirname "${1}"`
  #pushd "${DIR}"
  cp "${1}" "${1}"-`date +%Y%m%d%H%M`.backup
  #popd
  pause
}

choosePi() {
  clear
  echo "--------------------------------------------------------------------------------"
  echo "                        Raspberry Pi - LaserWeb4 Installer "
  echo "--------------------------------------------------------------------------------"
  echo ""
  echo " Which kind of Pi do you have?"
  echo ""
  select option in "Pi 2" "Pi 3" "Quit"
  do
    case $option in
      "Pi 2")
        PITYPE="2" && break;;
      "Pi 3")
        PITYPE="3" && break;;
      Quit)
        exit 0;;
     esac
  done
}

# We need sudo permissions for some things. Explain and ask for it
checkPermissions() {
  echo ""
  if [[ $EUID -ne 0 ]]; then
   echo " This script must be run as root, use sudo "$0" instead" 1>&2
   exit 1
fi
}

# ttyAMA0 => bluetooth on the Pi3, we need a real uart for the cnc hat to work reliably.
# See the link below if you want to know more.
# http://spellfoundry.com/2016/05/29/configuring-gpio-serial-port-raspbian-jessie-including-pi-3/
pi3Setup() {
  echo ""
  echo " Setting up /dev/ttyAMA0 for GPIO serial config..."
  backUp "/boot/config.txt"
  echo 'dtoverlay=pi3-miniuart-bt' >> /boot/config.txt"
  echo 'enable_uart=1' >> /boot/config.txt"
  systemctl disable hciuart
  systemctl stop serial-getty@ttyS0.service
  systemctl disable serial-getty@ttyS0.service
  pause
}

pi3Explain() {
  clear
  echo "--------------------------------------------------------------------------------"
  echo "                                  DISCLAIMER"
  echo "--------------------------------------------------------------------------------"
  echo ""
  echo " Pi3 specific system changes:"
  echo ""
  echo " Out of the box ttyS0 => bluetooth via the hardware uart and ttyAMA0 => GPIO"
  echo " using softwareSerial. We need high speed, reliable comms with the CNC hat or"
  echo " gcodes will be dropped. If you have modified your system and require high speed"
  echo " bluetooth then stop now and do some research. More info at:"
  echo ""
  echo " http://spellfoundry.com/2016/05/29/configuring-gpio-serial-port-raspbian-jessie-including-pi-3/"
  echo ""
  select option in "Yes" "No"
  do
    case $option in
      "Yes")
        break;;
      "No")
        exit 0;;
     esac
  done
}

# Stop the console from outputting ot hardware serial pins
kernMsgDisable() {
  echo ""
  echo " Disabling kernel console messages..."
  #backUp "/boot/cmdline.txt"
  #sed -i 's/ console=[^ ]*//' /boot/cmdline.txt
  pause
}

ttyPermissions() {
  echo ""
  echo " Updating uDev rules for tty permissions..."
  rm -f /etc/udev/rules.d/99-user-com.rules
  echo '# /etc/udev/rules.d/99-my-com.rules' >> /etc/udev/rules.d/99-user-com.rules
  echo '# These rules make the ttys accesable to the standard user, no sudo required' >> /etc/udev/rules.d/99-user-com.rules
  echo "" >> /etc/udev/rules.d/99-user-com.rules
  echo 'SUBSYSTEM=="tty", KERNEL=="ttyS0", GROUP:="users", MODE="0660"' >> /etc/udev/rules.d/99-user-com.rules
  echo 'SUBSYSTEM=="tty", KERNEL=="ttyAMA0", GROUP:="users", MODE="0660"' >> /etc/udev/rules.d/99-user-com.rules
  pause
}

explainAvrdude() {
  clear
  echo "--------------------------------------------------------------------------------"
  echo "                            Pi CNC Hat - Avrdude"
  echo "--------------------------------------------------------------------------------"
  echo ""
  echo " If you are running a CNC hat with an Arduino connected directly to the GPIO"
  echo " then you will need to use a modified avedude script to toggle the DTR (Pin11)"
  echo " "
  echo " Avrdude is from:"
  echo " http://savannah.nongnu.org/projects/avrdude/"
  echo " Licensed under GNU GPL v2"
  echo ""
  echo " If you are using a CNC hat then agree, otherwise you can skip this step."
  echo ""
  select option in "Install" "Skip"
  do
    case $option in
      "Install")
        AVRDUDE="TRUE" && break;;
      "Skip")
        break;;
     esac
  done
}

installAvrdude() {
  echo ""
  echo " Installing avrdude and scripts..."
  mkdir /usr/local/share/avrdude-rpi
  cp "$SCRIPTDIR"/avrdude-rpi/autoreset2560 /usr/local/share/avrdude-rpi/autoreset2560
  cp "$SCRIPTDIR"/avrdude-rpi/autoreset328 /usr/local/share/avrdude-rpi/autoreset328
  cp "$SCRIPTDIR"/avrdude-rpi/avrdude-autoreset /usr/local/share/avrdude-rpi/avrdude-autoreset
  cp "$SCRIPTDIR"/avrdude-rpi/avrdude-original /usr/local/share/avrdude-rpi/avrdude-original
  cp "$SCRIPTDIR"/avrdude-rpi/avrdude.conf /usr/local/share/avrdude-rpi/avrdude.conf
  ln -s /usr/local/share/avrdude-rpi/avrdude-autoreset /usr/local/share/avrdude-rpi/avrdude

  chmod +x /usr/local/share/avrdude-rpi/avrdude
  chmod +x /usr/local/share/avrdude-rpi/autoreset328
  chmod +x /usr/local/share/avrdude-rpi/autoreset2560
  chmod +x /usr/local/share/avrdude-rpi/avrdude-original

  # Make AVRDUDE available for all
  sudo ln -s -T /usr/local/share/avrdude-rpi/avrdude /usr/local/bin/avrdude-rpi
  pause
}

updateFW() {
  echo ""
  echo " As you installed the Pi CNC hat avrdude would you like to upgrade your"
  echo " firmware to GRBL v1.1f? (Your settings will remain in EEPROM)"
  echo ""
  select option in "Yes" "No"
  do
    case $option in
      "Yes")
          avrdude-rpi -v -C /usr/local/share/avrdude-rpi/avrdude.conf -p atmega328p -P /dev/ttyAMA0 -b 115200 -c arduino -D Uflash:w:"$SCRIPTDIR"/GRBL-FW/grbl_v1.1f.20170131.hex:i;;
      "No")
        break;;
     esac
  done
  pause
}

updateSystem() {
  echo ""
  echo " Updating and installing required programs..."
  apt-get update
  apt-get install git
  pause
}

installNVM() {
  clear
  echo " Install Node Version Manager (NVM)..."
  echo ""
  wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | NVM_DIR=/usr/local/share/nvm bash
  echo 'export NVM_DIR="/usr/local/share/nvm"' >> /home/pi/.bashrc
  echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm'  >> /home/pi/.bashrc
  source ~/.bashrc
  nvm install node
  pause
}

installLW4() {
  clear
  echo " Installing LaserWeb4..."
  echo ""
  git clone https://github.com/iceblu3710/LaserWeb4.git /home/pi/LaserWeb4
  pushd /home/pi/LaserWeb4
  npm run-script installdev
  popd
  pause
}

restart() {
  clear
  echo ""
  echo " Restart required to finilize instilation."
  pause
  shutdown -r now
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
  checkPermissions

  # System setup
  choosePi
  if [ "$PITYPE" = "3" ]; then
    pi3Explain
    pi3Setup
  fi
  kernMsgDisable
  ttyPermissions

  # Programs
  explainAvrdude
  if [ "$AVRDUDE" = "TRUE" ]; then
    installAvrdude
    updateFW
  fi

  # Install utils
  updateSystem
  installNVM
  installLW4

  restart
  exit 0
done

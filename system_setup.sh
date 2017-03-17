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
  echo ""
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

# We need sudo permissions for some things. Explain and ask for it
checkPermissions() {
  echo ""
  if [[ $EUID -ne 0 ]]; then
   echo " This script must be run as root, use sudo "$0" instead" 1>&2
   exit 1
fi
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
          avrdude-rpi -v -C /usr/local/share/avrdude-rpi/avrdude.conf -p atmega328p -P /dev/ttyAMA0 -b 115200 -c arduino -D Uflash:w:"$SCRIPTDIR"/GRBL-FW/grbl_v1.1f.20170131.hex:i
          break;;
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

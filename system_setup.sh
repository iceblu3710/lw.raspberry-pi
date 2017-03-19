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
  if [[ $EUID -ne 0 ]]; then
    whiptail --title "Warning" --msgbox \
      "This script must be run as root, please use sudo "$0" instead." \
      8 78
    exit 1
  fi
}

systemSetup() {
  if (whiptail --title "Program Setup" --yesno \
      "This is an example of a yes/no box."\
       8 78) then
    echo "User selected Yes, exit status was $?."
  else
    echo "User selected No, exit status was $?."
  fi
  whiptail --title "Check list example" --checklist \
    "Choose user's permissions" 20 78 4 \
    "NET_OUTBOUND" "Allow connections to other hosts" ON \
    "NET_INBOUND" "Allow connections from other hosts" OFF \
    "LOCAL_MOUNT" "Allow mounting of local devices" OFF \
    "REMOTE_MOUNT" "Allow mounting of remote devices" OFF
}


explainAvrdude() {
MSG="If you are running a CNC hat with an Arduino connected directly to the GPIO then you will need to use a modified avedude script to toggle the DTR (Pin11)
  
Avrdude is from:
http://savannah.nongnu.org/projects/avrdude/
Licensed under GNU GPL v2
  
If you are using a CNC hat then agree, otherwise you can skip this step."
  
  if (whiptail --title "Pi CNC Hat - Avrdude" --yesno "${MSG}" 30 78)
  then
    AVRDUDE="TRUE"
  else
    AVRDUDE="FALSE"
  fi
}

installAvrdude() {
  echo ""
  echo " Installing avrdude and scripts..."
  mkdir /usr/local/share/avrdude-rpi
  sudo cp "$SCRIPTDIR"/avrdude-rpi/autoreset2560 /usr/local/share/avrdude-rpi/autoreset2560
  sudo cp "$SCRIPTDIR"/avrdude-rpi/autoreset328 /usr/local/share/avrdude-rpi/autoreset328
  sudo cp "$SCRIPTDIR"/avrdude-rpi/avrdude-autoreset /usr/local/share/avrdude-rpi/avrdude-autoreset
  sudo cp "$SCRIPTDIR"/avrdude-rpi/avrdude-original /usr/local/share/avrdude-rpi/avrdude-original
  sudo cp "$SCRIPTDIR"/avrdude-rpi/avrdude.conf /usr/local/share/avrdude-rpi/avrdude.conf
  sudo ln -s /usr/local/share/avrdude-rpi/avrdude-autoreset /usr/local/share/avrdude-rpi/avrdude

  sudo chmod +x /usr/local/share/avrdude-rpi/avrdude
  sudo chmod +x /usr/local/share/avrdude-rpi/autoreset328
  sudo chmod +x /usr/local/share/avrdude-rpi/autoreset2560
  sudo chmod +x /usr/local/share/avrdude-rpi/avrdude-original

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
  echo " Update and install required programs? (git)"
  echo ""
  select option in "Yes" "No"
  do
    case $option in
      "Yes")
        break;;
      "No")
        return;;
     esac
  done
  sudo apt-get update
  sudo apt-get install git
  pause
}

installNVM() {
  echo ""
  echo " Install Node Version Manager (NVM)?"
  echo ""
  select option in "Yes" "No"
  do
    case $option in
      "Yes")
        break;;
      "No")
        return;;
     esac
  done
  wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | NVM_DIR=/usr/local/share/nvm bash
  echo 'export NVM_DIR="/usr/local/share/nvm"' >> /home/pi/.bashrc
  echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm'  >> /home/pi/.bashrc
  source ~/.bashrc
  nvm install node
  pause
}

installLW4() {
  echo ""
  echo " Install LaserWeb4?"
  echo ""
  select option in "Yes" "No"
  do
    case $option in
      "Yes")
        break;;
      "No")
        return;;
     esac
  done
  git clone https://github.com/LaserWeb/LaserWeb4.git /home/pi/LaserWeb4
  pushd /home/pi/LaserWeb4
  npm run-script installdev
  popd
  cp start_server.sh /home/pi/LaserWeb4 
  pause
}

finalMessage() {
  echo ""
  echo " Done! You will need to log out and back in or 'source ~/.bashrc'"
  echo " before you can use node"
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

  exit 0
done

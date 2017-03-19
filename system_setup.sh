#!/bin/bash

## ----------------------------------
# Step #1: Define variables
# ----------------------------------
RED='\033[0;41;30m'
STD='\033[0;0;39m'

PITYPE="0"
AVRDUDE="FALSE"
SCRIPTDIR="$(dirname "${BASH_SOURCE[0]}")"
PSW="0"

# ----------------------------------
# Step #2: User defined function
# ----------------------------------

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
MSG="If you are running a CNC hat with an Arduino connected 
directly to the GPIO then you will need to use a modified 
avedude script to toggle the DTR (Pin11)

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

installAvrdude() {
  progressBar "Install avrdude-rpi"\
    "sudo mkdir /usr/local/share/avrdude-rpi"\
    "sudo cp "$SCRIPTDIR"/avrdude-rpi/autoreset2560 /usr/local/share/avrdude-rpi/autoreset2560"\
    "sudo cp "$SCRIPTDIR"/avrdude-rpi/autoreset328 /usr/local/share/avrdude-rpi/autoreset328"\
    "sudo cp "$SCRIPTDIR"/avrdude-rpi/avrdude-autoreset /usr/local/share/avrdude-rpi/avrdude-autoreset"\
    "sudo cp "$SCRIPTDIR"/avrdude-rpi/avrdude-original /usr/local/share/avrdude-rpi/avrdude-original"\
    "sudo cp "$SCRIPTDIR"/avrdude-rpi/avrdude.conf /usr/local/share/avrdude-rpi/avrdude.conf"\
    "sudo ln -s /usr/local/share/avrdude-rpi/avrdude-autoreset /usr/local/share/avrdude-rpi/avrdude"\
    "sudo chmod +x /usr/local/share/avrdude-rpi/avrdude"\
    "sudo chmod +x /usr/local/share/avrdude-rpi/autoreset328"\
    "sudo chmod +x /usr/local/share/avrdude-rpi/autoreset2560"\
    "sudo chmod +x /usr/local/share/avrdude-rpi/avrdude-original"\
    "sudo ln -s -T /usr/local/share/avrdude-rpi/avrdude /usr/local/bin/avrdude-rpi"
}

updateFW() {
  MSG="As you installed the Pi CNC hat avrdude would you like to upgrade your firmware to GRBL v1.1f? (Your settings will remain in EEPROM)"
  if (whiptail --title "Update GRBL" --yesno "$MSG" 10 78) then
    avrdude-rpi -v -C /usr/local/share/avrdude-rpi/avrdude.conf -p atmega328p -P /dev/ttyAMA0 -b 115200 -c arduino -D Uflash:w:"$SCRIPTDIR"/GRBL-FW/grbl_v1.1f.20170131.hex:i
  else
    return
  fi
}

updateSystem() {
  # WIP
  #installPKG "htop" "git"
  sudo apt-get -y install git
}

installPKG() {
pkg=0
# List packages here
aptitude -y install ${@} | \
    tr '[:upper:]' '[:lower:]' | \
while read x; do
    case $x in
        *upgraded*newly*)
            u=${x%% *}
            n=${x%% newly installed*}
            n=${n##*upgraded, }
            r=${x%% to remove*}
            r=${r##*installed, }
            pkgs=$((u*2+n*2+r))
            pkg=0
        ;;
        unpacking*|setting\ up*|removing*\ ...)
            if [ $pkgs -gt 0 ]; then
                pkg=$((pkg+1))
                x=${x%% (*}
                x=${x%% ...}
                x=$(echo ${x:0:1} | tr '[:lower:]' '[:upper:]')${x:1}
                printf "XXX\n$((pkg*100/pkgs))\n${x} ...\nXXX\n$((pkg*100/pkgs))\n"
            fi
        ;;
    esac
done | whiptail --title "Installing Packages" \
        --gauge "Preparing installation..." 7 70 0
}

installChoices() {
  # Create a temporary file and make sure it goes away when we're dome
  results=$(tempfile 2>/dev/null) || results=/tmp/test$$
  trap "rm -f $results" 0 1 2 5 15

  whiptail --title "Install Menu" --checklist "Choose what to install" 20 78 15 \
"Node" "Install NVM and the current stable version of Node" off \
"LW4" "Install LaserWeb 4" off 2>results

  while read choice
  do
    case $choice in
      Node)
        echo "Node"
        ;;
      LW4)
        echo "LW4"
        ;;
    esac
  done < results
}

installNVM() {
  MSG="Would you like to install the Node Version Manager (NVM) and install the latest stable version of Node.JS?"
  if (whiptail --title "Install - Node" --yesno "$MSG" 10 78) then
  sudo wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | NVM_DIR=/usr/local/share/nvm bash
  echo 'export NVM_DIR="/usr/local/share/nvm"' >> /home/pi/.bashrc
  echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm'  >> /home/pi/.bashrc
  sudo source ~/.bashrc
  sudo nvm install node
  else
    return
  fi
}

installLW4() {
  MSG="Would you like to install LaserWeb v4?"
  if (whiptail --title "Install - Node" --yesno "$MSG" 10 78) then
  git clone https://github.com/LaserWeb/LaserWeb4.git /home/pi/LaserWeb4
  pushd /home/pi/LaserWeb4
  npm run-script installdev
  popd
  cp start_server.sh /home/pi/LaserWeb4
  else
    return
  fi
}

lwNotice() {
MSG="When GRBL is connected directly to the Pi's GPIO serial
lines you will need to run LaserWeb via the supplied script.

cd /home/pi/LaserWeb4
./start_server.sh"

  whiptail --title "Example Dialog" --msgbox "${MSG}" 8 78
}

finalMessage() {
  MSG="Done! You will need to log out and back in or 'source ~/.bashrc' before you can use node"
  whiptail --title "Example Dialog" --msgbox "$MSG" 8 78
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
#  checkPermissions

  # Programs
  explainAvrdude
  if [ "$AVRDUDE" = "TRUE" ]; then
    installAvrdude
    updateFW
  fi

  # Install utils
  updateSystem
#  installChoices
  installNVM
  installLW4
  if [ "$AVRDUDE" = "TRUE" ]; then
    lwNotice
  fi

  finalMessage
  exit 0
done


#!/bin/bash

if [ ${1} ]; then
  avrdude-rpi -v -C /usr/local/share/avrdude-rpi/avrdude.conf -p atmega328p -P /dev/ttyAMA0 -b 115200 -c arduino -D Uflash:w:"${1}":i
else
  echo ""
  echo "Please provide the firmware file you want to upload, eg:"
  echo "grbl_update.sh ./GRBL-FW/grbl_v1.1f.20170131.hex"
  exit 1;
fi
exit 0;

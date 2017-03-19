#!/bin/bash
# Copyright (c) 2016 Trevor Johansen Aase
#
# The MIT License (MIT)
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Useage:
#   ./start_server.sh
#   ./start_server.sh /dev/YOUR-TTY
#   ./start_server.sh /dev/YOUR-TTY HEADLESS

# Setup the default serial device
TTY=${1:-/dev/ttyAMA0}
HEADLESS=${2:-FALSE}

initMenu() {
  clear
  echo "--------------------------------------------------------------------------------"
  echo "                          LaserWeb4 - Pi Launcher "
  echo "--------------------------------------------------------------------------------"
  echo ""
  echo " Monitoring tty: $TTY"
  echo ""
  select option in "Server & App" "Server Only" "Exit"
  do
    case $option in
      "Server & App")
        startApp
        startServer
        break;;
      "Server Only")
        HEADLESS="TRUE"
        startServer
        break;;
      "Exit")
        exit 0;;
     esac
  done
}

function trigger {
  echo "Firing reset trigger to $TTY !"
  echo -n $'\cx' > $TTY
}

startServer() {
  echo "Starting LaserWeb4 Comms Server..."
  npm run-script start-server | tee /tmp/lw.stdout.log &

  while true
  do
    tail -f /tmp/lw.stdout.log | grep -q --line-buffered "INFO: Connecting to USB,$TTY" && trigger
    sleep 2
  done
}

startApp() {
  echo "Starting LaserWeb4 web app..."
  npm run-script start-app &
}

# Main program loop
while true
do
  if [ "$HEADLESS" != "FALSE" ]; then
    startServer
  fi

  initMenu

  exit 0
done

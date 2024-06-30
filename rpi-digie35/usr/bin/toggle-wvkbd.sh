#!/bin/bash
#This script toggle the virtual keyboard
#
# this file is in /usr/bin/toggle-wvkbd.sh
#
PID="$(pidof wvkbd-mobintl)"
if [  "$PID" != ""  ]; then
  killall wvkbd-mobintl
else
 wvkbd-mobintl -L 300 -fg ffffff -fg-sp ffffff --text 000000 --text-sp 000000 -fn 40
# use wvkbd-mobintl --help for options
# my options:
# -L 300 = landscape, 300 pixels tall
# -fg ffffff = foreground color white
# -fg-sp ffffff = special keys foreground white
# -text 000000 = text color black
# -text-sp 000000 = special keys text color black
# -fn 40 = font size 40


fi

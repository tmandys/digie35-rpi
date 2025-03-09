#!/bin/sh

# Patch file provided as the first argument. Intended as fake editor for raspi-eeprom-config
CONFIG=$1
if [ ! -f $CONFIG ]; then
    echo "Config file not provided as argument"
    exit 1
fi


do_update() {
    name=$1
    value=$2
    echo "Patching $1=$2"
    if ! grep -q "$name=" $CONFIG ; then
      sed $CONFIG -i -e "\$$name=$value\n"
    else
      sed $CONFIG -i -e "s/^.*$name=.*/$name=$value/"
    fi
}

echo "Config file: $CONFIG"
do_update BOOT_ORDER 0xf461
do_update PSU_MAX_CURRENT 4000

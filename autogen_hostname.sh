#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

# Report usage
usage() {
    echo "Generates and sets hostname based on wlan0 MAC address"
    echo ""
    echo "Usage: $(basename "$0")"
    echo ""
}

# make sure we're running this on the node and not on our workstation
# use MAC address of wlan0 to verify
# see: https://macaddress.io/statistics/company/22305
mac=$(cat /sys/class/net/wlan0/address)
[[ $(echo $mac | grep -o ^........ | grep -i "B8:27:EB") ]] || die "Please run this on a RPi node, not anywhere else."

# change hostname
echo ""
echo "Changing hostname ..."
cur_hostname=$(cat /etc/hostname)
echo "  -> old: $cur_hostname"
suffix=$(echo $mac | sed 's/://g' | grep -o ......$)
new_hostname="uav-$suffix"
# let's make sure it is changed:
sudo hostnamectl set-hostname $new_hostname
sudo hostname $new_hostname
sudo sed -i "s/^\(127\.0\.1\.1\s*\).*/\1$new_hostname/g" /etc/hosts
sudo sed -i "s/^\(127\.0\.0\.1\s*\).*/\1$new_hostname/g" /etc/hosts
echo "  -> changed to $new_hostname"

echo ""
echo "Hostname changed to $new_hostname. We should probably reboot."
read -s -n 1 -p "Press any key to reboot"
echo ""
sudo reboot
#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

usage() {
    echo "Sets up mesh networking on a modified RPi OS host"
    echo ""
    echo "Usage: $(basename "$0")"
    echo ""
    echo "  -h|--help           show this message"
    echo ""
}

die() {
    printf "ERROR: Script failed: %s\n\n" "$1" >&2
    cd "$pwd"
    exit 1
}

pwd=$(pwd)

# check for all mandatory directories and files
dirs_exist="networking"
files_exist="networking/bat0 networking/wlan0 start-batman-adv.sh"
for dir in $dirs_exist; do
    [[ -d "$dir" ]] || die "directory '$dir' not found"
done
for file in $files_exist; do
    [[ -f "$file" ]] || die "file '$file' not found"
done

# make sure we're running this on the node and not on our workstation
# use MAC address of wlan0 to verify
# see: https://macaddress.io/statistics/company/22305
mac=$(cat /sys/class/net/wlan0/address)
[[ $(echo $mac | grep -o ^........ | grep -i "B8:27:EB") ]] || die "Please run this on a RPi node, not anywhere else."


# copy files
echo ""
echo "Copy networking files ..."
cd networking
sudo cp -v wlan0 /etc/network/interfaces.d/
sudo cp -v bat0 /etc/network/interfaces.d/
cd ..

# Have batman-adv startup automatically on boot
echo ""
echo "Setting up batman-adv ..."
echo 'batman-adv' | sudo tee --append /etc/modules
echo 'denyinterfaces wlan0' | sudo tee --append /etc/dhcpcd.conf
echo "$(pwd)/start-batman-adv.sh" >> ~/.bashrc


# change hostname
echo ""
echo "Changing hostname ..."
cur_hostname=$(cat /etc/hostname)
suffix=$(echo $mac | sed 's/://g' | grep -o ......$)
new_hostname="uav-$suffix"
# let's make sure it is changed:
sudo hostnamectl set-hostname $new_hostname
sudo hostname $new_hostname
# sudo sed -i "s/$cur_hostname/$new_hostname/g" /etc/hosts
sudo sed -i "s/^\(127\.0\.1\.1\s*\)\w*/\1$new_hostname/g" /etc/hosts
# sudo sed -i "s/$cur_hostname/$new_hostname/g" /etc/hostname
sudo echo "$new_hostname" > /etc/hostname
echo "  -> changed to $new_hostname"

echo ""
echo "Mesh setup is done. This machine will now reboot and lose connectivity to any"
echo "wifi network previously defined. Good luck!"


read -s -n 1 -p "Press any key to reboot"
echo ""
sudo reboot
#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

usage() {
    echo "Sets up all software requirements on a modified RPi OS host"
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

# make sure we're running this on the node so we won't seriously mess up our workstation
# use MAC address of wlan0 to verify
# see: https://macaddress.io/statistics/company/22305
mac=$(cat /sys/class/net/wlan0/address)
[[ $(echo $mac | grep -o ^........ | grep -i "B8:27:EB") ]] || die "Please run this on a RPi node, not anywhere else."


# check for all mandatory directories and files
dirs_exist="networking"
files_exist="networking/bat0 networking/wlan0 networking/start-batman-adv.sh"
for dir in $dirs_exist; do
    [[ -d "$dir" ]] || die "directory '$dir' not found"
done
for file in $files_exist; do
    [[ -f "$file" ]] || die "file '$file' not found"
done

username=$(whoami)
cur_group=$(id -gn)
sudo chown -R $username:$cur_group .

echo ""
echo "Copying start script ..."
cp -v networking/start-batman-adv.sh .


# install software
echo ""
echo "Checking for network connectivity ..."
nc -z -w 2 8.8.8.8 53 >/dev/null 2>&1
online=$?
if [[ online -eq 0 ]]; then
    echo "Updating system and installing software ..."
    sudo apt update
    sudo apt -y upgrade
    sudo apt -y install batctl
else
    die "no network connection, please check network configuration"
fi


echo ""
echo "Setup finished, you can now run the setup_mesh.sh script."

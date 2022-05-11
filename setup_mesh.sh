#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

usage() {
    echo "Sets up mesh networking on a modified RPi OS host"
    echo ""
    echo "Usage: $(basename "$0")"
    echo ""
    echo "  -a | --ap-mode          setup this node as an access point"
    echo "  -h | --help             show this message"
    echo ""
}

die() {
    printf "ERROR: Script failed: %s\n\n" "$1" >&2
    cd "$pwd"
    exit 1
}

pwd=$(pwd)

is_ap=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--ap-mode)   is_ap="yes" ;;
        -h|--help)      usage; exit 0 ;;
        *)              die "Unkown parameter $1"
    esac
    shift
done



# check for all mandatory directories and files
dirs_exist="networking"
files_exist="networking/wlan0 start-batman-adv.sh"
if [[ -n "$is_ap" ]]; then
    files_exist="$files_exist networking/hostapd.conf networking/routed-ap.conf"
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
sudo cp -v networking/wlan0 /etc/network/interfaces.d/


# Have batman-adv startup automatically on boot
echo ""
echo "Setting up batman-adv ..."
echo 'batman-adv' | sudo tee --append /etc/modules
echo 'denyinterfaces wlan0 eth0' | sudo tee --append /etc/dhcpcd.conf

echo "$(pwd)/start-batman-adv.sh" >> ~/.bashrc


# Set up the AP on one RPi
if [[ -n "$is_ap" ]]; then
    echo ""
    echo "Setting up access point config ..."
    sudo cp -v networking/hostapd.conf /etc/hostapd/hostapd.conf
    cat << EOL | sudo tee -a /etc/dhcpcd.conf
interface wlan1
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOL

    sudo cp -v networking/routed-ap.conf /etc/sysctl.d/routed-ap.conf
    sudo iptables -t nat -A POSTROUTING -o bat0 -j MASQUERADE
    sudo netfilter-persistent save

    cat << EOL | sudo tee -a /etc/dnsmasq.conf
interface=wlan1
dhcp-range=192.168.4.2,192.168.4.200,255.255.255.0,24h
domain=wlan
address=/gw.wlan/192.168.4.1
EOL

    echo "Unmasking and restarting hostapd ..."
    sudo systemctl unmask hostapd
    sudo systemctl enable hostapd

    sudo rfkill unblock wlan
fi


# change hostname
echo ""
echo "Changing hostname ..."
cur_hostname=$(cat /etc/hostname)
suffix=$(echo $mac | sed 's/://g' | grep -o ......$)
new_hostname="uav-$suffix"
# let's make sure it is changed:
sudo hostnamectl set-hostname $new_hostname
sudo hostname $new_hostname
sudo sed -i "s/^\(127\.0\.1\.1\s*\).*/\1$new_hostname/g" /etc/hosts
sudo sed -i "s/^\(127\.0\.0\.1\s*\).*/\1$new_hostname/g" /etc/hosts
echo "  -> changed to $new_hostname"

echo ""
echo "Mesh setup is done. This machine will now reboot and lose any"
echo "previously defined wifi connectivity."
echo "Good luck!"


read -s -n 1 -p "Press any key to reboot"
echo ""
sudo systemctl reboot

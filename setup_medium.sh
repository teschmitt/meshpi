#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

pwd=$(pwd)

# Report usage
usage() {
    echo "Modifies a vanilla Raspberry Pi OS installation medium with configuration"
    echo "and setup files for the UAVPi project"
    echo ""
    echo "Usage: $(basename "$0") --bootfs PATH --rootfs PATH"
    echo ""
    echo "  -b | --bootfs PATH      path to the boot filesystem on the mounted installation medium"
    echo "  -r | --rootfs PATH      path to the rootfs filesystem on the mounted installation medium"
    echo "  -h | --help             show this message"
    echo ""
}

skipping() {
    echo "  -> File/directory $1 not found, skipping"
}

invalid() {
  echo "ERROR: Unrecognized argument: $1" >&2
  usage
  exit 1
}

die() {
    printf "ERROR: Script failed: %s\n\n" "$1" >&2
    cd "$pwd"
    exit 1
}


if [[ "$#" -eq 0 ]]; then
    usage; exit 1
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--bootfs)    shift; fs_boot="$1" ;;
        -r|--rootfs)    shift; fs_root="$1" ;;
        -h|--help)      usage; exit 0 ;;
        *)              die "Unkown parameter $1"
    esac
    shift
done

if [[ -z $fs_boot ]]; then
    usage
    die "Missing parameter --bootfs"
elif [[ -z $fs_root ]]; then
    usage
    die "Missing parameter --rootfs"
fi

# check for all mandatory directories and files
echo ""
echo "Checking if all necessary directories and files are accessible ..."
dirs_exist="pi_config dtn7-rs-release networking"
files_exist="
    setup_host.sh setup_mesh.sh
    pi_config/userconf
    dtn7-rs-release/dtnd dtn7-rs-release/dtnquery dtn7-rs-release/dtnsend dtn7-rs-release/dtnrecv dtn7-rs-release/dtntrigger
    networking/hostapd.conf networking/routed-ap.conf networking/wlan0 networking/start-batman-adv.sh"
x_flag="setup_host.sh setup_mesh.sh networking/start-batman-adv.sh"
for dir in $dirs_exist; do
    [[ -d "$dir" ]] || die "directory '$dir' not found"
done
for file in $files_exist; do
    [[ -f "$file" ]] || die "file '$file' not found"
done
for file in $x_flag; do
    [[ -x "$file" ]] || die "file '$file' must have execute permissions"
done
echo "  -> Success!"

usrbin="$fs_root/usr/bin"

echo ""
echo "Copying config files to $fs_boot ..."
cd pi_config
cp -v userconf "$fs_boot"
[[ -f ssh ]]            && cp -v ssh "$fs_boot"         || skipping "ssh"
[[ -f config.txt ]]     && cp -v config.txt "$fs_boot"  || skipping "config.txt"
[[ -f wpa_supplicant.conf ]]&& cp -v wpa_supplicant.conf "$fs_boot"|| skipping "wpa_supplicant.conf"


echo "Parsing username from userconf ..."
pi_username=$(sed -nr '1s/^([^:]+).*/\1/p' userconf)
[[ -n "$pi_username" ]] || die "Was not able to parse username in userconf"
echo "  -> got '$pi_username'"
cd ..


echo ""
echo "Copying DTN7 application files to $usrbin ..."
cd dtn7-rs-release
sudo cp -v dtnd "$usrbin"
sudo cp -v dtnquery "$usrbin"
sudo cp -v dtnrecv "$usrbin"
sudo cp -v dtnsend "$usrbin"
sudo cp -v dtntrigger "$usrbin"
cd ..


echo ""
echo "Switching keyboard layout to 'de' ..."
[[ -f pi_config/keyboard ]] && sudo cp -v pi_config/keyboard "$fs_root/etc/default/keyboard" || skipping "keyboard"


echo ""
echo "Copying files for self-hosted setup into user directory"
userdir="$fs_root/home/$pi_username"
local_username=$(whoami)
cur_group=$(id -gn)
sudo mkdir "$userdir"
sudo chown $local_username:$cur_group "$userdir"
cp -Rv networking "$userdir"
cp -v setup_host.sh "$userdir"
cp -v setup_mesh.sh "$userdir"
[[ -f autogen_hostname.sh ]] && cp -v autogen_hostname.sh "$userdir" || skipping "autogen_hostname.sh"
[[ -f show_network_drivers.sh ]] && cp -v show_network_drivers.sh "$userdir" || skipping "show_network_drivers.sh"

echo ""
echo "Copying user dotfiles into user directory"
if [[ -d "dotfiles" ]]
then
    cd dotfiles
    cp -v .bash_logout "$userdir"
    cp -v .bashrc "$userdir"
    cp -v .profile "$userdir"
else
    skipping "dotfiles"
fi
cd ..


echo ""
cd "$pwd"
echo "Setup finished, you can now unmount the partitions and boot up the Pi."
echo "Then run the setup_host.sh script in the /home/$pi_username directory."
echo "Have a fantastic day!"

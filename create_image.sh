#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

# Report usage
usage() {
    echo "Creates and shrinks an image from a mounted filesystem"
    echo ""
    echo "Usage: $(basename "$0") PATH_TO_SDCARD IMAGE_NAME"
    echo ""
}

die() {
    printf "ERROR: Script failed: %s\n\n" "$1" >&2
    cd "$pwd"
    exit 1
}


if [[ ! "$#" -eq 2 ]]; then
    usage; exit 1
fi

# check for all mandatory directories and files
dirs_exist="PiShrink"
files_exist="PiShrink/pishrink.sh"
for dir in $dirs_exist; do
    [[ -d "$dir" ]] || die "directory '$dir' not found"
done
for file in $files_exist; do
    [[ -f "$file" ]] || die "file '$file' not found"
done

sdcard_path=$1
image_name=$2

echo ""
echo "Creating image (this could take a while) ..."
sudo dd if="$sdcard_path" of="$image_name" bs=4M conv=fsync status=progress

echo ""
echo "Shrinking image ..."
sudo PiShrink/pishrink.sh "$image_name"

echo ""
echo "Fixing permissions ..."
username=$(whoami)
cur_group=$(id -gn)
sudo chown $username:$cur_group "$image_name"

echo ""
echo "Success!"
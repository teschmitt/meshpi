#!/bin/bash

# Show drivers for all connected network devices.
# Source: https://unix.stackexchange.com/a/225496

for f in /sys/class/net/*; do
    dev=$(basename $f)
    driver=$(readlink $f/device/driver/module)
    if [ $driver ]; then
        driver=$(basename $driver)
    fi
    addr=$(cat $f/address)
    operstate=$(cat $f/operstate)
    printf "%10s [%s]: %10s (%s)\n" "$dev" "$addr" "$driver" "$operstate"
done

# UAVPi Distro Image Build (WIP)

This is an early, early version of an image build for a Raspberry Pi Zero. Purpose of this image is to build a mesh network with other UAV-enabled Pis and supply an access point to outside devices in order to relay data using a disruption-tolerant networking implementations of the Bundle Protocol 7.

Steps to replicate image:


## Set up Zero W

1. Download Distro from https://www.raspberrypi.com/software/operating-systems/
2. `sha256sum` it

#### Burn image

```shell
$ xzcat 2022-04-04-raspios-bullseye-armhf-lite.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

mount it

### Set up SSH and Wifi

1. `cd /QQQ/boot/`
2. `touch ssh`
3. Enable Wifi like here: https://code.mendhak.com/prepare-raspberry-pi/

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE

network={
     ssid="QQQQ"
     psk="QQQQ"
     key_mgmt=WPA-PSK
}
```

**New way to enable SSH**: Create default user and password:
https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/

```shell
$ openssl passwd -6
$ [ ... enter password ...]
```

then copy output to `userconf`:

```
username:$6$PASSWORDHASH
```

**Note: look into the `pi_config` directory for samples and ready to use configs.


### Todo: Change hostname
like [here](https://raspberrypi.stackexchange.com/a/114629)
with a script

umount and log in with ssh.


## Cross build DTNd (Rust implementation)

Install `cross` with favorite package manager
then clone repo

```shell
$ git clone git@github.com:dtn7/dtn7-rs.git
```

`cd` in there and build it:

```shell
$ cross build --release --target arm-unknown-linux-gnueabi
```

get the bins from `./target/arm-unknown-linux-gnueabi/release` and `scp` them to the node.

Wonder in awe at the 123 MB the `dtnd` now occupies.


## More software
on all nodes:
- DTNd

gateway:
- dnsmasq


## Mesh stuff
https://www.iottrends.tech/blog/diy-how-to-create-a-home-mesh-wifi-using-raspberry-pi/
https://www.open-mesh.org/projects/batman-adv/wiki

Nice docs:
https://www.open-mesh.org/doc/batman-adv/index.html

How to use the `batctl` tool:
https://www.open-mesh.org/doc/batman-adv/Understand-your-batman-adv-network.html


## B.A.T.M.A.N. Advanced setup

Follow these tutorials:
1. https://github.com/binnes/WiFiMeshRaspberryPi or
2. https://medium.com/@tdoll/how-to-setup-a-raspberry-pi-ad-hoc-network-using-batman-adv-on-raspbian-stretch-lite-dce6eb896687

or there's one on the official `batman-adv` pages especially for Debian:
https://www.open-mesh.org/doc/batman-adv/Debian_batman-adv_AutoStartup.html

basically:

```shell
$ sudo apt install -y batctl
$ cd ~ && touch start-batman-adv.sh && chmod +x start-batman-adv.sh
$ nano start-batman-adv.sh
```

the contents should be:

```bash
#!/bin/bash
# batman-adv interface to use
sudo batctl if add wlan0
# sudo ifconfig bat0 mtu 1468

# Tell batman-adv this is a gateway client
# sudo batctl gw_mode client

# Activates batman-adv interfaces
sudo ifconfig wlan0 up
sudo ifconfig bat0 up
```

then:

```shell
$ sudo touch /etc/network/interfaces.d/wlan0
$ sudo touch /etc/network/interfaces.d/bat0
```

with content:

```
auto wlan0
iface wlan0 inet manual
    mtu 1532 # Increase packet size to account for batman-adv header
    wireless-channel 1 # Any channel from 1-14
    wireless-essid my-ad-hoc-network # Your network name here
    wireless-mode ad-hoc
    wireless-ap 02:12:34:56:78:9A # This pre-sets your CELL id
```

and

```
auto bat0
iface bat0 inet auto
    pre-up /usr/sbin/batctl if add wlan0
```

Finally:

```shell
# Have batman-adv startup automatically on boot
$ echo 'batman-adv' | sudo tee --append /etc/modules# Prevent DHCPCD from automatically configuring wlan0, THIS IS KEY
$ echo 'denyinterfaces wlan0' | sudo tee --append /etc/dhcpcd.conf# Enable interfaces on boot
$ echo "$(pwd)/start-batman-adv.sh" >> ~/.bashrc
```

### Create one entry point node (EPN)
https://www.open-mesh.org/doc/batman-adv/Quick-start-guide.html#mixing-non-b-a-t-m-a-n-systems-with-batman-adv

### Create and shrink the image
https://opensource.com/article/21/7/custom-raspberry-pi-image
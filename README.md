# UAVPi image build workflow

### Prerequisites
Building a deployable UAVPi image is aided by the scripts and pre-defined config files in this repository. There are a few prerequesites for starting this workflow:

1. Download a suitable vanilla Raspi OS image, e.g. [2022-04-04-raspios-bullseye-armhf-lite](https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-04-07/2022-04-04-raspios-bullseye-armhf-lite.img.xz.torrent)
2. Flash that image to an SD card like so:

```shell
$ xzcat 2022-04-04-raspios-bullseye-armhf-lite.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

3. Then clone this repository

```shell
$ git clone git@github.com:teschmitt/UAVPi.git
$ cd UAVPi
```

4. Edit `pi_config/userconf_sample` in order to set up a custom default user. Generate the password hash with

```shell
$ openssl passwd -6
  [ ... enter password ...]
```

then save the output to `pi_config/userconf`:

```
<username>:<PASSWORDHASH>
```

5. The self-hosted setup steps require a wifi connection, so edit `wpa_supplicant.conf_sample` and remove the suffix.
6. If you want to connect to the Pi via SSH, remove the suffix from `ssh_sample`. These will be copied to the `boot` partition and will be read out automagically on the Pi's first startup.
7. `./setup_medium.sh` expects the DTN7 binaries (from the [Rust implementation](https://github.com/dtn7/dtn7-rs)) to be in a sub-directory called `dtn7-rs-release`. So please compile them with `cross build --release --target arm-unknown-linux-gnueabi` and place them there.
8. Go and tell the `cross` maintainers what absolute MVPs they are. I'll wait.

The above steps will normally only have to be done once, then you have a working environment for the following workflow.

## Install medium setup
If everything went well, you should have two partitions mounted and it should look something like this:

```shell
$ lsblk
...
sdX      8:16   1  59,5G  0 disk
├─sdX1   8:17   1   256M  0 part /run/media/<username>/boot
└─sdX2   8:18   1   1,7G  0 part /run/media/<username>/rootfs
```

You can then launch the script to copy all files needed for the self-hosted setup with the details from above:

```shell
$ ./setup_medium.sh --bootfs /run/media/<username>/boot --rootfs /run/media/<username>/rootfs
```

Since we're copying the DTN7 stuff into system directories, you will need to plug in your root password along the way. Don't forget to `umount` the partitions. You can now boot up the Pi (and connect to it via ssh, if you provided the adequate credentials above).

In order to install all needed software, run

```shell
$ ./setup_host.sh
```

This requires an internet connection and may take a while. When it's done you should see

```
Setup finished, you can now run the setup_mesh.sh script.
```

So do that:

```shell
$ ./setup_mesh.sh
```

This will actually muck around in the network configurations and set up all interfaces needed by `batman-adv`. If you want to change any of the used options, check the `networking` directory for the appropriate files.

## Create and shrink an image
Now for the most important part, creating the image:

1. Power down the Pi and remove the SD card. Mount it on the workstation
2. Find out the device ID like above
3. Fire up the `create_image.sh` script (this will also require your `sudo` credentials, so have those handy):

```shell
$ ./create_image.sh /dev/sdX imagename.img
```

This will take a while, but you'll have a ready to deploy image when it's done.

## On hostnames
The `setup_mesh.sh` script will generate a hostname based on the MAC address of the `wlan0` interface and write this hostname to `/etc/hosts` and `/etc/hostname`. The image you create will have this hostname hard-coded into it. If you want something more generic you will have to alter the appropriate files before ripping the image.

To auto-generate and set a hostname with the schema `uav-<last 6 MAC addr digits w/o colons>`, simply run the `autogen_hostname.sh` script.

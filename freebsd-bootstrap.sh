#!/bin/sh
set -e

# Download: curl -LO https://bit.ly/freebsd-bootstrap

# References
#
# https://cooltrainer.org/a-freebsd-desktop-howto/
# https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/x11-wm.html
# TrueOS Desktop install July 2017

# Util functions

show_help() {
  cat << EOT
usage: freebsd-bootstrap.sh [--gnome][--xfce][--vbox]|[--help]

--gnome
  Install Gnome 3

--xfce
  Install XFCE

--vbox
  Include VirtualBox additions and config

--help
  This help
EOT
}

# write_to_file "string" filename
write_to_file () {
  printf "$1\n" >> $2
}

# Globals

VERSION="0.1"
GNOME=false
XFCE=false
VBOX=false

while :; do
  case $1 in
    -h|-\?|--help)
        show_help
        exit
        ;;
    --gnome)
        echo "Installing Gnome 3"
        GNOME=true
        ;;
    --xfce)
        echo "Installing XFCE"
        XFCE=true
        ;;
    --vbox)
        echo "Using VirtualBox configuration"
        VBOX=true
        ;;
    --) # End of all options.
        shift
        break
        ;;
    -?*)
        printf 'Unknown option (ignored): %s\n' "$1" >&2
        ;;
    *) # Default case: No more options, so break out of the loop.
        break
  esac

  shift
done

if [ `whoami` != 'root' ]; then
  printf "Please run as root"
  exit
fi

# Interactive system update
read -p "Do you want to check for and install system updates? [y/N]: " answer
case $answer in
  [Yy]*)
    freebsd-update fetch install
    printf "\nPlease reboot then re-run this script to continue...\n"
    exit
    ;;
esac

CURRENT_USER=`logname`

pw usermod "$CURRENT_USER" -G wheel,operator,video

kldload linux64

# Packages
pkg update
pkg upgrade -y

pkg install -y \
  cuse4bsd-kmod \
  elasticsearch5 \
  emacs25 \
  git \
  htop \
  ImageMagick7-nox11 \
  linux-c7 \
  memcached \
  node \
  postgresql96-server postgresql96-client postgresql96-contrib \
  qt5-webkit qt5-qmake qt5-buildtools \
  rabbitmq \
  rbenv \
  redis \
  ruby-build \
  sudo \
  tmux \
  xorg \

# Install minimum linux compatibility for Sublime Text
# Swap for linux-c7 from above
# pkg install -y \
#   linux_base-c7 \
#   linux-c7-xorg-libs \
#   linux-c7-cairo linux-c7-gdk-pixbuf2 linux-c7-glx-utils linux-c7-gtk2

# Install Sublime Text 3
currdir=`pwd`
cd /tmp
curl -O https://download.sublimetext.com/files/sublime-text-3143-1.x86_64.rpm
cd /compat/linux/
rpm2cpio < /tmp/sublime-text-3143-1.x86_64.rpm | cpio -id
cd $currdir

# Setup PostgreSQL
/usr/local/etc/rc.d/postgresql oneinitdb
service postgresql onestart
sudo -u postgres createuser -s `logname`
sudo -u postgres createdb `logname`

# Configuration files

# /boot/loader.conf
# use kldstat -v | grep <name> to check what is already loaded
write_to_file '
# Boot-time kernel tuning
kern.ipc.shmseg=1024
kern.ipc.shmmni=1024
kern.maxproc=100000

# Tune ZFS Arc Size - Change to adjust memory used for disk cache
vfs.zfs.arc_max="256M"

# Enable Wellspring touchpad driver (for Apple Internal Trackpad)
wsp_load="YES"

# Filesystems in Userspace
fuse_load="YES"

# Intel Core thermal sensors
# coretemp_load="YES"

# AMD K8, K10, K11 thermal sensors
# amdtemp_load="YES"

# In-memory filesystems
tmpfs_load="YES"

# Enable sound
snd_driver_load="YES"

# Handle Unicode on removable media
libiconv_load="YES"
libmchain_load="YES"
cd9660_iconv_load="YES"
msdosfs_iconv_load="YES"

# Userland character device driver for webcams
cuse4bsd_load="YES"
' /boot/loader.conf

# /etc/rc.conf
# use sudo service <name> onestatus to check what is already running
write_to_file '
# Disable mouse
moused_enable="NO"

# Enable BlueTooth
hcsecd_enable="YES"
sdpd_enable="YES"

# Synchronize system time
ntpd_enable="YES"
# Let ntpd make time jumps larger than 1000sec
ntpd_flags="-g"

# Enable webcam
webcamd_enable="YES"

# Enable linux compatibility
linux_enable="YES"

# Enable our custom device ruleset
devfs_system_ruleset="devfsrules_common"

# Enable services for Gnome etc
avahi_daemon_enable="YES"
dbus_enable="YES"
hald_enable="YES"

# Start databases
postgresql_enable="NO"
elasticsearch_enable="NO"
redis_enable="NO"
rabbitmq_enable="NO"
memcached_enable="NO"
' /etc/rc.conf

# /etc/sysctl.conf
write_to_file '
# Enhance shared memory X11 interface
kern.ipc.shmmax=67108864
kern.ipc.shmall=32768

# Enhance desktop responsiveness under high CPU use (200/224)
kern.sched.preempt_thresh=224

# Bump up maximum number of open files
kern.maxfiles=200000

# Enable shared memory for Chromium
kern.ipc.shm_allow_removed=1

# Allow users to mount disks
vfs.usermount=1

# Do not hang on shutdown when using USB disks
hw.usb.no_shutdown_wait=1

# Disable the system bell
kern.vt.enable_bell=0 # FreeBSD > 11
hw.syscons.bell=0
# Select first sound card
hw.snd.default_unit=0
# Autodetect the most recent sound card. Uncomment for Digital output / USB
# hw.snd.default_auto=1
' /etc/sysctl.conf

# /etc/fstab
write_to_file '
proc  /proc   procfs  rw  0 0
fdesc /dev/fd fdescfs rw,auto,late  0 0
' /etc/fstab

# /etc/devfs.conf
write_to_file '
# Allow all users to access optical media
perm    /dev/acd0       0666
perm    /dev/acd1       0666
perm    /dev/cd0        0666
perm    /dev/cd1        0666

# Allow all USB Devices to be mounted
perm    /dev/da0        0666
perm    /dev/da1        0666
perm    /dev/da2        0666
perm    /dev/da3        0666
perm    /dev/da4        0666
perm    /dev/da5        0666

# Misc other devices
perm    /dev/pass0      0666
perm    /dev/xpt0       0666
perm    /dev/uscanner0  0666
perm    /dev/video0     0666
perm    /dev/tuner0     0666
perm    /dev/dvb/adapter0/demux0    0666
perm    /dev/dvb/adapter0/dvr       0666
perm    /dev/dvb/adapter0/frontend0 0666
' /etc/devfs.conf

# /etc/devfs.rules
write_to_file "
[devfsrules_common=7]
add path 'ad[0-9]\*'    mode 666
add path 'ada[0-9]\*' mode 666
add path 'da[0-9]\*'    mode 666
add path 'acd[0-9]\*' mode 666
add path 'cd[0-9]\*'    mode 666
add path 'mmcsd[0-9]\*' mode 666
add path 'pass[0-9]\*'  mode 666
add path 'xpt[0-9]\*' mode 666
add path 'ugen[0-9]\*'  mode 666
add path 'usbctl'   mode 666
add path 'usb/\*'   mode 666
add path 'lpt[0-9]\*' mode 666
add path 'ulpt[0-9]\*'  mode 666
add path 'unlpt[0-9]\*' mode 666
add path 'fd[0-9]\*'    mode 666
add path 'uscan[0-9]\*' mode 666
add path 'video[0-9]\*' mode 666
add path 'tuner[0-9]*'  mode 666
add path 'dvb/\*'   mode 666
add path 'cx88*' mode 0660
add path 'cx23885*' mode 0660 # CX23885-family stream configuration device
add path 'iicdev*' mode 0660
add path 'uvisor[0-9]*' mode 0660
" /etc/devfs.rules

# /etc/hosts
# TBD add domain to hostname?

# /etc/login.conf
# TBD

# firewall
# TBD

# Optional packages and configuration

if [ "$VBOX" = true ]; then
  pkg install -y virtualbox-ose-additions

  write_to_file '
# Enable VirtualBox Guest Additions
vboxguest_enable="YES"
vboxservice_enable="YES"
' /etc/rc.conf
fi

if [ "$GNOME" = true ]; then
  pkg install -y gnome3
fi

if [ "$GNOME" = true && "$XFCE" = false ]; then
  write_to_file '
# Enable Gnome login manager
gdm_enable="YES"
' /etc/rc.conf
fi

if [ "$XFCE" = true ]; then
  pkg install -y \
    xfce \
    xfce4-mixer \
    xfce4-power-manager \
    xfce4-netload-plugin \
    xfce4-systemload-plugin \
    slim \
    slim-themes

  write_to_file '
# Enable SLiM login manager
slim_enable="YES"
' /etc/rc.conf

  write_to_file 'exec $1' "/home/$CURRENT_USER/.xinitrc"
fi

# Final message
cat <<EOT

---------
Finished!
---------

Please reboot

EOT


#### https://cooltrainer.org/a-freebsd-desktop-howto/ ####

################## /boot/loader.conf ##################

# # Boot-time kernel tuning
# kern.ipc.shmseg=1024
# kern.ipc.shmmni=1024
# kern.maxproc=100000

# # Load MMC/SD card-reader support
# mmc_load="YES"
# mmcsd_load="YES"
# sdhci_load="YES"

# # Access ATAPI devices through the CAM subsystem
# atapicam_load="YES"

# # Filesystems in Userspace
# fuse_load="YES"

# # Intel Core thermal sensors
# coretemp_load="YES"

# # AMD K8, K10, K11 thermal sensors
# amdtemp_load="YES"

# # In-memory filesystems
# tmpfs_load="YES"

# # Asynchronous I/O
# aio_load="YES"

# # Enable sound
# snd_driver_load="YES"

# # Handle Unicode on removable media
# libiconv_load="YES"
# libmchain_load="YES"
# cd9660_iconv_load="YES"
# msdosfs_iconv_load="YES"

# # Userland character device driver for webcams
# cuse4bsd_load="YES"

################## /etc/sysctl.conf ##################

# # Enhance shared memory X11 interface
# kern.ipc.shmmax=67108864
# kern.ipc.shmall=32768

# # Enhance desktop responsiveness under high CPU use (200/224)
# kern.sched.preempt_thresh=224

# # Bump up maximum number of open files
# kern.maxfiles=200000

# # Disable PC Speaker
# hw.syscons.bell=0

# # Enable shared memory for Chromium
# kern.ipc.shm_allow_removed=1

# # Allow users to mount disks
# vfs.usermount=1

# # S/PDIF out on my MSI board
# hw.snd.default_unit=6

# # Don't automatically use new sound devices
# hw.snd.default_auto=0

################## /etc/rc.conf ##################

# # Enable mouse
# moused_enable="YES"

# # powerd: hiadaptive speed while on AC power, adaptive while on battery power
# powerd_enable="YES"
# powerd_flags="-a hiadaptive -b adaptive"

# # Enable BlueTooth
# hcsecd_enable="YES"
# sdpd_enable="YES"

# # Synchronize system time
# ntpd_enable="YES"
# # Let ntpd make time jumps larger than 1000sec
# ntpd_flags="-g"

# # Enable webcam
# webcamd_enable="YES"



#### TrueOS Install Defaults July 2017 ####

################## /boot/loader.conf ##################

# crypto_load="YES"
# aesni_load="YES"
# geom_eli_load="YES"
# # Tune ZFS Arc Size - Change to adjust memory used for disk cache
# vfs.zfs.arc_max="256M"
# zfs_load="YES"

################## /etc/sysctl.conf ##################

# Disable coredump
# kern.coredump=0

# # Allow users to mount CD's
# vfs.usermount=1

# # Autodetect the most recent sound card. Uncomment for Digital output / USB
# #hw.snd.default_auto=1

# # Enable shm_allow_removed
# kern.ipc.shm_allow_removed=1

# # Speed up the shutdown process
# kern.shutdown.poweroff_delay=500

# # Don't hang on shutdown when using USB disks
# hw.usb.no_shutdown_wait=1

# # Disable the system bell
# kern.vt.enable_bell=0
# hw.snd.default_unit=0

################## /etc/rc.conf ##################

# webcamd_enable="YES"
# # Auto-Enabled NICs from pc-sysinstall
# ifconfig_em0="DHCP"
# # Auto-Enabled NICs from pc-sysinstall
# ifconfig_em0_ipv6="inet6 accept_rtadv"
# hostname="trueos"
# zfs_enable="YES"

# dbus_enable="YES"
# hald_enable="YES"
# vboxguest_enable="YES"
# vboxservice_enable="YES"

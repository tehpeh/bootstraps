#!/bin/sh
set -e

# Download: curl -LO https://bit.ly/bootstrap-freebsd

# References
#
# https://cooltrainer.org/a-freebsd-desktop-howto/
# https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/x11-wm.html
# TrueOS Desktop install July 2017
# GhostBSD 11.1
# https://www.c0ffee.net/blog/freebsd-on-a-laptop/
#
# TODO:
#
# - add custom files/mods from /usr/local/etc/devd/
# - update pf.conf

# Util functions

show_help() {
  cat << EOT
usage: freebsd-bootstrap.sh [--gnome][--kde][--xfce][--vbox][--vmware]|[--help]

--gnome
  Install Gnome

--kde
  Install KDE

--xfce
  Install XFCE

--vbox
  Include VirtualBox additions and config

--vmware
  Include VMWare additions and config

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
KDE=false
XFCE=false
VBOX=false
VMWARE=false

while :; do
  case $1 in
    -h|-\?|--help)
        show_help
        exit
        ;;
    --gnome)
        echo "Installing Gnome"
        GNOME=true
        ;;
    --kde)
        echo "Installing KDE"
        KDE=true
        ;;
    --xfce)
        echo "Installing XFCE"
        XFCE=true
        ;;
    --vbox)
        echo "Using VirtualBox configuration"
        VBOX=true
        ;;
    --vmware)
        echo "Using VMWare configuration"
        VMWARE=true
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

# Check for root
if [ $(whoami) != 'root' ]; then
  printf "Please run as root"
  exit
fi

CURRENT_USER=$(logname)

# Interactive system update
read -p "Do you want to check for and install system updates? [y/N]: " answer
case $answer in
  [Yy]*)
    freebsd-update fetch install
    printf "\nPlease reboot then re-run this script to continue...\n"
    exit
    ;;
esac

# Load linux if not already
if [ ! "$(kldstat -v | grep linux64)" ]; then
  kldload linux64
fi

# Packages

# Switch to 'latest' pkg repository
# TODO: make this an option
# if [ "$(grep quarterly /etc/pkg/FreeBSD.conf)" ]; then
#   mkdir -p /usr/local/etc/pkg/repos
#   cp /etc/pkg/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf
#   sed -i '' -e 's/quarterly/latest/g' /usr/local/etc/pkg/repos/FreeBSD.conf
# fi

pkg bootstrap -y
pkg update
pkg upgrade -y

# Install utilities
pkg install -y \
  bastille \
  bhyve-firmware \
  ca_root_nss \
  curl \
  direnv \
  doas \
  en-hunspell \
  fish \
  fusefs-encfs \
  git \
  gnupg \
  grub2-bhyve \
  htop \
  ipad_charge \
  keybase \
  libdvdcss \
  libinotify \
  linux-c7 \
  openssl \
  password-store \
  pefs-kmod \
  powerdxx \
  readline \
  rpm4 \
  sudo \
  tmux \
  vm-bhyve \

# Install applications
pkg install -y \
  chromium \
  dsbmc \
  dsbmc-cli \
  dsbmd \
  dsbmixer \
  firefox \
  linux-sublime-text4 \
  neovim \
  sndio \
  thunderbird \
  tigervnc-viewer \
  virtual_oss \
  x11-fonts/anonymous-pro \
  x11-fonts/dejavu \
  x11-fonts/droid-fonts-ttf \
  x11-fonts/google-fonts \
  x11-fonts/liberation-fonts-ttf \
  x11-fonts/meslo \
  x11-fonts/noto-emoji \
  x11-fonts/roboto-fonts-ttf \
  x11-fonts/terminus-font \
  x11-fonts/twemoji-color-font-ttf \
  x11-fonts/webfonts \
  xorg \
  zeal \
  # drm-kmod \
  # nvidia-driver \

# Install development environment
pkg install -y \
  devel/ruby-gems \
  go \
  ImageMagick7 \
  node \
  python3 \
  qt5-webkit qt5-qmake qt5-buildtools \
  rbenv \
  ruby \
  ruby-build \
  yarn \

# Install services
pkg install -y \
  dnsmasq \
  nginx  \
  postgresql14-server postgresql14-client postgresql14-contrib \
  redis \
  # elasticsearch7 \
  # memcached \
  # opensearch \
  # rabbitmq \

# TODO: There is a port available for resilio sync, no package, at net-p2p/rslsync

# Set up fonts
# NOTE: If you install `x11-fonts/urwfonts-ttf` then disable all Nimbus fonts in font-manager
# because Nimbus, as replacement for Helvetica, renders really compressed kerning in Firefox
# ln -s /usr/local/etc/fonts/conf.avail/10-hinting-none.conf /usr/local/etc/fonts/conf.d/
# ln -s /usr/local/etc/fonts/conf.avail/10-no-sub-pixel.conf /usr/local/etc/fonts/conf.d/
# ln -s /usr/local/etc/fonts/conf.avail/70-no-bitmaps.conf /usr/local/etc/fonts/conf.d/

# Add admin and video acceleration groups to user
pw usermod "$CURRENT_USER" -G wheel,operator,video

# Initialize rpm database for installing linux packages
# mkdir -p /var/lib/rpm
# /usr/local/bin/rpm --initdb

# Setup PostgreSQL
/usr/local/etc/rc.d/postgresql oneinitdb
service postgresql onestart
sudo -u postgres createuser -s "$CURRENT_USER"
sudo -u postgres createdb "$CURRENT_USER"

# Write default configuration files

# /boot/loader.conf
# use kldstat -v | grep <name> to check what is already loaded
write_to_file '
# Load crypto and geli
aesni_load="YES"
geom_eli_load="YES"

# Reduce boot menu delay
autoboot_delay="3"

# Boot-time kernel tuning
kern.ipc.shmseg=1024
kern.ipc.shmmni=1024
kern.maxproc=100000

# Increase the network interface queue link - default 50
# net.link.ifqmaxlen="2048" # removed for now, causes issues

# Load accf_http, buffer incoming connections until a certain complete HTTP requests arrive
accf_http_load="YES"

# Tune ZFS Arc Size - Change to adjust memory used for disk cache, default is half available RAM
vfs.zfs.arc_max="256M"

# Enable CPU firmware updates
cpuctl_load="YES"

# Filesystems in Userspace
fusefs_load="YES"

# In-memory filesystems
tmpfs_load="YES"

# Enable sound
snd_driver_load="YES"

# Handle Unicode on removable media
libiconv_load="YES"
libmchain_load="YES"
cd9660_iconv_load="YES"
msdosfs_iconv_load="YES"

# Userland character device library (for webcams FreeBSD > 11)
cuse_load="YES"

# Hardware specific:

# Intel Core thermal sensors
# coretemp_load="YES"

# AMD K8, K10, K11 thermal sensors
# amdtemp_load="YES"

# Enable Apple System Management Console
# asmc_load="YES"

# Enable Wellspring touchpad driver (for Apple Internal Trackpad)
# wsp_load="YES"

# Switch to headphones when plugged in
# hint.hdaa.0.nid9_config="as=3 seq=15"
# TODO: research https://forums.freebsd.org/threads/changing-sound-devices-in-real-time.54229/

# Enable Android and Raspberry Pi tethering
# if_urndis_load="YES"

# Disable cdce
# hint.cdce.0.disabled="1"

# Realtek RTL8192EU wireless USB driver
# if_rtwn_usb_load="YES"
# legal.realtek.license_ack=1

# Ralink Technology USB IEEE 802.11a/b/g wireless driver
# if_rum_load="YES"

# Broadcom BMC43224
# with GPL PHY version from net/bwn-firmware-kmod port
# https://svnweb.freebsd.org/base?view=revision&revision=326841
# http://landonf.org/code/freebsd/Broadcom_WiFi_Improvements.20180122.html
# hw.bwn_pci.preferred="1"
# if_bwn_pci_load="YES"
# bwn_v4_ucode_load="YES"
# bwn_v4_n_ucode_load="YES"
# bwn_v4_lp_ucode_load="YES"
' /boot/loader.conf

# /etc/rc.conf
# use sudo service <name> onestatus to check what is already running
write_to_file '
# Installer defaults: (may already exist)

# Clear /tmp on reboot
clear_tmp_enable="YES"

# Disable syslog open network sockets
syslogd_flags="-ss"

# Disable the sendmail daemon
sendmail_enable="NONE"

# Set hostname
# hostname=""

# Networking:

# Ethernet em0
ifconfig_em0="DHCP"
ifconfig_em0_ipv6="inet6 accept_rtadv"

# Tethered Raspberry Pi
# ifconfig_ue0="DHCP"

# Wireless USB TP-Link rtwn0
# wlans_rtwn0="wlan0"
# ifconfig_wlan0="WPA DHCP"
# OR ifconfig_wlan0="-ht WPA DHCP"

# Wireless USB D-Link DWL-G122 rev C1 rum0
# wlans_rum0="wlan1"
# ifconfig_wlan1="WPA DHCP"

# Do not wait for DHCP during boot
background_dhclient="YES"

# Enable PF
pf_enable="YES"

# Start OpenVPN client
# openvpn_enable="YES"
# openvpn_if="tun"
# openvpn_configfile=""

# Devices:

# Caps lock as control in console
keymap="us.ctrl.kbd"

# Enable mouse in console
moused_enable="YES"

# powerdxx_enable="YES" # port, more conservative scaling
powerd_enable="YES" # base, more aggressive scaling

# Load nvidia-driver
# kld_list="nvidia"
# kld_list="nvidia-modeset"  # use this if issues

# Load Intel driver
# kld_list="i915kms"
# kld_list="/boot/modules/i915kms.ko"  # for 12.0?

# Load AMD driver
# kld_list="amdgpu"

# Load Radeon KMS
# kld_list="radeonkms"
# kld_list="/boot/modules/radeonkms.ko"  # for 12.0?

# Enable BlueTooth
hcsecd_enable="YES"
sdpd_enable="YES"

# Synchronize system time
ntpd_enable="YES"
# Let ntpd make time jumps larger than 1000sec
ntpd_flags="-g"

# Enable virtual_oss to combine audio devices
# Output is USB Scarlett, input is USB webcam
# virtual_oss_enable="YES"
# virtual_oss_dsp="-T /dev/sndstat \
# -C 2 -c 2 \
# -S \
# -r 48000 \
# -b 16 \
# -s 1024 \
# -O /dev/dsp4 \
# -R /dev/dsp3 \
# -d dsp
# -t dsp.ctl"

# Enable sndio for audio
# sndiod_enable="YES"
# sndiod_flags="-j on" # use this with virtual_oss and/or Chromium
# sndiod_flags="-j on -r 96000 -e s24" # use with virtual_oss@96k24bit
# add media.cubeb.backend=sndio to firefox about:config - not necessary

# Enable webcam
webcamd_enable="YES"

# Enable linux compatibility
linux_enable="YES"

# Enable our custom device ruleset
devfs_system_ruleset="devfsrules_common"

# Enable DSBMD with GUI for mounting external disks
dsbmd_enable="YES"

# iPad charge
ipad_charge_enable="YES"

# Services:

# Enable services for Gnome type desktops
# avahi_daemon_enable="YES"
dbus_enable="YES"

# Start sshd
sshd_enable="YES"
sshd_flags="-o ListenAddress=HOSTNAME" # dont listen on cloned loopback interface

# Start dnsmasq
# dnsmasq_enable="YES"

# Start nginx
# nginx_enable="YES"

# Start databases
postgresql_enable="YES"
redis_enable="YES"

# Run Resilio Sync
# rslsync_enable="YES"
# rslsync_user=""
# rslsync_storage=""
' /etc/rc.conf

# /etc/sysctl.conf
write_to_file '
# Enhance shared memory X11 interface
kern.ipc.shmmax=67108864
kern.ipc.shmall=32768

# Enhance desktop responsiveness under high CPU use (200/224)
kern.sched.preempt_thresh=224

# Bump up maximum number of open files
kern.maxfilesperproc=1048576
kern.maxvnodes=1048576
kern.maxfiles=1048576

# Enable shared memory for Chromium
kern.ipc.shm_allow_removed=1

# Allow users to mount disks
vfs.usermount=1

# Do not hang on shutdown when using USB disks
hw.usb.no_shutdown_wait=1

# Disable the system bell
kern.vt.enable_bell=0
# Enable sound card polling
# dev.hdac.0.polling=1
# Select first sound card
hw.snd.default_unit=0
# Autodetect the most recent sound card. Uncomment for Digital output / USB
# hw.snd.default_auto=1
' /etc/sysctl.conf

# /etc/fstab
write_to_file '
proc\t/proc\tprocfs\trw\t0\t0
fdesc\t/dev/fd\tfdescfs\trw,auto,late\t0\t0
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
add path 'ad[0-9]\*'    mode 0660 group operator
add path 'ada[0-9]\*' mode 0660 group operator
add path 'da[0-9]\*'    mode 0660 group operator
add path 'acd[0-9]\*' mode 0660 group operator
add path 'cd[0-9]\*'    mode 0660 group operator
add path 'mmcsd[0-9]\*' mode 0660 group operator
add path 'pass[0-9]\*'  mode 0660 group operator
add path 'xpt[0-9]\*' mode 0660 group operator
add path 'ugen[0-9]\*'  mode 0660 group operator
add path 'usbctl'   mode 0660 group operator
add path 'usb/\*'   mode 0660 group operator
add path 'lpt[0-9]\*' mode 0660 group operator
add path 'ulpt[0-9]\*'  mode 0660 group operator
add path 'unlpt[0-9]\*' mode 0660 group operator
add path 'fd[0-9]\*'    mode 0660 group operator
add path 'uscan[0-9]\*' mode 0660 group operator
add path 'video[0-9]\*' mode 0660 group operator
add path 'tuner[0-9]*'  mode 0660 group operator
add path 'dvb/\*'   mode 0660 group operator
add path 'cx88*' mode 0660 group operator
add path 'cx23885*' mode 0660 group operator # CX23885-family stream configuration device
add path 'iicdev*' mode 0660 group operator
add path 'uvisor[0-9]*' mode 0660 group operator
" /etc/devfs.rules

# set locale to UTF-8-US
write_to_file '
me:\\
        :charset=UTF-8:\\
        :lang=en_US.UTF-8:
' "/home/$CURRENT_USER/.login_conf"

# /etc/pf.conf
write_to_file '
# The name of our network interface as seen in `ifconfig`
ext_if="em0"

# Custom services
resilio_sync = "55555"

# Macros to define the set of TCP and UDP ports to open.
# Add additional ports or ranges separated by commas.
tcp_services = "{ssh," $resilio_sync "}"
udp_services = "{dhcpv6-client}"

# If you block all ICMP requests you will break things like path MTU
# discovery. These macros define allowed ICMP types. The additional
# ICMPv6 types are for neighbor discovery (RFC 4861)
icmp_types = "{echoreq, unreach}"
icmp6_types="{echoreq, unreach, 133, 134, 135, 136, 137}"

# Modulate the initial sequence number of TCP packets.
# Broken operating systems sometimes dont randomize this number,
# making it guessable.
tcp_state="flags S/SA keep state"
udp_state="keep state"

# Drop blocked packets, causing clients to wait for timeout, or
# set block-policy drop
# Reject blocked packets
set block-policy return

# Exempt the loopback interface to prevent services utilizing the
# local loop from being blocked accidentally.
set skip on lo0

# All incoming traffic on external interface is normalized and fragmented
# packets are reassembled.
scrub in on $ext_if all fragment reassemble

# Set a default deny policy.
block in log all

# This is a desktop so be permissive in allowing outgoing connections.
pass out quick modulate state

# Enable antispoofing on the external interface
antispoof for $ext_if inet
antispoof for $ext_if inet6

# block packets that fail a reverse path check. we look up the routing
# table, check to make sure that the outbound is the same as the source
# it came in on. if not, it is probably source address spoofed.
block in from urpf-failed to any

# drop broadcast requests quietly.
block in quick on $ext_if from any to 255.255.255.255

# Allow the services defined in the macros at the top of the file
pass in on $ext_if inet proto tcp from any to any port $tcp_services $tcp_state
pass in on $ext_if inet6 proto tcp from any to any port $tcp_services $tcp_state

pass in on $ext_if inet proto udp from any to any port $udp_services $udp_state
pass in on $ext_if inet6 proto udp from any to any port $udp_services $udp_state

# Allow ICMP
pass inet proto icmp all icmp-type $icmp_types keep state
pass inet6 proto icmp6 all icmp6-type $icmp6_types keep state
' /etc/pf.conf

# /etc/make.conf
write_to_file '
DEFAULT_VERSIONS+=ssl=openssl111
WITH_CCACHE_BUILD=yes
# Audio systems
OPTIONS_SET+=SNDIO # enable sndio compile option
OPTIONS_SET+=PORTAUDIO # Portaudio supports sndio, so more software supports sndio (gqrx is an example)
OPTIONS_UNSET=PULSEAUDIO PULSE #ALSA # disable other audio systems
' /etc/make.conf

# /usr/local/etc/rc.d/rslsync
write_to_file '
#!/bin/sh
#
# PROVIDE: rslsync
# REQUIRE: LOGIN DAEMON NETWORKING
# KEYWORD: shutdown
#
# To enable rslsync, add this line to your /etc/rc.conf:
#
# rslsync_enable="YES"
#
# And optionally these line:
#
# rslsync_user="username" # Default is "root"
# rslsync_bin="/path/to/rslsync" # Default is "/usr/local/bin/rslsync"
# rslsync_storage="/root/.config/rslsync"

. /etc/rc.subr

name="rslsync"
rcvar="rslsync_enable"

load_rc_config $name

required_files=$rslsync_bin

: ${rslsync_enable="NO"}
: ${rslsync_user="root"}
: ${rslsync_bin="/usr/local/bin/rslsync"}
: ${rslsync_storage="/root/.config/rslsync"}

command=$rslsync_bin
command_args="--storage ${rslsync_storage}"

run_rc_command "$1"
' /usr/local/etc/rc.d/rslsync

# Optional packages and configuration

if [ "$VBOX" = true ]; then
  pkg install -y virtualbox-ose-additions

  write_to_file '
# Enable VirtualBox Guest Additions
vboxguest_enable="YES"
vboxservice_enable="YES"
' /etc/rc.conf

mkdir -p /usr/local/etc/X11/xorg.conf.d

write_to_file '
Section "InputDevice"
    Identifier "Mouse0"
    Driver "vboxmouse"
EndSection
' /usr/local/etc/X11/xorg.conf.d/10-vboxmouse.conf

sysrc moused_enable="YES"
fi

if [ "$VMWARE" = true ]; then
  pkg install -y xf86-input-vmmouse xf86-video-vmware open-vm-tools
  # use open-vm-tools-nox11 for servers

  write_to_file '
# Enable VMWare Guest Additions
vmware_guestd_enable="YES"
' /etc/rc.conf

mkdir -p /usr/local/etc/X11/xorg.conf.d

  write_to_file '
Section "ServerFlags"
       Option             "AutoAddDevices"       "false"
EndSection
Section "InputDevice"
       Identifier "Mouse0"
       Driver             "vmmouse"
       Option              "Device"       "/dev/sysmouse"
EndSection
' /usr/local/etc/X11/xorg.conf.d/10-vmmouse.conf

sysrc moused_enable="YES"
fi

if [ "$GNOME" = true ]; then
  pkg install -y gnome
fi

if [ "$GNOME" = true && "$XFCE" = false ]; then
  write_to_file '
# Enable Gnome login manager
gdm_enable="YES"
' /etc/rc.conf
fi

if [ "$KDE" = true ]; then
  pkg install -y kde5 sddm

  write_to_file '
# Enable KDE login manager
sddm_enable="YES"
' /etc/rc.conf
fi

if [ "$XFCE" = true ]; then
  pkg install -y \
    xfce \
    xfce4-goodies \
    greybird-theme \
    lightdm \
    lightdm-gtk-greeter \
    lightdm-gtk-greeter-settings

    # Covered with xfce4-goodies:
    # xfce4-clipman-plugin \
    # xfce4-cpugraph-plugin \
    # xfce4-genmon-plugin \
    # xfce4-netload-plugin \
    # xfce4-power-manager \
    # xfce4-screensaver \
    # xfce4-systemload-plugin \
    # xfce4-taskmanager \
    # xfce4-wm-themes \
    # xfce4-weather-plugin \
    # xfce4-whiskermenu-plugin \
    # thunar-archive-plugin

  # Extra applications
  pkg install -y \
    font-manager \
    gnome-keyring \
    gtk-arc-themes \
    networkmgr \
    redshift \
    seahorse \
    wifimgr \
    xarchiver \
    xpdf \

  write_to_file '
# Enable LightDM display manager
lightdm_enable="YES"
' /etc/rc.conf

  write_to_file '
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export TZ=":Australia/Sydney"
' ."/home/$CURRENT_USER/.xprofile"

  write_to_file "
remove Lock = Caps_Lock
keysym Caps_Lock = Control_L
add Control = Control_L
" "/home/$CURRENT_USER/.Xmodmap"

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


#### GhostBSD 11.1 defaults ####

################## /boot/loader.conf ##################

# loader_brand="gbsd"
# loader_logo="gbsd"
# hw.psm.synaptics_support="1"
# # boot_mute="YES"
# crypto_load="YES"
# aesni_load="YES"
# geom_eli_load="YES"
# zfs_load="YES"

################## /etc/sysctl.conf ##################

# # $FreeBSD: releng/11.1/etc/sysctl.conf 112200 2003-03-13 18:43:50Z mux $
# #
# #  This file is read when going to multi-user and its contents piped thru
# #  ``sysctl'' to adjust kernel values.  ``man 5 sysctl.conf'' for details.
# #

# # Uncomment this to prevent users from seeing information about processes that
# # are being run under another UID.
# #security.bsd.see_other_uids=0
# vfs.usermount=1

# # the following is required to run chromium browser
# kern.ipc.shm_allow_removed=1

# # make sure the system find the kernel path.
# kern.bootfile=/boot/kernel/kernel

# # this is required for MBR 4 alignement
# kern.geom.part.mbr.enforce_chs=0

# vm.defer_swapspace_pageouts=1

################## /etc/rc.conf ##################

# # Power saver.
# powerd_enable="YES"
# powerd_flags="-a adp -b adp"

# # DEVFS rules
# devfs_system_ruleset="devfsrules_common"
# devd_enable="YES"

# # usbd_enable="YES"
# dbus_enable="YES"
# hald_enable="YES"
# polkit_enable="YES"

# moused_enable="YES"
# # iscsid_enable="YES"

# # Enable linux compatibility
# linux_enable="YES"

# # Load the following kernel modules
# kld_list="geom_mirror geom_journal geom_eli linux fuse ext2fs cuse"

# # Configs from installed packages
# webcamd_enable="YES"
# vboxguest_enable="YES"
# vboxservice_enable="YES"
# cupsd_enable="YES"
# lpd_enable="NO"

# slim_enable="YES"
# ntpd_enable="YES"
# ntpd_sync_on_start="YES"
# keymap="us.iso"
# hostname="xfce.ghostbsd-pc.home"
# slim_enable="YES"
# zfs_enable="YES"
# ifconfig_em0="DHCP"

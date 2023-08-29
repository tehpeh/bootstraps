#!/bin/sh

# Tested on FreeBSD 13.1

# Start installation as usual, but choose 'Shell' in the partitioning menu.

# References:
# https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot
# https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot/9.0-RELEASE
# https://svnweb.freebsd.org/base/head/usr.sbin/bsdinstall/scripts/zfsboot?view=markup
# http://kev009.com/wp/2016/07/freebsd-uefi-root-on-zfs-and-windows-dual-boot/
# https://www.keltia.net/howtos/mfsbsd-zfs11/
# https://www.c0ffee.net/blog/freebsd-full-disk-encryption-uefi/
# https://forums.freebsd.org/threads/cant-boot-on-uefi.68141/post-406138
# https://forums.freebsd.org/threads/uefi-gpt-dual-boot-how-to-install-freebsd-with-zfs-alongside-another-os-sharing-the-same-disk.75734/

# Find device name, eg: nvd0
camcontrol devlist
# or
nvmecontrol devlist
# consider using nda instead of nvd driver for nvme drives

# Erase disk
# gpart destroy -F nvd0
# gpart create -s gpt nvd0

# Create UEFI boot partition
# gpart add -a 4k -s 200M -t efi -l boot0 nvd0 # macOS/Windows has already created this
# gpart bootcode -p /boot/boot1.efifat -i 1 nvd0 # creates an 800k FAT filesystem, not enough for rEFInd, copy loader manually
# eg:
# newfs_msdos -F 32 -c 1 /dev/nvd0p1
# mount -t msdosfs -o longnames /dev/nvd0p1 /mnt
# mkdir -p /mnt/EFI/BOOT
# cp /boot/loader.efi /mnt/EFI/BOOT/BOOTX64.efi
# umount /mnt

# Create swap and zfs partitions, align to 1m (align_big) [With GPT, we align
# large partitions to 1m for improved performance on SSDs]
gpart add -a 1m -s 16G -t freebsd-swap -l swap0 nvd0
gpart add -a 1m -s 200G -t freebsd-zfs -l zfs0 nvd0

# Enable zfs
kldload zfs

# Force 4k sectors, not required if using geli encryption
sysctl vfs.zfs.min_auto_ashift=12

# Create geli provider, init options:
# -l 128/256 - key length
# -b - decrypt during boot (use with bootpool)
# -g - enable booting from this encrypted root filesystem
# -s - sector size
geli init -bg -s 4096 /dev/gpt/zfs0
geli attach /dev/gpt/zfs0

# Create zroot
zpool create -o altroot=/mnt -m none zroot gpt/zfs0.eli

# Set defaults
# Latest compression algo is zstd
zfs set compression=lz4                                        zroot
zfs set atime=off                                              zroot

# Create zfs datasets
zfs create -o mountpoint=none                                  zroot/ROOT
zfs create -o mountpoint=/     -o canmount=noauto              zroot/ROOT/default
mount -t zfs zroot/ROOT/default /mnt
zfs create -o mountpoint=/tmp  -o exec=on      -o setuid=off   zroot/tmp
zfs create -o mountpoint=/usr  -o canmount=off                 zroot/usr
zfs create                                                     zroot/usr/home
zfs create                                                     zroot/usr/local
zfs create                                                     zroot/usr/obj
zfs create -o mountpoint=/usr/ports            -o setuid=off   zroot/usr/ports
zfs create                     -o exec=off     -o setuid=off   zroot/usr/ports/distfiles
zfs create                     -o exec=off     -o setuid=off   zroot/usr/ports/packages
zfs create                     -o exec=off     -o setuid=off   zroot/usr/src
zfs create -o mountpoint=/var  -o canmount=off                 zroot/var
zfs create                     -o exec=off     -o setuid=off   zroot/var/audit
zfs create                     -o exec=off     -o setuid=off   zroot/var/crash
zfs create                     -o exec=off     -o setuid=off   zroot/var/log
zfs create -o atime=on         -o exec=off     -o setuid=off   zroot/var/mail
zfs create                     -o exec=on      -o setuid=off   zroot/var/tmp

ln -s /usr/home /mnt/home
chmod 1777 /mnt/var/tmp
chmod 1777 /mnt/tmp
zpool set bootfs=zroot/ROOT/default zroot

cat << EOF > /tmp/bsdinstall_boot/loader.conf.geli
geom_eli_load="YES"
EOF

# Create /tmp/bsdinstall_etc/fstab
cat << EOF > /tmp/bsdinstall_etc/fstab
# Device                       Mountpoint              FStype  Options         Dump    Pass#
/dev/gpt/swap0.eli             none                    swap    sw              0       0
EOF

cat << EOF > /tmp/bsdinstall_etc/rc.conf.zfs
zfs_enable="YES"
EOF

# Continue installation
exit

#!/bin/sh

# Tested on FreeBSD 11.2

# Start installation as usual, but choose 'Shell' in the partitioning menu.

# References:
# https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot
# https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot/9.0-RELEASE
# https://svnweb.freebsd.org/base/head/usr.sbin/bsdinstall/scripts/zfsboot?view=markup
# http://kev009.com/wp/2016/07/freebsd-uefi-root-on-zfs-and-windows-dual-boot/
# https://www.keltia.net/howtos/mfsbsd-zfs11/
# https://www.c0ffee.net/blog/freebsd-full-disk-encryption-uefi/

# Find device name, eg: ada0
camcontrol devlist

# Erase disk
# gpart destroy -F ada0
# gpart create -s gpt ada0

# Create UEFI boot partition
# gpart add -a 4k -s 200M -t efi -l boot0 ada0 # macOS has already created this
gpart bootcode -p /boot/boot1.efifat -i 1 ada0

# Create swap and zfs partitions, align to 1m (align_big) [With GPT, we align
# large partitions to 1m for improved performance on SSDs]
  gpart add -a 1m -s 1G -t freebsd-zfs -l bootpool0 ada0 # GELI ONLY
gpart add -a 1m -s 16G -t freebsd-swap -l swap0 ada0
gpart add -a 1m -s 200G -t freebsd-zfs -l zfs0 ada0

# Find the partition name, eg: ada0p3
# gpart show -p ada0 # Not necessary if gpt labels are used

# Enable zfs
kldload zfs

# Force 4k sectors, not required if using geli encryption
sysctl vfs.zfs.min_auto_ashift=12

# Create root zpool
zpool create -o altroot=/mnt zroot gpt/zfs0 # NO GELI, ignore mount error
### GELI ONLY ###
# Create bootpool
  zpool create -o altroot=/mnt bootpool gpt/bootpool0 # ignore mount error
  mount -t zfs bootpool /mnt
  mkdir /mnt/boot

  kldload aesni
  dd if=/dev/random of=/mnt/boot/encryption.key bs=64 count=1
# geli init options:
# -l 128/256 - key length
# -b - decrypt during boot (use with bootpool)
# -g - enable booting from this encrypted root filesystem (does not yet work on UEFI? supposed to use -bg)
  geli init -b -s 4096 -K /mnt/boot/encryption.key /dev/gpt/zfs0
  geli attach -K /mnt/boot/encryption.key /dev/gpt/zfs0
  dd if=/dev/random of=/dev/gpt/zfs0.eli bs=1m
  umount /mnt # unmount bootpool
  zpool create -o altroot=/mnt zroot gpt/zfs0.eli # ignore mount error
  zpool set cachefile=/boot/zfs/zpool.cache zroot
  zpool set cachefile=/boot/zfs/zpool.cache bootpool

  cat << EOF > /tmp/bsdinstall_boot/loader.conf.geli
  geli_ada0p4_keyfile0_load="YES"
  geli_ada0p4_keyfile0_type="ada0p4:geli_keyfile0"
  geli_ada0p4_keyfile0_name="/boot/encryption.key"
  aesni_load="YES"
  geom_eli_load="YES"
  vfs.root.mountfrom="zfs:zroot/ROOT/default"
  kern.geom.label.disk_ident.enable="0"
  kern.geom.label.gptid.enable="0"
  zpool_cache_load="YES"
  zpool_cache_type="/boot/zfs/zpool.cache"
  zpool_cache_name="/boot/zfs/zpool.cache"
  geom_eli_passphrase_prompt="YES"
EOF
### END GELI ###

# Set defaults
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

### GELI ONLY ###
# Mount bootpool for installer
  mkdir /mnt/bootpool
  mount -t zfs bootpool /mnt/bootpool
  cd /mnt
  ln -s bootpool/boot
  cd /
### END GELI ###

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

#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

mkdir -p "$tmp"/etc/network
makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base busybox linux-lts
linux-firmware-amd linux-firmware-amd-ucode
linux-firmware-amdgpu linux-firmware-radeon
linux-firmware-nvidia
linux-firmware-intel linux-firmware-i915
linux-firmware-rtlwifi linux-firmware-mwlwifi
linux-firmware-brcm
linux-firmware-qca linux-firmware-qcom
linux-firmware-ath10k linux-firmware-ath11k
efibootmgr os-prober grub grub-efi
util-linux coreutils usbutils ethtool hwids
sudo doas nano curl rsync rsync-openrc
iptables iptables-openrc
wireless-tools wpa_supplicant wpa_supplicant-openrc
iwd iwd-openrc
e2fsprogs e2fsprogs-extra dosfstools mtools lvm2
nfs-utils ntfs-3g btrfs-progs xfsprogs f2fs-tools
parted sfdisk sgdisk
zfs-lts zfs-openrc zfs-scripts zfs-utils-py
EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add networking boot
rc_add local boot

rc_add iwd default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz

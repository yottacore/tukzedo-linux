<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->
<div align="center">

![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)
![Lifecycle: Beta](https://img.shields.io/badge/Lifecycle-Beta-yellow)
![Support](https://img.shields.io/badge/Support-Maintained-brightgreen)

</div>
<!--
[![!#/bin/bash](https://img.shields.io/badge/-%23!%2Fbin%2Fbash-1f425f.svg?logo=gnu-bash)](https://www.gnu.org/software/bash/)
![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Lifecycle: Alpha](https://img.shields.io/badge/Lifecycle-Alpha-orange)
![Lifecycle: Beta](https://img.shields.io/badge/Lifecycle-Beta-yellow)
![Lifecycle: RC](https://img.shields.io/badge/Lifecycle-RC-blue)
![Lifecycle: Stable](https://img.shields.io/badge/Lifecycle-Stable-brightgreen)
![Lifecycle: Deprecated](https://img.shields.io/badge/Lifecycle-Deprecated-red)
![Status: Deprecated](https://img.shields.io/badge/Status-Deprecated-orange)
![Status: Archived](https://img.shields.io/badge/Status-Archived-lightgrey)
![Lifecycle: EOL](https://img.shields.io/badge/Lifecycle-EOL-lightgrey)
![Coverage](https://img.shields.io/badge/Coverage-25%25-red)
![Coverage](https://img.shields.io/badge/Coverage-50%25-orange)
![Coverage](https://img.shields.io/badge/Coverage-75%25-yellow)
![Coverage](https://img.shields.io/badge/Coverage-90%25-brightgreen)
![Status: Passing](https://img.shields.io/badge/Status-Passing-brightgreen)
![Status: Failing](https://img.shields.io/badge/Status-Failing-red)
-->

<!-- TOC ignore:true -->
# How to install Tukzedo Linux (Debian Trixie edition)

A step-by-step guide to building your own Tukzedo Linux install, on a Debian 13 "Trixie" base.

<!-- TOC ignore:true -->
## Table of contents

<!-- TOC -->

- [Introduction](#introduction)
- [Before you start](#before-you-start)
- [Creation steps](#creation-steps)
	- [Set up the VM](#set-up-the-vm)
	- [Prepare the live environment](#prepare-the-live-environment)
	- [Set variables](#set-variables)
	- [Partition the target drive](#partition-the-target-drive)
	- [Create LUKS and LVM](#create-luks-and-lvm)
	- [Create the ZFS pool and datasets](#create-the-zfs-pool-and-datasets)
	- [Install the base system](#install-the-base-system)
	- [Enter the chroot](#enter-the-chroot)
	- [Configure the base system](#configure-the-base-system)
	- [Install the kernel, ZFS and boot tools](#install-the-kernel-zfs-and-boot-tools)
	- [Configure dracut and the UKI command line](#configure-dracut-and-the-uki-command-line)
	- [Set up USB key unlock](#set-up-usb-key-unlock)
	- [Set up SSH unlock](#set-up-ssh-unlock)
	- [Set up fstab, ZFS services and the network](#set-up-fstab-zfs-services-and-the-network)
	- [Create users](#create-users)
	- [Lay out the ESP and build the first UKI](#lay-out-the-esp-and-build-the-first-uki)
	- [First boot](#first-boot)
	- [Mount ZFS datasets from systemd units](#mount-zfs-datasets-from-systemd-units)
	- [Set up encrypted-home mounting at login](#set-up-encrypted-home-mounting-at-login)
	- [Boot-time helpers and tunables](#boot-time-helpers-and-tunables)
	- [Keep systemd-boot signed after upgrades](#keep-systemd-boot-signed-after-upgrades)
	- [Turn on Secure Boot](#turn-on-secure-boot)
	- [Make the USB key](#make-the-usb-key)
	- [Add and manage users](#add-and-manage-users)
	- [Move the drive to its machine](#move-the-drive-to-its-machine)
	- [Install the desktop](#install-the-desktop)
	- [Change passphrases later](#change-passphrases-later)
	- [Get back in from a live system](#get-back-in-from-a-live-system)
	- [How it boots](#how-it-boots)
	- [Steps not yet converted](#steps-not-yet-converted)
		- [Install libvirt, Docker, NordVPN](#install-libvirt-docker-nordvpn)
	- [Install or update local scripts](#install-or-update-local-scripts)
- [Document history](#document-history)
- [Copyright and license](#copyright-and-license)

<!-- /TOC -->

## Introduction

This guide builds Tukzedo Linux from scratch onto one drive, from a Debian live ISO.

What you end up with:

- A GPT drive with 2 partitions:
	- A 4 GiB FAT32 UEFI system partition (ESP). It has shim, systemd-boot, and one signed Unified Kernel Image (UKI) per kernel. Each UKI is about 90 MiB, so 4 GiB leaves plenty of room.
	- A LUKS2 partition taking up the rest of the drive.

- Inside LUKS, an LVM volume group with a swap volume, and one volume for the ZFS root pool.

- A ZFS root pool with separate datasets for `/`, the persistent data folders, and `/home`. Regular users can each get their own encrypted home dataset, unlocked at login with their password.

- LUKS can be unlocked 3 ways at boot: a key file on a USB stick, a passphrase at the console, or a passphrase over SSH.

- The whole boot chain is signed with your own Machine Owner Key (MOK), so it works with Secure Boot on or off.

- It boots on Intel, AMD, or Nvidia graphics. GPU drivers are kept out of the UKI, so the unlock prompt uses the plain firmware framebuffer. The real driver loads after the root filesystem is up. Nvidia gets the open `nouveau` driver, which is fine for desktop use but not fast 3D.

There is no Grub and no separate boot pool. The UKI already has the kernel, initrd and command line, and its initrd can unlock LUKS and import ZFS on its own, so LUKS only gets unlocked once.

The names used below:

| Placeholder       | What it is                                                        | Example
|:------------------|:------------------------------------------------------------------|:----------------
| `<mUID>`          | A short unique ID for this install, used in device and pool names | `k7q2x`
| `<hostname>`      | The new system's hostname                                         | `myhost`
| `alice`           | A regular user with an encrypted home                             |
| `guest`           | A regular user with a plain home                                  |

## Before you start

- You need:
	- The target drive. Everything on it gets erased.
	- A separate Linux system to work from, with libvirt (KVM/QEMU) installed. A USB-booted Linux on the same machine works fine.
	- Wired Ethernet on the target machine, if you want SSH unlock. Wi-Fi isn't available that early in boot.
	- A spare USB stick, if you want USB key unlock. It gets erased too.
	- A password manager, for the passphrases and keys made along the way.

- Do the work in a VM with the target drive passed through to it, even when the drive is the machine's own internal drive. Inside the VM, the only disk you can see is the target. Your working system's drives aren't there to be wiped by mistake.

- The live system forgets everything when it reboots. Write down each passphrase the moment you make it up, before the next reboot. Losing the LUKS passphrase this early means starting over from the LUKS step.

## Creation steps

### Set up the VM

- On your working system, find the target drive's stable name. Prefer an `nvme-eui.`, `wwn-` or `nvme-<model>_<serial>` name over `/dev/sdX` or `/dev/nvme0n1`:

	~~~bash
	lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS
	ls -l /dev/disk/by-id/ | grep -v part
	~~~

- Make sure nothing on your working system has the target drive mounted, then download the Debian 13 "standard" live ISO. Check it against `SHA256SUMS` from the same folder.

	~~~bash
	cd /var/lib/libvirt/images
	sudo curl -fLO https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-13.7.0-amd64-standard.iso
	curl -fsS https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/SHA256SUMS | grep 'standard.iso$' | sha256sum -c -
	~~~

- Create the VM. Secure Boot stays off for now, because the live system has to load an unsigned ZFS module. Give the target a distinctive serial, so it's easy to spot inside the VM.

	~~~bash
	targetDisk=/dev/disk/by-id/nvme-eui.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  ## Yours from above
	sudo virsh net-start default 2>/dev/null
	sudo virt-install --name tkz-build --memory 8192 --vcpus 4 --osinfo debian13 \
		--boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
		--cdrom /var/lib/libvirt/images/debian-live-13.7.0-amd64-standard.iso \
		--controller scsi,model=virtio-scsi \
		--disk path="${targetDisk}",bus=scsi,serial=TKZTARGET,cache=none,discard=unmap \
		--network network=default --graphics vnc,listen=127.0.0.1 --noautoconsole
	~~~

- Open the VM's console in Virtual Machine Manager. The live system logs in by itself as `user`, whose password is `live`. Install an SSH server, adn get the VM's address:

	~~~bash
	sudo apt update && sudo apt install -y openssh-server
	ip -4 -br addr
	~~~

- From here on, work over SSH from your working system, as root, inside `tmux`. Copying commands is easier, and a dropped connection doesn't kill a long step.

	~~~bash
	ssh user@<vm-address>
	sudo -i
	apt install -y tmux && tmux new -s build
	~~~

### Prepare the live environment

- Add `contrib`, then install the build tools. ZFS builds through DKMS, so it takes a few minutes.

	~~~bash
	sed -i 's/ main non-free-firmware/ main contrib non-free-firmware/' /etc/apt/sources.list
	apt update
	apt install -y linux-headers-$(uname -r)
	apt install -y debootstrap gdisk parted dosfstools cryptsetup lvm2 zfs-dkms zfsutils-linux xxd
	modprobe zfs && zfs version
	~~~

- Confirm the VM booted with UEFI, and that the only disk is the target:

	~~~bash
	ls /sys/firmware/efi >/dev/null && echo UEFI
	lsblk -o NAME,SIZE,MODEL,SERIAL
	ls -l /dev/disk/by-id/ | grep TKZTARGET
	~~~

### Set variables

Every step below reads these variables. Keep them in a file and source it in each new shell, including inside the chroot later.

- Make up the install ID (mUID). It goes into the LUKS, LVM and ZFS names. It's kept separate from the hostname, so the drive can move to other hardware and get a new hostname without renaming everything.

	~~~bash
	head -c 100 /dev/urandom | base64 | tr -cd '0123456789cdefhkmnrtvwx' | awk 'BEGIN{FS=""}{for(i=1;i<=NF;i++)if(!seen[$i]++)printf $i;print""}' | head -c 5; echo
	~~~

- Make up a ZFS hostid for the new system. ZFS records the hostid of the system that imports a pool, and refuses to import the pool on a system with a different one. Using the new system's hostid in the live system as well avoids that whole problem.

	~~~bash
	head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n'; echo
	~~~

- Write the file. Use your own values:

	~~~bash
	cat > /root/tkz-vars.sh <<'EOF'
	mUID=k7q2x
	diskTarget=/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_TKZTARGET
	TEMPMOUNT_BASE=/mnt/tkz
	swapSizeGB=64
	zfsHostID=3a9c51f2
	newHostname=myhost
	EOF
	source /root/tkz-vars.sh
	~~~

	The swap size is up to you. Matching RAM leaves room for hibernation later, though hibernating with ZFS isn't covered here.

- Copy `/root/tkz-vars.sh` somewhere off the live system as well, such as your working system. It'll be needed again if you ever come back to this step.

### Partition the target drive

- This erases the target. Double-check `${diskTarget}` first.

	~~~bash
	lsblk -o NAME,SIZE,SERIAL "${diskTarget}"
	wipefs -a "${diskTarget}"-part* 2>/dev/null; sgdisk --zap-all "${diskTarget}"
	blkdiscard -f "${diskTarget}"
	~~~

- Partition 1 is the 4 GiB ESP. Partition 2 is LUKS, and fills the rest of the drive. Its end is rounded down to a 1 MiB boundary, so the size is a whole number of 4 KiB sectors for LUKS and ZFS.

	~~~bash
	sgdisk -a 2048 -n 1:1M:+4G -t 1:EF00 -c 1:UEFI_${mUID} "${diskTarget}"
	last=$(sgdisk -E "${diskTarget}" | tail -1); end=$(( (last + 1) / 2048 * 2048 - 1 ))
	sgdisk -a 2048 -n 2:0:${end} -t 2:8309 -c 2:LUKS_${mUID} "${diskTarget}"
	partprobe "${diskTarget}"; udevadm settle
	mkfs.fat -F32 -n UEFI_${mUID^^} "${diskTarget}-part1"
	sgdisk -p "${diskTarget}"
	echo "4K-aligned: $(( $(blockdev --getsz ${diskTarget}-part2) % 8 == 0 ))"   ## Want 1
	~~~

### Create LUKS and LVM

- Format LUKS2. It asks for a passphrase. This is the one you'll type at boot when there's no USB key, so make it long, and save it in your password manager now.

	~~~bash
	cryptsetup luksFormat --type luks2 --sector-size 4096 --cipher aes-xts-plain64 --key-size 512 --hash sha256 --pbkdf argon2id --label LUKS_${mUID} "${diskTarget}-part2"
	cryptsetup open --allow-discards "${diskTarget}-part2" crypt_${mUID}
	~~~

- Create the volume group, the swap volume, and the volume for ZFS:

	~~~bash
	pvcreate /dev/mapper/crypt_${mUID}
	vgcreate vg_${mUID} /dev/mapper/crypt_${mUID}
	lvcreate -L ${swapSizeGB}G -n lv_swap_${mUID} vg_${mUID}
	lvcreate -l 100%FREE -n lv_rpool_${mUID} vg_${mUID}
	mkswap -L swap_${mUID} /dev/vg_${mUID}/lv_swap_${mUID}
	~~~

- Record the UUIDs in the variables file:

	~~~bash
	cat >> /root/tkz-vars.sh <<EOF
	uefiUUID=$(blkid -s UUID -o value ${diskTarget}-part1)
	luksUUID=$(blkid -s UUID -o value ${diskTarget}-part2)
	swapUUID=$(blkid -s UUID -o value /dev/vg_${mUID}/lv_swap_${mUID})
	EOF
	source /root/tkz-vars.sh; tail -3 /root/tkz-vars.sh
	~~~

### Create the ZFS pool and datasets

- Give the live system the new hostid, then create the pool. `cachefile=none` means pools are found by scanning at boot, not from a cache file that goes stale when the drive is cloned or moved.

	~~~bash
	zgenhostid -f ${zfsHostID}
	mkdir -p ${TEMPMOUNT_BASE}
	zpool create -f -o ashift=12 -o autotrim=on -o cachefile=none \
		-O devices=off -O xattr=sa -O atime=off -O compression=lz4 -O normalization=formD -O utf8only=on \
		-O acltype=posixacl -O dnodesize=auto -O logbias=latency -O secondarycache=none \
		-O canmount=off -O mountpoint=none -R ${TEMPMOUNT_BASE} rpool_${mUID} /dev/vg_${mUID}/lv_rpool_${mUID}
	~~~

	Older notes for this project set `sync=disabled` on the pool. It's left at the default here, since with it disabled a crash can lose writes that programs were told were safe. If you want it anyway, it can be set per dataset at any time.

- Create the datasets. Order matters: `/` has to be mounted before anything under it.

	~~~bash
	P=rpool_${mUID}/deb
	mk(){ zfs create -o canmount="$2" -o mountpoint="$3" ${4:+-o com.sun:auto-snapshot=$4} "$1"; }
	mk $P               off     none  true
	mk $P/ROOT          noauto  /     ""
	zfs mount $P/ROOT
	zpool set bootfs=$P/ROOT rpool_${mUID}
	mk $P/imperm             off  none        false
	mk $P/imperm/var_tmp     on   /var/tmp    ""
	mk $P/imperm/var_spool   on   /var/spool  ""
	mk $P/persist            off  none        true
	for d in etc_opt:/etc/opt home:/home opt:/opt root:/root srv:/srv usr_local:/usr/local var_lib:/var/lib var_mail:/var/mail var_www:/var/www; do
		mk $P/persist/${d%%:*} on ${d#*:} ""
	done
	chmod 700 ${TEMPMOUNT_BASE}/root; chmod 1777 ${TEMPMOUNT_BASE}/var/tmp
	~~~

	- `imperm` is for data that's fine to lose, and isn't auto-snapshotted. `persist` is for the rest.
	- There's no `/tmp` dataset. Debian 13 mounts a fresh tmpfs on `/tmp` at every boot, which would hide it anyway.

- Create a plain home for each user that doesn't need encryption:

	~~~bash
	mk $P/persist/home/guest on /home/guest ""
	~~~

- Create an encrypted home for each user that does. It asks for a passphrase twice. Use the password that user will log in with, because the login script unlocks the home with it. `org.openzfs.systemd:ignore=on` keeps the boot from asking for it.

	~~~bash
	u=alice
	zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=prompt -o pbkdf2iters=600000 \
		-o canmount=noauto -o mountpoint=/home/$u -o x9.custom.automount:user=$u -o org.openzfs.systemd:ignore=on \
		$P/persist/home/$u
	zfs mount $P/persist/home/$u
	for c in .cache tmp var; do mk $P/persist/home/$u/$c on /home/$u/$c false; done
	~~~

- Check that everything is mounted under `${TEMPMOUNT_BASE}`:

	~~~bash
	zfs list -o name,mountpoint,canmount,mounted,encryption -r rpool_${mUID}
	~~~

### Install the base system

- Run `debootstrap`. It may print `cannot create .../test-dev-null: Permission denied`. That's a probe that fails because the pool has `devices=off`, and debootstrap keeps going without it. Look for `Base system installed successfully` at the end.

	~~~bash
	debootstrap --arch=amd64 --include=locales,ca-certificates trixie ${TEMPMOUNT_BASE} http://deb.debian.org/debian
	~~~

### Enter the chroot

- Mount the ESP after ZFS, so `/boot/efi` isn't hidden. Then bind the live system's runtime folders, and copy in the hostid and variables:

	~~~bash
	T=${TEMPMOUNT_BASE}
	mkdir -p $T/boot/efi && mount -o noatime UUID=${uefiUUID} $T/boot/efi
	for d in dev proc sys run dev/pts; do mkdir -p $T/$d; mount --bind /$d $T/$d; done
	mount -t efivarfs efivarfs $T/sys/firmware/efi/efivars 2>/dev/null
	cp /etc/hostid $T/etc/hostid
	cp /root/tkz-vars.sh $T/root/
	chroot $T /bin/bash --login
	~~~

- Inside the chroot, load the variables:

	~~~bash
	source /root/tkz-vars.sh; export DEBIAN_FRONTEND=noninteractive
	~~~

- The rest of this section runs inside the chroot. Any time you open a new shell, check which system you're in before running anything. `hostname -f` and `findmnt /` tell you quickly.

### Configure the base system

- Hostname, apt sources, and a rule against auto-removing old kernels. On root-on-ZFS, an older kernel is sometimes the only one a ZFS module has been built for.

	~~~bash
	echo "${newHostname}" > /etc/hostname
	printf "127.0.0.1\tlocalhost\n127.0.1.1\t%s\n::1\tlocalhost ip6-localhost ip6-loopback\n" ${newHostname} > /etc/hosts
	cat > /etc/apt/sources.list <<'EOF'
	deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
	deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
	deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
	deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
	EOF
	printf 'APT::NeverAutoRemove { "linux-image-.*"; "linux-headers-.*"; };\n' > /etc/apt/apt.conf.d/99-no-autoremove-kernels
	apt update
	~~~

- Locale, time zone and keyboard. Pick your own in the menus:

	~~~bash
	apt install -y console-setup keyboard-configuration
	dpkg-reconfigure locales tzdata keyboard-configuration console-setup
	~~~

### Install the kernel, ZFS and boot tools

- Make the MOK signing key first. DKMS signs `zfs.ko` with it when ZFS gets installed, which is what lets ZFS load once Secure Boot is on. One key per install. Keep `/etc/mok/mok.key` private; it can sign anything your firmware will trust.

	~~~bash
	install -d -m 700 /etc/mok
	openssl req -newkey rsa:4096 -nodes -keyout /etc/mok/mok.key -new -x509 -sha256 -days 36500 -subj "/CN=${mUID} MOK Signing Key/" -out /etc/mok/mok.crt
	openssl x509 -in /etc/mok/mok.crt -out /etc/mok/mok.der -outform DER
	chmod 600 /etc/mok/mok.key
	mkdir -p /etc/dkms/framework.conf.d
	printf 'mok_signing_key=/etc/mok/mok.key\nmok_certificate=/etc/mok/mok.der\n' > /etc/dkms/framework.conf.d/tkz-mok.conf
	~~~

- Install dracut before the kernel. If the kernel goes in first, it pulls in `initramfs-tools`, and that will break a ZFS root. Never let `initramfs-tools` back in as a dependency later, either.

	~~~bash
	apt install -y dracut dracut-core dracut-network
	echo "INITRAMFS=dracut" > /etc/kernel-img.conf
	printf 'layout=other\nBOOT_ROOT=/boot/efi\n' > /etc/kernel/install.conf
	apt install -y linux-image-amd64 linux-headers-amd64
	~~~

	`layout=other` stops `kernel-install` from copying plain kernels and initrds to the ESP. Only the signed UKIs go there.

- Mask the iSCSI and NFS client units. `dracut-network` recommends `open-iscsi` and `nfs-common`, so apt installs them, and nothing here uses either. With no network, `open-iscsi.service` holds the login prompt for about 2 minutes while it waits for one. The initrd already leaves both out. `systemctl unmask` undoes it.

	~~~bash
	systemctl mask open-iscsi.service iscsid.service iscsid.socket iscsiuio.service \
		nfs-client.target nfs-blkmap.service nfs-idmapd.service rpc-statd.service rpc-statd-notify.service \
		rpc-gssd.service rpc-svcgssd.service rpcbind.service rpcbind.socket
	~~~

- Install everything else. The firmware packages cover Intel, AMD and Nvidia graphics, and common Wi-Fi and Ethernet chips.

	~~~bash
	apt install -y zfs-dkms zfsutils-linux zfs-dracut zfs-auto-snapshot cryptsetup cryptsetup-bin lvm2 \
		systemd-boot systemd-boot-efi shim-signed mokutil sbsigntool efibootmgr dosfstools \
		firmware-linux firmware-linux-nonfree firmware-misc-nonfree firmware-amd-graphics firmware-intel-graphics \
		firmware-iwlwifi firmware-realtek intel-microcode amd64-microcode \
		openssh-server systemd-resolved sudo parallel moreutils bsdextrautils psmisc lsof rsync \
		gdisk parted rng-tools-debian xxd curl git nano tmux
	apt purge -y mdadm; apt autoremove -y
	~~~

	`mdadm` comes in as a dependency, and can hang the boot before ZFS loads, so it goes right back out.

- Check the results. `zfs.ko` should be signed by your MOK key, and `initramfs-tools` shouldn't be installed:

	~~~bash
	for k in /lib/modules/*/updates/dkms/zfs.ko*; do echo "$k: $(modinfo -F signer $k)"; done
	dpkg -l initramfs-tools mdadm 2>&1 | grep ^ii || echo "OK: neither installed"
	~~~

- Installing systemd-boot also put a plain kernel entry on the ESP. Remove it:

	~~~bash
	rm -rf /boot/efi/$(cat /etc/machine-id) /boot/efi/loader/entries/*.conf
	rm -f /etc/dracut.conf.d/*mdadm*.conf /etc/dracut.conf.d/*mdraid*.conf
	~~~

### Configure dracut and the UKI command line

- The dracut config. `hostonly=no` builds a generic initrd, so the drive still boots after it moves to other hardware.

	~~~bash
	cat > /etc/dracut.conf.d/00-tkz-generic.conf <<'EOF'
	## Generic initrd, so the drive boots on other hardware. hostonly=yes can leave out what ZFS root needs.
	hostonly=no
	hostonly_cmdline=no
	use_fstab=no

	## LUKS, LVM, ZFS
	add_dracutmodules+=' crypt lvm zfs '
	force_dracutmodules+=' crypt lvm zfs '
	install_items+=' /sbin/cryptsetup /sbin/lvm /sbin/vgchange /sbin/zpool /sbin/zfs '

	## USB key unlock reads an ext4 stick
	add_drivers+=' ext4 '

	## NICs for SSH unlock. Wi-Fi isn't usable this early.
	add_drivers+=' virtio_net virtio_pci e1000 e1000e igb igc ixgbe atlantic tg3 bnx2 bnx2x i40e ice iavf r8169 '

	## GPU drivers stay out. The unlock prompt uses the firmware framebuffer (efifb), which works the
	## same on Intel, AMD and Nvidia. The real driver loads from the root filesystem after switch-root.
	omit_dracutmodules+=' plymouth '
	omit_drivers+=' i915 xe amdgpu radeon nouveau nvidia nvidia_drm nvidia_modeset nvidia_uvm '

	## Not booting over a SAN or NFS. (The nfs module mounts rpc_pipefs under /var/lib before the real /var/lib is mounted.)
	omit_dracutmodules+=' iscsi nfs '

	## mdadm/mdraid hangs boot before ZFS loads
	omit_dracutmodules+=' mdraid mdraid-cleanup '
	omit_drivers+=' raid0 raid1 raid10 raid456 '
	EOF
	printf '## Keep initrd in /boot, not /boot/<machine-id>/\nmachine_id=no\n' > /etc/dracut.conf.d/zz-overrides.conf
	~~~

- The kernel command line that gets baked into every UKI. `tkz_rebuild-uki` strips the comments and blank lines.

	~~~bash
	cat > /etc/kernel/uki-cmdline.conf <<EOF
	## Kernel command line baked into each UKI by tkz_rebuild-uki. Comments and blank lines are stripped.

	## LUKS (discard lets ZFS autotrim reach the SSD)
	rd.luks.name=${luksUUID}=crypt_${mUID}
	rd.luks.options=discard

	## LVM
	rd.lvm.lv=vg_${mUID}/lv_rpool_${mUID}
	rd.lvm.lv=vg_${mUID}/lv_swap_${mUID}

	## ZFS root
	root=ZFS=rpool_${mUID}/deb/ROOT

	## Network, for SSH unlock
	ip=dhcp
	rd.neednet=1
	rd.net.timeout.dhcp=15
	rd.net.timeout.carrier=5

	## Console
	consoleblank=0
	quiet
	loglevel=3

	## Performance
	mitigations=off
	init_on_alloc=0

	## zswap
	zswap.enabled=1
	zswap.compressor=zstd
	zswap.zpool=zsmalloc
	zswap.max_pool_percent=33

	## Debugging
	#rd.break=pre-mount
	EOF
	~~~

	`mitigations=off` trades CPU side-channel protection for speed. Delete that line if the machine runs code you don't trust.

- Get this repo into the chroot, then install the UKI rebuild script and its kernel hook. The hook's `zz-` prefix keeps it running after `dkms` has built `zfs.ko` for a new kernel.

	~~~bash
	git clone --depth 1 https://github.com/t00mietum/tukzedo-linux /root/tkz-repo
	R=/root/tkz-repo/filesystem/debian_13
	install -o root -g root -m 0755 $R/usr/local/sbin/tkz_rebuild-uki /usr/local/sbin/
	install -o root -g root -m 0755 $R/etc/kernel/postinst.d/zz-rebuild-uki /etc/kernel/postinst.d/
	~~~

- Add a small dracut module that puts root's real password hash into the initrd. Without it, Debian's dracut 106 writes a locked root entry there, and both the emergency shell and SSH unlock refuse root.

	~~~bash
	mkdir -p /usr/lib/dracut/modules.d/99fix-shadow
	cat > /usr/lib/dracut/modules.d/99fix-shadow/module-setup.sh <<'EOF'
	#!/bin/bash
	## Copy root's real shadow entry into the initrd, so the emergency shell and dracut-sshd accept root.
	check() { return 0; }
	depends() { return 0; }
	install() {
		local shadow_entry
		shadow_entry=$(grep '^root:' /etc/shadow)
		if [[ -n "$shadow_entry" ]]; then
			sed -i "s|^root:.*|${shadow_entry}|" "${initdir}/etc/shadow" 2>/dev/null || true
		fi
	}
	EOF
	chmod 755 /usr/lib/dracut/modules.d/99fix-shadow/module-setup.sh
	~~~

### Set up USB key unlock

The dracut module is installed now. The USB stick itself gets made later, in [Make the USB key](#make-the-usb-key). Until then the module waits 10 seconds for a stick at each boot, finds none, and moves on to the passphrase prompt.

- Install the module and its per-machine config:

	~~~bash
	cp -r $R/usr/lib/dracut/modules.d/99usb-unlock /usr/lib/dracut/modules.d/
	install -d -m 755 /etc/tukzedo
	sed -e "s/^LUKS_UUID=.*/LUKS_UUID=\"${luksUUID}\"/" -e "s/^LUKS_NAME=.*/LUKS_NAME=\"crypt_${mUID}\"/" \
		-e "s|^KEYFILE_PATH=.*|KEYFILE_PATH=\".keys/${mUID}.hex\"|" \
		$R/etc/tukzedo/usb-unlock.conf > /etc/tukzedo/usb-unlock.conf
	cat /etc/tukzedo/usb-unlock.conf
	~~~

### Set up SSH unlock

- Install `dracut-sshd`, pinned to a release. 0.7.0 or newer is needed for Debian 13, whose OpenSSH 10 splits `sshd` into helper programs the older releases don't copy into the initrd.

	~~~bash
	git -c advice.detachedHead=false clone --branch 0.7.1 --depth 1 https://github.com/gsauthof/dracut-sshd.git /usr/local/src/dracut-sshd
	cp -r /usr/local/src/dracut-sshd/46sshd /usr/lib/dracut/modules.d/
	~~~

- Give the initrd its own SSH host keys. A UKI sits unencrypted on the ESP, so anyone with the drive in hand can read what's in it. The main system's host keys must never go in there.

	~~~bash
	for t in ed25519 ecdsa rsa; do ssh-keygen -q -t $t -N '' -C "initrd-${newHostname}" -f /etc/ssh/dracut_ssh_host_${t}_key; done
	~~~

- Add the public keys allowed to unlock over SSH. They can log in as root, both in the initrd and in the running system.

	~~~bash
	install -d -m 700 /root/.ssh
	nano /root/.ssh/authorized_keys   ## Paste your workstation's public key(s)
	chmod 600 /root/.ssh/authorized_keys; touch /root/.ssh/known_hosts
	~~~

### Set up fstab, ZFS services and the network

- `/etc/fstab` only has the ESP and swap. ZFS mounts everything else.

	~~~bash
	cat > /etc/fstab <<EOF
	## ESP mounts after the pools import, so /boot/efi isn't shadowed.
	UUID=${uefiUUID}  /boot/efi  vfat  defaults,noatime,umask=0077,x-systemd.after=zfs-import.target  0 2
	UUID=${swapUUID}  none       swap  sw  0 0
	EOF
	~~~

- Import pools by scanning, never from a cache file:

	~~~bash
	systemctl enable zfs-import-scan.service zfs-mount.service zfs.target zfs-import.target
	systemctl mask zfs-import-cache.service
	rm -f /etc/zfs/zpool.cache
	~~~

- Wired network through systemd-networkd, so SSH works on first boot. Desktop network tools and Wi-Fi can come later.

	~~~bash
	printf '[Match]\nType=ether\nName=en* eth*\n\n[Network]\nDHCP=yes\n' > /etc/systemd/network/20-wired.network
	systemctl enable systemd-networkd systemd-resolved ssh
	~~~

### Create users

- Set a root password. Save it in your password manager. It's also what the emergency shell asks for if a boot goes wrong.

	~~~bash
	passwd root
	~~~

- Create each user. A user with an encrypted home must get the same password their home dataset was given above.

	~~~bash
	u=alice
	useradd -m -d /home/$u -s /bin/bash -G sudo,adm,audio,video,plugdev,users $u   ## Drop sudo,adm for non-admins
	passwd $u
	cp -rn /etc/skel/. /home/$u/; chown -R $u:$u /home/$u; chmod 750 /home/$u
	for c in .cache tmp var; do chown $u:$u /home/$u/$c; chmod 700 /home/$u/$c; done   ## Encrypted homes only
	~~~

	`useradd -m` doesn't copy `/etc/skel` into a folder that already exists, which these do, because they're mounted datasets. The `cp -rn` does that part.

### Lay out the ESP and build the first UKI

- Put shim at the firmware's fallback path, `EFI/BOOT/BOOTX64.EFI`. Shim is signed by Microsoft, so firmware trusts it even with Secure Boot on and no boot entries in NVRAM. That's the state of a brand-new machine, or one whose NVRAM was reset. Shim then loads `grubx64.efi` from its own folder, and `tkz_rebuild-uki` signs systemd-boot into that file name.

	~~~bash
	E=/boot/efi/EFI; SB=/usr/lib/systemd/boot/efi/systemd-bootx64.efi
	[[ -f $E/systemd/systemd-bootx64.efi ]] || bootctl install --no-variables
	mkdir -p $E/debian $E/BOOT $E/Linux
	for d in debian BOOT; do cp /usr/lib/shim/mmx64.efi.signed $E/$d/mmx64.efi; cp $SB $E/$d/grubx64.efi; done
	cp /usr/lib/shim/shimx64.efi.signed $E/debian/shimx64.efi
	cp /usr/lib/shim/shimx64.efi.signed $E/BOOT/BOOTX64.EFI
	printf 'timeout 5\nconsole-mode keep\neditor no\n' > /boot/efi/loader/loader.conf
	~~~

	`editor no` turns off editing the kernel command line at the boot menu, so that way it can't be changed there.

- Build and sign the UKI:

	~~~bash
	tkz_rebuild-uki --all
	~~~

	- It checks the config first, then lists required pieces found inside the UKI. Every count should be 1 or more.
	- Then it signs the UKI and the 3 systemd-boot copies, and makes the second-newest kernel the default once there are 2.

- Check the ESP, the signature, and that no GPU driver got into the UKI:

	~~~bash
	find /boot/efi -type f | sort; df -h /boot/efi
	U=$(ls /boot/efi/EFI/Linux/debian-*.efi | tail -1)
	sbverify --cert /etc/mok/mok.crt "$U"
	lsinitrd "$U" 2>/dev/null | grep -c -E '/(i915|amdgpu|nouveau|radeon|xe)\.ko'   ## Want 0
	lsinitrd -f etc/hostid "$U" 2>/dev/null | od -An -tx1                         ## Want your hostid, bytes reversed
	~~~

### First boot

- Leave the chroot, and snapshot the fresh install. `@base-install` is a rollback point if a later step goes badly.

	~~~bash
	exit
	source /root/tkz-vars.sh; T=${TEMPMOUNT_BASE}
	zfs snapshot -r rpool_${mUID}@base-install
	~~~

- Unmount everything, export the pool, and close LUKS. Encrypted homes are `canmount=noauto`, so `zfs unmount -a` skips them, and they have to be unmounted by name first.

	~~~bash
	umount $T/sys/firmware/efi/efivars 2>/dev/null
	for d in dev/pts dev proc sys run boot/efi; do umount -l $T/$d; done
	for d in $(zfs list -H -o name,keystatus -r rpool_${mUID} | awk '$2=="available"{print $1}' | sort -r); do zfs unmount $d 2>/dev/null; done
	zfs list -H -o name,encryptionroot -r rpool_${mUID} | awk '$1==$2{print $1}' | xargs -rn1 zfs unload-key
	zfs unmount -a; zfs unmount rpool_${mUID}/deb/ROOT 2>/dev/null
	zpool export rpool_${mUID}
	vgchange -an vg_${mUID}; cryptsetup close crypt_${mUID}
	~~~

- Shut the VM down. In its settings, remove the ISO, and make the target disk the first boot device. Then start it.

- At boot:
	- systemd-boot shows the UKI for 5 seconds.
	- `usb-unlock` waits 10 seconds for a USB key, then prints the network address.
	- The LUKS passphrase prompt appears.

- Unlock at the console, or over SSH from your working system:

	~~~bash
	ssh root@<address-shown>
	systemd-tty-ask-password-agent
	~~~

	The SSH session logs into the initrd, not the real system. It uses the initrd's own host keys, so SSH warns that they differ from the real system's. That's expected; keep the 2 apart in `known_hosts`.

- Log in as root over SSH, and check:

	~~~bash
	source /root/tkz-vars.sh
	systemctl --failed
	findmnt -n -o SOURCE /; findmnt /boot/efi; swapon --show
	zpool status -x; hostid
	zfs list -o name,mounted,keystatus -r rpool_${mUID}/deb/persist/home
	~~~

	Encrypted homes show `mounted no` and `keystatus unavailable` until their user logs in.

### Mount ZFS datasets from systemd units

`zfs-mount.service` mounts datasets with `zfs mount -a`, which systemd can't see into. Units that need a folder under `/var/lib` can then run before `/var/lib` is mounted, and write into the root dataset underneath it. `systemd-random-seed` is one that does. The OpenZFS mount generator fixes it. ZED keeps a list of datasets, and the generator turns each one into a real systemd mount unit, so normal mount ordering applies.

- Turn the list on, and make ZED fill it by touching a property:

	~~~bash
	source /root/tkz-vars.sh
	mkdir -p /etc/zfs/zfs-list.cache; touch /etc/zfs/zfs-list.cache/rpool_${mUID}
	zfs set canmount=noauto rpool_${mUID}/deb/ROOT
	sleep 3; wc -l /etc/zfs/zfs-list.cache/rpool_${mUID}   ## Want one line per dataset
	systemctl daemon-reload
	ls /run/systemd/generator/*.mount
	~~~

	Encrypted homes shouldn't be in that list of mount units. They have `org.openzfs.systemd:ignore=on` for this, and get mounted at login instead.

- Check whether anything was already written under a mountpoint in the root dataset. A non-recursive bind of `/` shows the root dataset alone, with nothing mounted on top:

	~~~bash
	mkdir -p /run/rootpeek && mount --bind / /run/rootpeek
	for d in var/lib var/mail var/www var/spool var/tmp home opt root srv usr/local etc/opt tmp; do
		n=$(ls -A /run/rootpeek/$d 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "$d: $(ls -A /run/rootpeek/$d | tr '\n' ' ')"
	done
	~~~

	If anything shows up, look at it, then delete it from inside `/run/rootpeek`, never from the real path. Then reboot, and check again. When the list stays empty:

	~~~bash
	umount /run/rootpeek && rmdir /run/rootpeek
	~~~

### Set up encrypted-home mounting at login

The login script unlocks and mounts a user's encrypted home when they log in, using the password they typed. A watchdog locks it again after their last session ends.

- Install the scripts and units:

	~~~bash
	cd /root/tkz-repo/filesystem/debian_13
	install -o root -g root -m 0755 usr/local/sbin/tkz_zfs-mount usr/local/sbin/tkz_zfs-crypthome_login usr/local/sbin/tkz_zfs-crypthome_logout-watchdog /usr/local/sbin/
	install -o root -g root -m 0644 etc/systemd/system/tkz-zfs-crypthome-logout-watchdog.service etc/systemd/system/tkz-zfs-crypthome-logout-watchdog.timer etc/systemd/system/tkz-zfs-mount-audit.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable --now tkz-zfs-crypthome-logout-watchdog.timer
	~~~

- The boot-time audit keeps every mountpoint folder empty and immutable, so nothing gets written into one while it's unmounted. Run it dry first, and read what it would move:

	~~~bash
	tkz_zfs-mount --audit-all --dry-run
	~~~

	It should only list `chattr +i` lines. If it wants to move anything, find out what it is first. Then enable it:

	~~~bash
	systemctl enable --now tkz-zfs-mount-audit.service
	~~~

- Hook the login script into PAM. Back up both files, and keep a root shell open until a fresh login works. With `requisite`, a missing or broken script blocks every password login, root's included.

	~~~bash
	d=$(date +%Y%m%d); cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak-$d; cp /etc/pam.d/common-session /etc/pam.d/common-session.bak-$d
	sed -i '/pam_deny.so/a ## ZFS encrypted home\nauth\trequisite\t\t\tpam_exec.so expose_authtok quiet  /usr/local/sbin/tkz_zfs-crypthome_login' /etc/pam.d/common-auth
	sed -i '/pam_systemd.so/a session [success=1 default=ignore]\tpam_succeed_if.so quiet service in cron:sudo:sudo-i:cups:samba\nsession optional\t\t\tpam_exec.so quiet type=close_session /usr/bin/systemctl start --no-block tkz-zfs-crypthome-logout-watchdog.service' /etc/pam.d/common-session
	grep -v '^#' /etc/pam.d/common-auth | grep .
	~~~

	The `pam_exec` auth line must come after `pam_deny.so` and before `pam_permit.so`.

- Test with a password login from another machine. The home should be mounted while logged in, and locked a few seconds after logout:

	~~~bash
	ssh -o PubkeyAuthentication=no alice@<address> 'findmnt -n -o SOURCE $HOME'
	zfs get -H -o value mounted,keystatus rpool_${mUID}/deb/persist/home/alice   ## As root, after logout: "no unavailable"
	journalctl -t tkz_zfs-crypthome_login -t tkz_zfs-crypthome_logout-watchdog -n 20
	~~~

- The watchdog locks a logged-out user's home even if root unlocked it on purpose. To stop that for one user, use `tkz_user hold`, under [Add and manage users](#add-and-manage-users).

- When a user changes their password, their home's ZFS key has to change to match, or their next login fails. Until a script handles both together, do the 2 steps by hand while they're logged in:

	~~~bash
	passwd alice
	zfs change-key -o keyformat=passphrase rpool_${mUID}/deb/persist/home/alice   ## Same new password
	~~~

### Boot-time helpers and tunables

- Install the startup logger, the ESP mount safety net, and the tunables tool:

	~~~bash
	cd /root/tkz-repo/filesystem/debian_13
	install -o root -g root -m 0755 usr/local/sbin/tkz_startup-log usr/local/sbin/tkz_show-startup-log usr/local/sbin/tkz_insure-efi-mount usr/local/sbin/tkz_apply-tunables /usr/local/sbin/
	install -o root -g root -m 0644 etc/systemd/system/tkz-insure-efi-mount.service etc/systemd/system/tkz-apply-tunables.service /etc/systemd/system/
	install -o root -g root -m 0644 etc/tukzedo/tunables.conf /etc/tukzedo/tunables.conf
	systemctl show boot-efi.mount -p LoadState --value   ## Want 'loaded', not 'masked'
	systemctl daemon-reload
	systemctl enable tkz-insure-efi-mount.service tkz-apply-tunables.service
	tkz_insure-efi-mount --check
	~~~

- Set the tunables for this machine. `zfs_arc_max` should scale with RAM; the file has a table. Then generate the native config files, and rebuild the UKI so module settings reach early boot:

	~~~bash
	nano /etc/tukzedo/tunables.conf
	tkz_apply-tunables --emit-native
	sysctl --system
	udevadm control --reload && udevadm trigger --subsystem-match=block --action=change
	systemctl start tkz-apply-tunables.service
	tkz_rebuild-uki --all
	tkz_apply-tunables --check
	~~~

	`--emit-native` prints a line for any setting that has to go on the kernel command line instead, such as `zswap.max_pool_percent`. Add those to `/etc/kernel/uki-cmdline.conf`, and rebuild again.

- Take a second snapshot, now that the system is set up:

	~~~bash
	zfs snapshot -r rpool_${mUID}@configured
	~~~

### Keep systemd-boot signed after upgrades

When the `systemd-boot` package is upgraded, it runs `bootctl update`. That replaces every copy of systemd-boot it recognizes with the new, unsigned build, and it recognizes the `grubx64.efi` copies that shim loads. With Secure Boot on, the next boot then fails. `tkz_rebuild-uki` re-signs them, but it only runs on kernel upgrades.

- Install an apt hook that re-signs them after every package run. It only acts when a signature is missing or wrong:

	~~~bash
	cd /root/tkz-repo/filesystem/debian_13
	install -o root -g root -m 0755 usr/local/sbin/tkz_resign-sdboot /usr/local/sbin/
	install -o root -g root -m 0644 etc/apt/apt.conf.d/99-tkz-resign-sdboot /etc/apt/apt.conf.d/
	tkz_resign-sdboot && echo OK
	~~~

### Turn on Secure Boot

Do this part on the machine the drive will live in, since the MOK enrollment is stored in that machine's firmware. An enrollment done in the VM doesn't count for the real machine.

- Make shim the first firmware boot entry. Installing systemd-boot created a "Linux Boot Manager" entry that skips shim. With Secure Boot on, firmware won't run that one. Later `bootctl update` runs may add it back, but at the end of the boot order, which is fine.

	~~~bash
	efibootmgr
	disk=/dev/$(lsblk -no PKNAME $(findmnt -no SOURCE /boot/efi))
	for n in $(efibootmgr | awk '/Linux Boot Manager|Tukzedo/ {print substr($1,5,4)}'); do efibootmgr -b $n -B; done
	efibootmgr --create --disk $disk --part 1 --label "Tukzedo (shim)" --loader '\EFI\debian\shimx64.efi'
	efibootmgr
	~~~

	With no boot entries at all, firmware falls back to `EFI/BOOT/BOOTX64.EFI`, which is also shim. So the drive still boots in a machine that has never seen it.

- Ask shim to enroll your MOK certificate at the next boot. It asks for a one-time password, which you type once more at the enrollment screen. Something short is fine; it isn't needed again.

	~~~bash
	mokutil --sb-state
	mokutil --import /etc/mok/mok.der
	reboot
	~~~

	If `mokutil` says the system doesn't support Secure Boot, the firmware has no Secure Boot at all, and there's nothing to do here.

- At the blue MokManager screen, press a key within 10 seconds. Then choose `Enroll MOK`, `Continue`, `Yes`, type the one-time password, and choose `Reboot`.

- Unlock and log in, and check the key is enrolled:

	~~~bash
	mokutil --list-enrolled | grep -i 'subject:.*mok'
	~~~

- Reboot into the firmware setup, and turn Secure Boot on. Then boot, unlock, and check that ZFS still loaded:

	~~~bash
	mokutil --sb-state                     ## Want "SecureBoot enabled"
	dmesg | grep -i 'locked down'          ## The kernel locks itself down under Secure Boot
	lsmod | grep -c '^zfs'                 ## Want 1. If 0, zfs.ko isn't signed with your MOK
	zpool status -x
	~~~

### Make the USB key

The key can be a random file on a dedicated stick, or any file that already sits on a stick you carry, such as one photo among many. A file that's already there doesn't stand out, and the stick stays usable for other things.

- Whatever file you pick, its bytes must never change. Editing, rotating or re-saving it, or a photo app rewriting its metadata, breaks the key. Make it read-only, and don't keep it anywhere it might get "fixed".

- Every copy of the file is a copy of the key. That includes photo backups and cloud photo libraries.

- The passphrase still works without the stick, so losing the stick doesn't lock you out.

The stick can be ext4, FAT or exFAT. Plug it into the machine you're working on.

- Find the stick's filesystem UUID. That's the `UUID`, not the `PARTUUID`:

	~~~bash
	lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINTS
	~~~

- Either pick an existing file on it, or make a new random one. For a new one on an empty stick:

	~~~bash
	mount /dev/disk/by-uuid/<stick-uuid> /mnt
	mkdir -p /mnt/.keys && openssl rand -hex 256 > /mnt/.keys/${mUID}.hex
	~~~

- Add the file as a LUKS keyslot. It asks for your current LUKS passphrase. cryptsetup reads at most 8 MiB of a key file by default. For a bigger file, add `--keyfile-size=4194304` here, and set `KEYFILE_SIZE=4194304` in the config below.

	~~~bash
	source /root/tkz-vars.sh
	keyFile=/mnt/PHOTOS/IMG_1234.JPG          ## Or /mnt/.keys/${mUID}.hex
	cryptsetup luksAddKey --pbkdf argon2id /dev/disk/by-uuid/${luksUUID} "$keyFile"
	cryptsetup open --test-passphrase --key-file "$keyFile" /dev/disk/by-uuid/${luksUUID} && echo "Key works"
	~~~

- Point the config at the stick and file. `KEYFILE_PATH` is relative to the stick's root.

	~~~bash
	nano /etc/tukzedo/usb-unlock.conf    ## USB_UUID, KEYFILE_PATH, and KEYFILE_SIZE if used
	tkz_rebuild-uki --all
	umount /mnt
	~~~

- Reboot with the stick in. The machine should go straight past the passphrase prompt. Then reboot without it: after 10 seconds, the passphrase prompt appears as usual.

- Save in your password manager which stick and which file it is, and that it's in LUKS keyslot 2 or whichever `luksDump` shows.

### Add and manage users

`tkz_user` creates users whose home is its own dataset, plain or encrypted. It also keeps an encrypted home's ZFS key in step with the login password. Plain `passwd` doesn't do that, so the next login would fail to unlock the home.

- Install it:

	~~~bash
	install -o root -g root -m 0755 /root/tkz-repo/filesystem/debian_13/usr/local/sbin/tkz_user /usr/local/sbin/
	~~~

- Add a user with an encrypted home, or a plain one:

	~~~bash
	tkz_user add alice --encrypt          ## Add --admin for sudo
	tkz_user add guest
	~~~

- Change a password. For an encrypted home, this changes the ZFS key too. If the user is logged out, it asks for the current password first, to unlock the home's key.

	~~~bash
	tkz_user passwd alice
	~~~

	Loading a logged-out user's key by hand doesn't get around that prompt, unless the user is held first, as below. Otherwise the logout watchdog locks it again the next time any session closes.

- Keep the logout watchdog away from a user's home, for example to work in it as root while they're logged out. A held user's home stays as it is, unlocked or not, until you release them or the box reboots. If a watchdog run is going, `hold` waits for it to finish.

	~~~bash
	tkz_user hold alice
	tkz_user release alice
	~~~

- Move an existing plain home into a new encrypted dataset. The user has to be logged out, with nothing of theirs still running. Their files are copied over, and the old home is kept under a new name until you delete it. If it fails partway, it puts back the old home and password. A `~/.cache`, `~/tmp` or `~/var` that's a symlink stays a symlink, and doesn't get its own dataset.

	~~~bash
	tkz_user migrate guest
	~~~

- See every home dataset, and whether it's encrypted, unlocked and mounted. Held users are listed below the table:

	~~~bash
	tkz_user status
	~~~

### Move the drive to its machine

Up to here, everything ran in the VM. If the target is the machine's own internal drive, you're booting it directly now.

- In the running system, take out any SSH keys that were only for the build, then rebuild the UKI. The initrd has its own copy of `authorized_keys`.

	~~~bash
	nano /root/.ssh/authorized_keys
	tkz_rebuild-uki --all
	~~~

- Shut the VM down, and make sure it stays down. Two systems must never run from the same drive at once.

	~~~bash
	sudo virsh shutdown tkz-build
	sudo virsh autostart --disable tkz-build 2>/dev/null
	~~~

- Reboot the machine, open its one-time boot menu (often F12), and pick the internal drive. Firmware that hasn't seen this drive before boots `EFI/BOOT/BOOTX64.EFI`, which is shim, so it works with no boot entries.

- Unlock, log in as root, and run the checks from [First boot](#first-boot) again. Then add the shim boot entry, and turn on Secure Boot as in [Turn on Secure Boot](#turn-on-secure-boot). The MOK enrollment from the VM doesn't carry over; it lives in each machine's firmware.

- The network setup so far only covers wired Ethernet. Wi-Fi is a later step. The desktop is next.

### Install the desktop

The desktop is LXQt on the Wayfire compositor, with SDDM as the login screen. Everything here runs as root on the new system.

- Install the packages without Recommends. Plain `apt install lxqt` pulls in about 1,600 packages, all of KDE Plasma, Firefox and Thunderbird among them. This list is about 330.

	~~~bash
	apt install --no-install-recommends lxqt-core lxqt-qtplugin lxqt-config lxqt-themes pcmanfm-qt qterminal \
		lximage-qt featherpad wayfire xwayland xdg-desktop-portal-wlr xdg-desktop-portal-lxqt sddm qt6-wayland \
		breeze-icon-theme fonts-dejavu-core
	~~~

- Build LXQt's Wayland session launcher. Debian 13 doesn't package `lxqt-wayland-session`, so without it LXQt only has an X11 session. Release 0.1.1 matches the LXQt 2.1 in Debian 13; later releases need a later LXQt. Once Debian packages it, use the package instead.

	~~~bash
	apt install --no-install-recommends git ca-certificates cmake make g++ pkg-config lxqt-build-tools liblxqt-dev \
		xdg-user-dirs qt6-l10n-tools qt6-tools-dev libxkbcommon-dev libkf6windowsystem-dev
	mkdir -p /usr/local/src && cd /usr/local/src
	git clone --depth 1 --branch 0.1.1 https://github.com/lxqt/lxqt-wayland-session.git
	cd lxqt-wayland-session
	cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release
	cmake --build build && cmake --install build
	~~~

- Add the "LXQt (Wayfire)" login session, and remove upstream's "LXQt (Wayland)" one. Upstream's starts labwc to ask for a compositor when a user hasn't picked one, and labwc isn't installed. `tkz_startlxqt-wayfire` sets Wayfire for such a user, then starts the same launcher. A compositor picked later in LXQt Session Settings is kept.

	~~~bash
	git -C /root/tkz-repo pull --ff-only
	cd /root/tkz-repo/filesystem/debian_13
	install -o root -g root -m 0755 usr/local/bin/tkz_startlxqt-wayfire /usr/local/bin/
	install -o root -g root -m 0644 usr/local/share/wayland-sessions/tkz-lxqt-wayfire.desktop /usr/local/share/wayland-sessions/
	rm /usr/local/share/wayland-sessions/lxqt-wayland.desktop
	~~~

	`cmake --install` puts the upstream file back, so remove it again after any rebuild.

- Give the login screen a theme. With none installed, SDDM shows a plain built-in one. Elarun is a single small package; the usual Breeze theme pulls in about 350 packages of KDE Plasma.

	~~~bash
	apt install --no-install-recommends sddm-theme-elarun
	mkdir -p /etc/sddm.conf.d
	printf '[Theme]\nCurrent=elarun\n' > /etc/sddm.conf.d/tkz-theme.conf
	~~~

- Start the login screen, or reboot. Pick "LXQt (Wayfire)" from the session menu before logging in.

	~~~bash
	systemctl start sddm
	~~~

### Change passphrases later

- LUKS. Add the new passphrase, test it, then remove the old keyslot. `luksKillSlot` asks for any passphrase that stays.

	~~~bash
	source /root/tkz-vars.sh; dev=/dev/disk/by-uuid/${luksUUID}
	cryptsetup luksDump $dev | grep -E '^ +[0-9]+: luks2'
	cryptsetup luksAddKey $dev
	cryptsetup open --test-passphrase $dev
	cryptsetup luksKillSlot $dev <old-slot-number>
	~~~

- A user with an encrypted home: `tkz_user passwd <user>`. Anyone else: `passwd <user>`.

- After changing root's password, rebuild the UKI with `tkz_rebuild-uki --all`. The initrd keeps a copy of root's password hash, for the emergency shell.

### Get back in from a live system

If it won't boot, start the VM, or the machine, from the live ISO. Then follow [Prepare the live environment](#prepare-the-live-environment), and copy `/root/tkz-vars.sh` back in from wherever you saved it.

- Open everything without letting ZFS mount on top of the live system. Mount `/` first, then the rest, then the ESP:

	~~~bash
	source /root/tkz-vars.sh
	zgenhostid -f ${zfsHostID}
	cryptsetup open --allow-discards /dev/disk/by-uuid/${luksUUID} crypt_${mUID}
	vgchange -ay vg_${mUID}
	zpool import -N -R ${TEMPMOUNT_BASE} rpool_${mUID}
	zfs mount rpool_${mUID}/deb/ROOT
	zfs mount -a
	mount -o noatime UUID=${uefiUUID} ${TEMPMOUNT_BASE}/boot/efi
	~~~

- Then bind and chroot as in [Enter the chroot](#enter-the-chroot). When done, leave the chroot, and unmount and export as in [First boot](#first-boot). A pool that isn't exported cleanly can still be imported next time, but only with `-f`.

- A snapshot taken before a bad change can be rolled back from here. Roll back `/` and `/var/lib` together, since `/var/lib` has the package database that has to match what's installed on `/`. `-r` also deletes any newer snapshots of that dataset.

	~~~bash
	zfs list -t snapshot -o name,creation -r rpool_${mUID}/deb/ROOT rpool_${mUID}/deb/persist/var_lib
	zfs rollback -r rpool_${mUID}/deb/ROOT@configured
	zfs rollback -r rpool_${mUID}/deb/persist/var_lib@configured
	~~~

### How it boots

- Firmware runs shim, from its boot entry or from `EFI/BOOT/BOOTX64.EFI`. Shim is signed by Microsoft, and it checks the next file against the keys in firmware and the MOK list.

- Shim runs `grubx64.efi`, which is systemd-boot signed with your MOK. systemd-boot lists every UKI in `EFI/Linux/`, and starts the default after 5 seconds. With 2 or more kernels, `tkz_rebuild-uki` makes the second-newest the default, in case a new kernel is ahead of the ZFS module.

- The UKI holds the kernel, the initrd and the command line, all under one signature. Nothing in it can be edited at the boot menu.

- In the initrd:
	- The USB key, the console prompt and SSH unlock all race to open LUKS. Whichever succeeds first wins.
	- Then LVM activates, and the ZFS module imports `rpool_<mUID>` by scanning, using the hostid baked into the initrd.
	- It mounts `rpool_<mUID>/deb/ROOT` on `/sysroot`, and switches root.

- In the real system, systemd mounts the other datasets from the units the ZFS mount generator makes, then the ESP from `/etc/fstab`. GPU drivers load at this point. Encrypted homes stay locked until their user logs in.

### Steps not yet converted

Older notes, still in rough pseudo-bash. View them in the raw .md file.

<!--

#### Install libvirt, Docker, NordVPN

	mainNetDev='enp1s0'

	## Install libvirt
		sudo apt install --no-install-recommends qemu-system-x86 libvirt-daemon-system libvirt-clients virt-manager bridge-utils virt-manager ca-certificates curl gnupg

	## Create bridge definition (in preparation to switch to systemd-network)
		filePath="/etc/systemd/network/10-br0.netdev"  #; sudo nano "${filePath}"
			sudo tee "${filePath}" <<- EOF_1mw1cbt
				[NetDev]
				Name=br0
				Kind=bridge
			EOF_1mw1cbt
			sudo nano "${filePath}"
		filePath="/etc/systemd/network/20-enp1s0.network"  #; sudo nano "${filePath}"
			sudo tee "${filePath}" <<- EOF_1mw1cj1
				[Match]
				Name=${mainNetDev}

				[Network]
				Bridge=br0
			EOF_1mw1cj1
			sudo nano "${filePath}"
		filePath="/etc/systemd/network/30-br0.network"  #; sudo nano "${filePath}"
			## Choose only one of:
				## DHCP
					sudo tee "${filePath}" <<- EOF_1mw2hgt
						[Match]
						Name=br0

						[Network]
						DHCP=yes
						EOF
					EOF_1mw2hgt
					sudo nano "${filePath}"
				## Static IP
					sudo tee "${filePath}" <<- EOF_1mwjqfm
						[Match]
						Name=br0

						[Network]
						Address=192.168.1.123/24
						Gateway=192.168.1.1
						DNS=9.9.9.9 1.1.1.1
					EOF_1mwjqfm
					sudo nano "${filePath}"

	## Switch over to systemd-networkd
		sudo systemctl disable --now NetworkManager
		sudo systemctl disable --now networking
		sudo systemctl enable --now systemd-networkd systemd-resolved
		ip addr show br0

	## Prevent networking problems that Docker causes with libvirt, before installind Docker
		filePath="/etc/sysctl.d/90-bridge-nofilter.conf"  #; sudo nano "${filePath}"
			sudo tee "${filePath}" <<- EOF_1mwncxj
				net.ipv4.ip_forward=1
				net.bridge.bridge-nf-call-iptables=0
				net.bridge.bridge-nf-call-ip6tables=0
			EOF_1mwncxj
			sudo nano "${filePath}"
			sudo sysctl -p "${filePath}"
		filePath="/etc/docker/daemon.json"  #; sudo nano "${filePath}"
			sudo tee "${filePath}" <<- EOF_1mwnrhe
				{
				  "bip": "172.17.0.1/24",
				  "fixed-cidr": "172.17.0.0/24"
				}
			EOF_1mwnrhe
			sudo nano "${filePath}"
		filePath="/etc/modules-load.d/br_netfilter.conf"  #; sudo nano "${filePath}"
			echo br_netfilter | sudo tee "${filePath}"
			sudo nano "${filePath}"

		## Enable br_netfilter and check status
			sudo modprobe br_netfilter
			sudo sysctl -p /etc/sysctl.d/90-bridge-nofilter.conf

	## Install docker (Install Docker Engine, NOT Docker Desktop. The latter uses a VM.)
		## Follow instructions on: https://docs.docker.com/engine/install/debian/#installation-methods

	## Install NordVPN
		curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh | sh
		nordvpn login

	## Add user permissions, and start services
		sudo usermod -aG libvirt  $USER
		sudo usermod -aG kvm      $USER
		sudo usermod -aG docker   $USER
		sudo usermod -aG nordvpn  $USER
		sudo systemctl enable --now libvirtd

	## Either reboot or enter a new shell with updated permissions
		newgrp

	## Test simultaneous connectivity

		## Install bash into Docker:
			docker pull bash ; docker ps -a
			docker run -it bash
				## Then from inside the Docker bash
					ping -4 google.com

		## Create a new TinyCore64 VM, booting to LiveCD:
			http://www.tinycorelinux.net/17.x/x86_64/release/CorePure64-current.iso
			## Then from a terminal:
				ping google.com

		## From a regular host terminal
			ping google.com

		## While that's happening, connect to NordVPN, make sure the pings are still going, including after disconnect.
			nordvpn connect

-->

### Install or update local scripts

These scripts won't necessarily do much good without following an installation guide from the previous section. But you may want to conveniently update your existing local scripts:

- Install or update local Tukzedo scripts for Debian Trixie with latest dev versions:

	~~~bash
	curl -fsSL https://raw.githubusercontent.com/t00mietum/tukzedo-linux/main/install_dev.bash | bash
	~~~

## Document history

- 2026-10-12: Added "Install the desktop": LXQt on Wayfire, with SDDM and a Wayland session built from `lxqt-wayland-session`.

- 2026-10-12: `tkz_user hold` and `release` keep the logout watchdog away from one user's home. The watchdog's and `tkz_zfs-mount`'s locks moved to `/run/tkz`, where other users can't get at them.

- 2026-10-11: Rewrote the procedure as real steps. Grub and bpool are gone, and shim starts systemd-boot from a 4 GiB ESP. Added USB key unlock, SSH unlock with dracut-sshd 0.7.1, the ZFS mount generator, and `tkz_user`.

- 2026-09-07: Logout watchdog: hourly cron job replaced by a systemd timer (5 minutes) plus a PAM close_session hook. Added tkz_zfs-mount (mount helper, immutable mountpoint dirs) and its boot-time audit unit.

- 2026-08-13: Added notes for the encrypted-home auto-mount / logout watchdog (scripts, cron job, PAM hook), and for the boot-time helpers now that they run as systemd units.

- 2026-06-01: Added section "Install or update local scripts"

- 2026-03-31: Template put in Git.

## Copyright and license

> Copyright © 2026 t00mietum (CryptogID: ปʬϝღถɔ4რఠΔթะ9ƾǝu)<br>
> Licensed under The GNU General Public License v2.0 or later <https://spdx.org/licenses/GPL-2.0-or-later.html>. No warranty.

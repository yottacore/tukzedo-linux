<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->
<div align="center">

![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)
![Lifecycle: Alpha](https://img.shields.io/badge/Lifecycle-Alpha-orange)e
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

# How to clone an existing Tukzedo Linux installation on Debian Trixie

This how-to walks you through how to clone an existing Tukzedo Linux installation on Debian Trixie.

<!-- TOC ignore:true -->
## Table of contents

<!-- TOC -->

- [Introduction](#introduction)
- [Warnings - and solutions](#warnings---and-solutions)
- [Cloning steps](#cloning-steps)
	- [Prepare](#prepare)
		- [Map out your landscape](#map-out-your-landscape)
		- [Set up a recovery environment to work in](#set-up-a-recovery-environment-to-work-in)
	- [Get going](#get-going)
	- [Remaining steps to expand on and format better](#remaining-steps-to-expand-on-and-format-better)
- [Document history](#document-history)
- [Copyright and license](#copyright-and-license)

<!-- /TOC -->

## Introduction

Unless you are running a very basic system that has no full-drive encryption, no data checksumming, no auto-snapshot capability, or other modern OS/filesystem features - then gone are the good 'ol days of Linux when you could just do a quick `dd` to copy a drive with a good setup, to another. Now it's more complicated - and not just for Tukzedo Linux - by things like:

- __Luks volume IDs__: Not changing these can result in catastrophic data loss, because if a single host computer has two full-disk encrypted containers with the same Luks ID, then no matter which bootloader the UEFI is told to boot (e.g. drive 2), the bootloader itself will open the Luks container the matches the ID it is told to open, that it sees first in a device scan. If you have two drives with the same Luks ID (i.e. a cloned system drive), odds are about 50% that you won't be booting into the system you think you are.

- __LVM__: Similar problem to Luks, except the behavior is less well-defined and can lead to corruption. Luks will happily mount whichever it sees first and all is fine (except you may be in the "wrong" OS). But with LVM, it might either refuse to mount, mount the wrong one - and/or make a mess of the bed at any time.

- __ZFS__: By definition pool names must be unique in order to import on the same system, but ZFS is at least a little more graceful in the case of conflicting names. Even after cloning drives, the device will still have different block-level GUIDs, and ZFS allows specifying which disambiguated name+GUID you wish to import. But ZFS is still one of the bigger headaches when it comes to cloning:

	- Specifying name+GUID at _boot time_ is a different problem than when manually importing an external array. And even then, that would still need to be changed as a post-clone step - so you might as just change the pool name.

	- Much bigger problems result from ZFS's origins at Sun Microsystems, when it was running on hundreds or thousands of LUNs on SAN fabrics, and/or as members of failover clusters. And at the time, import time mattered because Solaris reboots affected enterprise SLAs. So as a result, we have:

		- `/etc/hostid`: This contains a 4-byte binary value, which is also stored in each pool imported. The value stored on the host, and in each pool, must match. If they don't, ZFS will refuse to import the pool.

			- The original intention of this ID was (and is) to avoid problems in clustered failover scenarios. In such a scenario, multiple hosts may be able to simultaneously see the same array, but the ZFS executables on all machines will only allow one machine to import at a time. It does this by storing the host id of whichever host imported it, in the pool itself.

			- This ID is stored in a file on the root filesystem, under `/etc/`. Which, in the case of ZFS as a root filesystem is _in_ the pool itself. (In other words, in that case it's pointless as designed, and just makes life harder for initial system setup in a `chroot` environment, and cloning.)

			- The `-f` flag for `zpool import` can override this behavior. Also if the pool has been cleanly exported with `zpool export`, it can then be imported to another host without complaint.

		- `/etc/zfs/zpool.cache` further complicates cloning (and initial installation as a root filesystem). ZFS uses this file to store pool configuration. It's a "cache" in the sense of it being static configuration from the last boot, so that ZFS doesn't have to spend time scanning disks to reconstruct a potentially complex array configuration, as Btrfs does. It's a pool property that can be disabled, but it's ephemeral and resets on the next reboot. The problem with it is:

			- As mentioned previously, this used to make some sense for meeting reboot SLAs in massive SAN environments. But most Linux ZFS users are on local storage, local NVMe and SATA HDD inventories are small and scan almost instantly, and even SAN environments have better and faster device enumeration now.

		- These issues may persist in spite of not making much sense for modern ZFS systems (and wreaking havoc for "boot on ZFS" projects such as this one), because OpenZFS is conservative about changing behavior that "works" — the cache does work when nothing goes wrong. Furthermore Oracle has little incentive to change Solaris ZFS behavior, and OpenZFS historically shadowed Oracle decisions.

- __Btrfs__: Btrfs imports devices only one way - arguably more robustly and reliably than ZFS: by scanning for `fsid` and `devid`s written to the superblock of every device. It survives moving and other hardware changes like ZFS's `/dev/disk/by-partlabel`, but harder to accidentally change by users. And unlike ZFS it's doesn't offer other import methods (by default no less) that can and do change.

	But this also means the same problems that Luks and LVM suffer from - Btrfs does as well. And like LVM, the behavior of duplicate devices is not well-defined nor predicatable.

- __SystemD__: This is a per-host unique ID used by some SystemD services, that exists as a 128-bit hex string in `/etc/machine-id`.

- __Hostname__: This is the easy one, that needs to be changed no matter what system is cloned. It lives in `/etc/hostname` and `/etc/hosts`, and is trivially easy to change.

- __Encryption keys__: While not strictly necessary to avoid name collisions and/or OS corruption, it's a really good idea for security to not have everything using the same Luks and/or ZFS encryption keys. Even if you insist on using the same master password on more than one cloned drive, resetting the keyslots will generate all-new, different encryption keys.

Systems installed directly onto basic filesystems like ext4 present few cloning issues (basically just the last two easiest ones), mostly because ext4 isn't natively capable of supporting multi-device arrays. (At least, not without the help of underlying array managers such as `mdadm`, and then you have the same problems.)

## Warnings - and solutions

- If there is absolutely 0% chance of the cloned device ever being on the same host as the source after cloning, then you can theoretically get away without changing anything other than the hostname and SystemD machine-id. (But if it's going to a different network, guaranteed to never return, you don't even "have" to change those.)

	__But__ the "0% chance" has ways of deceiving us and biting us in the future. For example, if you have a whole network of cloned drives, and one has a problem - you may naturally wish to attach it via USB to another system in order to troubleshoot. (E.g. via `chroot`.) But without having previously gone through these cloning steps, you may soon be troubleshooting _two_ borked systems.

- The cloning process involves non-trivial, potentially breaking system changes. Therefore it's important to do it in a __virtual machine__, even if cloning real hardware. Why:

	- To protect your real host OS and hardware from very easy-to-make catastrophic mistakes.

		- You need to be able to boot into a third system, to clone one system to another. (Because neither source nor target can be running.) So you might as well do so in a VM, booting to an image that you can roll-back or easily recover from a copy, if you accidentally screw it up.

		- It is trivially easy in a terminal to forget which environment you are in (`chroot`? host?), and make changes that break a previously perfectly functioning host or recovery system.

		- The solution is _not_ to "just be more vigilant". That requires a mental tax that should be used for better purposes, and also can and will eventually fail. The real solution is to put in place _layered systems_ that make such mistakes "virtually" impossible - or at least far less likely - for any human to make in the first place.

	- To easily roll-back changes:

		- Ideally you should always do major system changes like this, to a virtual image in raw .img format, on a checksummed auto snapshotting filesystem such as Btrfs or ZFS.

			- Before each virtual reboot, power the VM off instead, and take a manual snapshot.
			- If a change breaks something badly, roll back to a working snapshot.
			- Also have auto-snapshotting enabled as a failsafe.

	- If cloning virtual-to-virtual, the easiest approach is to copy the source `.img` file at the filesystem level. (Especially with `cp --reflink=auto`.)

	- If cloning one physical drive to another physical drive, ideally first clone the source device to a virtual raw .img file and make the changes to that. Then when finished, copy the final .img file to the target device. Extra steps, but inevitably saves time in the end by making inevitable mistakes easy to surgically back out, rather than starting over.

		- Modern `cat`, `dd`, `pv`, or `ddrescue` are all equally good, if hardware in good working order. The real magic is in the way Linux presents block devices under `/dev` to userland tools, not the tools themselves. `dd` provides more options that aren't very relevant anymore on modern fast hardware, and `ddrescue` can do deeper recovery and verification on damaged media. But `cat` does the job exactly just as well as `dd`, while `pv` and especially `ddrescue` provides better status output of progress.

## Cloning steps

### Prepare

#### Map out your landscape

- You're going to need:

	- A recovery environment to initially boot to. This should ideally have persistent storage, not a LiveCD. If you don't have one, now would be a good time to create one. Even a quick-and-dirty install to a virtual image, from a friendly distro LiveCD.

	- A source drive or bootable virtual image file.

	- A target drive and/or virtual image file. ("And/or", because as mentioned before, it can be helpful to first clone to an `.img` file stored on snapshottable host media [e.g. ZFS or Btrfs], then when done, clone _that_ to a real drive.)

- Decide what virtualization product you are going to use, if any. (_Strongly_ encouraged as explained above.)

- Decide what among the three drives involved are going to be real drives used virtually, and what are going to be virtual image drives used virtually. (And what if any will be later made real.)

#### Set up a recovery environment to work in

- This has to be separate from the clone source and target, and one that both of those devices can be connected to.

- As explained why above, try hard to do this in a virtual machine. You might be surprised what few resources are required (e.g. a laptop with 4GB RAM), and/or the age of hardware (e.g. Intel Core Duo) you can do this effectively on; and how easy a virtual machine manager is to install and configure.

- As mentioned before, to save you time and energy, your recovery environment should ideally be a regular persistent Linux OS - i.e. not a LiveCD.

- A good and handy approach (in general) is to maintain a "USB recovery drive": some form of external SSD drive that can be or is connected to USB (anything better than USB 2), and has a full-blown Linux OS installed on it. It doesn't even need to be a "lightweight" distro. (But the fewer complex apps you have installed above and beyond the tools for setup and recovery, the easier it is to maintain long-term over years.)

	- This can also be used to boot and recover real "bare metal" systems. Most mainstream distros like Debian will happily boot back and forth between bare-metal and virtual, without a care in the world, even with proprietary Nvidia drivers for the bare-metal. Others (such as NixOS) may require advanced tweaking to handle the differences, and aren't recommended for a recovery drive.

	- An even better alternative for this purpose, is to user a "recovery _image_" - a virtual drive as an `.img` file, in turn stored on ZFS or Btrfs on your virtualization host - that can be snapshotted and rolled back. This is handy in case you accidentally screw up you recovery image! That's a pickle.

- Attaching real drives to a virtual machine is trivially easy with most VM products. Whether the drives are connected to the real host via USB adapter, or directly to native interfaces such as as NVMe or SATA. (One exception is VirtualBox, and is one of its few weak areas compared to other products. It's possible, just not as easy or robust.) It's easy in:

	- Linux: "Virtual Machine Manager" for KVM/QEMU/Libvirt (your most likely and arguably best solution), or VMware Worstation.
	- Windows: Windows Hyper-V Manager, or VMware Worstation.
	- macOS: UTM, or VMware Fusion

- Attach your recovery drive or image, clone source, and target to the VM. Either via NVMe-to-USB and/or SATA-to-USB adapters, or less ideally directly to native NVMe or SATA buses on your real host hardware. (Either way, ultimately passing through to the VM.)

	- Regardless of the physical attachment method, attach them all to the VM logically by device ID if the VM manager allows it. E.g. as found under `/dev/disk/by-id`, and ideally IDs starting with `wwn-` or `eui.`. These will never change even as other reference identifiers might. Don't attach them as "USB pass-through" devices. You need them to look to the VM like real system drives.

	- The device type in the VM manager can either be "SATA" or "VirtIO". It won't ultimately matter. ("NVMe" will probably also work, but won't help performance, unless it actually is on a real NVMe bus.)

	- Attaching drives to their native interfaces on your host is branded "less ideal" than with USB adapters, because all of the drives are presumably attached to the bare-metal host, only temporarily anyway. Why risk messing up your metal hardware configuration for a temporary operation, when for the purpose of this task, even the original USB3 speed is never a bottleneck (except for the initial full-disk clone). But c'est la vie.

- Configure the VM to boot first into the recovery environment drive or image.

### Get going

- __Boot into your recovery image__.

	- Install prerequisits into you recovery environment (assuming `apt` from here on):

		~~~bash
		sudo apt install git subversion coreutils
		~~~

	- Download the helper scripts you're going to need. (After reviewing them online to make sure they are safe.):

		~~~bash
		cd $(mktemp -d)  &&  git clone --filter=blob:none --sparse https://github.com/t00mietum/tukzedo-linux
		cd tukzedo  &&  git sparse-checkout init --no-cone  &&  git sparse-checkout set helpers
		sudo cp helpers/*  /usr/local/sbin/
		~~~

		Alternately you can copy the helper scripts somewhere less permanent, and add that folder to your path.

	- Generate a new short unique number for the new clone, that we'll refer to as 'mUID'.

		- This will be is used as part of multiple device names - Luks volume, LVM, ZFS pools. But _not_ as any part of the hostname. That will be different. A common scenario where you want consistent device naming but a different hostname, is the drive physically moving - not being cloned - to different hardware. You want to be able to do that without the hassle of changing the 'mUID' everywhere. (Which wouldn't actually matter if the hostname was the same as the mUID and then you later changed only the hostname. But it's just nice to be explicit about the distinction. Also, most people and orgs have a preexisting convention for hostnames, which could be quite long. Device names, not so much.)

		- Use any tool you want or just make one up, but here are some options for "short" and "probably unique enough":

			~~~bash
			## Time-deterministic: POSIX time [UTC seconds since 1970] to minute precision, converted to RFC 4648 base32
			printf "%x" $(( $(date +"%s") / 60 )) | xxd -r -p | base32 | tr 'A-Z' 'a-z' | tr -d '='

			## Random and less ambiguous to human readers
			head -c 100 /dev/urandom | base64 | tr -cd '0123456789cdefhkmnrtvwx' | awk 'BEGIN{FS=""}{for(i=1;i<=NF;i++)if(!seen[$i]++)printf $i;print""}' | head -c 5; echo
			~~~

### Remaining steps to expand on and format better

- Copy virtual .img file to clone.img, or for a real drive, something like `sudo cat /dev/xyz > /destdir/clone.img`.
	- (With a more meaningful destination folder and filename.)
- Load clone.img into libvirt and/or Virtual Machine Manager GUI, along with a bootable rescue image, drive, or live iso.
- Change GPT identifiers and references
	- Boot into UEFI setup, disable secureboot
	- Reboot back into your rescue image, drive, or live iso.
	- Change the target's GPT UUID, GPT partition UUIDs, and filesystem PARTUUIDs and PARTLABELS.
		- Update all references, e.g. in /etc/fstab and dracut modules.
		- Notes:
			- This can and will be done non-destructively.
			- This works just as well on a virtual disk image as a real block device, and will survive the copy from .img to physical.
	- Reboot into the new system (in a VM) to make sure the sytem works with the new GPT UUIDS.
- Change LUKS2 identifiers, names, and references
	- Reboot back into your rescue image, drive, or live iso.
	- Change the Luks UUID and all references.
	- Change the Luks name and all references.
	- Reboot into the new system (in a VM) to make sure the system works with the new UUIDS and names.
- Change LUKS2 keys
	- Reboot back into your rescue image, drive, or live iso.
	- Add a new primary dracut/initrd password, note the keyslot and metadata. Make it reasonably complex if USB will be primary unlock. Store metadata and the password in a password manager.
		luksAddKey  --pbkdf argon2id
	- Remove all the other keyslots
	- Add a new LUKS password for Grub fallback, to something complex (due to weaker key encryption). Store metadata and the password in a password manager.
		sudo cryptsetup luksAddKey --pbkdf pbkdf2 --hash sha256
	- Delete and create a new stage 2 key file ('/etc/cryptkeys/${mUID}') for Grub fallback. Store metadata, path, and contents in a password manager.
	- Create a new USB key file (on a new USB thumbdrive) for primary unlock. Store metadata, path, and contents in a password manager.
	- Reboot into the new system (VM) to make sure the new keys work. Test all the new keyslots and unlock methods.
- Change LVM names and references
	- Reboot back into your rescue image, drive, or live iso.
	- Make the changes
	- Reboot into the new system (VM) to make sure the system works with the new names.
- Change ZFS hostid and pool names
	- Reboot back into your rescue image, drive, or live iso.
	- Make the changes
	- Reboot into the new system (VM) to make sure the system works with the new names.
- Change systemd hostid, system hostname, and optionally static IP.
	- These are done within the running target system, so probably no reboot necessary from the previous step.
	- Make the changes
	- Reboot to make sure everything works.
- Change SecureBoot signing key
	- Create new mok keys
	- Re-sign everything
	- Build new UKI EFI[s] (and to be safe for testing, Grub)
- Optionally clone image to new real hardware drive
	- Map the physical device into the same VM as the .img file to clone.
	- Boot back into your rescue image, drive, or live iso.
	- Clone the entire updated .img file directly to the target `/dev/...` block device, using `cat`, `dd`, `pv`, or `ddrescue` etc.
		- Either as a source block device as already presented by the VM, or directly from the .img file.
		- Deal with the entire block devices, not individual partitions.
	- Non-destructively expand partition 2 (Luks) to fill empty space.
	- Non-destructively expand LVM2 (holding rpool) to fill empty space.
	- Import rpool and insure it auto-expands
	- Reboot into the new system (VM) to make sure the system works.
- Optionally Enable SecureBoot on final target system
	- Boot into UEFI, disable secureboot
	- Boot into new system on new target hardware
	- Create new mok keys
	- Enroll new keys on new system
	- Reboot, accept new keys
	- Reboot again into UEFI, enable secureboot
	- Reboot final time, test.

## Document history

- 2026-04-02: Template added to Git project.
- 2026-04-13: Progress on converting crude list into workable document.

## Copyright and license

> Copyright © 2026 t00mietum (ID: f⍒Ê🝅ĜᛎỹqFẅ▿⍢Ŷ‡ʬẼᛏ🜣)<br>
> Licensed under GNU GPL v2 <https://www.gnu.org/licenses/gpl-2.0.html>. No warranty.

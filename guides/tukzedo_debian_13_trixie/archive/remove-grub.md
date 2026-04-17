<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD055 -- Table pipe style [Expected: leading_and_trailing; Actual: leading_only; Missing trailing pipe] -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->
<div align="center">

[![!#/bin/bash](https://img.shields.io/badge/-%23!%2Fbin%2Fbash-1f425f.svg?logo=gnu-bash)](https://www.gnu.org/software/bash/)
![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)
![Lifecycle](https://img.shields.io/badge/Lifecycle-RC-blue)
![Support](https://img.shields.io/badge/Support-Maintained-brightgreen)
![Status: Passing](https://img.shields.io/badge/Status-Passing-brightgreen)

</div>
<!--
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
# Update to existing images (irrelevant to yet-created images)

For most of Tukzedo Linux' original ~five-year development, Grub was - begrudgingly - the cornerstone.

And once it was no longer the primary bootloader, it was still kept as a fallback.

But now that's just adding unnecessary, and unjustifiable, complexity.

_Grub has to go._

This document exists to plan and document that process. It isn't necessarily intended to be a full-blown "how to remove Grub" guide.

<!-- TOC ignore:true -->
## Table of ontents

<!-- TOC -->

- [Assumptions](#assumptions)
- [Guide](#guide)
	- [Remove Grub](#remove-grub)
	- [Remove bpool](#remove-bpool)
	- [Next steps](#next-steps)
- [Document history](#document-history)
- [Copyright and license](#copyright-and-license)

<!-- /TOC -->

## Assumptions

- These instructions assume that the OS in question is either a virtual machine, or you've cloned your real hardware to a virtual file on a snapshottable filesystem to do this, then will clone it back to the real drive. (In order to be able to easily roll-back disasters.) If that's not the case, then ignore instructions involving things like "make a snapshot on the host".

## Guide

### Remove Grub

- __In the VM host__:
	- Make a snapshot on the host of the initial starting condition, to be able to roll back to.
- __In the new guest__:
	- Make sure systemd-boot is working, and has a valid target (you can run these all at once):

		~~~bash
		## Status
		bootctl status

		echo -e "\nMake sure there's a non-Grub|firmware entry:"
		echo; bootctl list | grep -iPv 'firmware|grub' | grep -iP '(title|source):'; echo
		~~~

	- Uninstall Grub and delete leftovers

		~~~bash
		sudo apt remove --purge --allow-remove-essential grub-efi-amd64 grub-efi-amd64-bin grub-efi-amd64-signed grub-common grub2-common

		[[ -d /var/lib/grub ]]  &&  sudo rm -rf /var/lib/grub
		[[ -d /boot/grub    ]]  &&  sudo rm -rf /boot/grub
		[[ -d /etc/grub.d/  ]]  &&  sudo rm -rf /etc/grub.d
		[[ -f /boot/efi/loader/entries/grub-fallback.conf ]]  &&  sudo rm /boot/efi/loader/entries/grub-fallback.conf
		~~~

	- Check to make sure Grub is gone from EFI vars, while shimx64.efi and systemd-boot remain:

		~~~bash
		efibootmgr -v | grep -iP 'shimx64.efi|fallback|grub'
		~~~

### Remove bpool

Before starting, replace all instances of the string 't2nsn' below, with the unique identifier for your ZFS pools.

First, copy the data from bpool's /boot to a new /boot directory on rpool:

In the new guest:

~~~bash
sudo mkdir /boot_backup
sudo umount /boot/efi  &&  sudo rsync -aHAXS  /boot/  /boot_backup/
sudo umount /boot  &&  sudo rm -rf /boot
sudo mv  /boot_backup  /boot
~~~

Next, effectively disable bpool without deleting it, and make sure booting works without it:

~~~bash
sudo zfs set mountpoint=none bpool_t2nsn/deb/BOOT
sudo zfs set canmount=off    bpool_t2nsn/deb/BOOT
~~~

Update initrd:

~~~bash
sudo rebuild-uki --all
~~~

Reboot. If everything went OK, you can delete bpool entirely:

~~~bash
sudo zpool destroy bpool_t2nsn
~~~

### Next steps

You can remove the Logical Volume that housed the now-deleted bpool, and move and expand the rpool LV to fill that now-empty space. But it's sometimes as small as 512 MB - or 2 GB in the case of the original Tukzedo Linux - so it's not a big deal to just leave it be. Still, the guide on cloning will cover how to do this.

## Document history

- 2026-04-11: First draft.

## Copyright and license

> Copyright © 2026 t00mietum (ID: f⍒Ê🝅ĜᛎỹqFẅ▿⍢Ŷ‡ʬẼᛏ🜣)<br>
> Licensed under GNU GPL v2 <https://www.gnu.org/licenses/gpl-2.0.html>. No warranty.

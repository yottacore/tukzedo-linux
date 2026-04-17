<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD055 -- Table pipe style [Expected: leading_and_trailing; Actual: leading_only; Missing trailing pipe] -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->
# Frequently Asked Questions (FAQ)

<!-- TOC ignore:true -->
## Table of Contents

<!-- TOC -->

- [Definitions](#definitions)
	- [BIOS "Basic Input/Output System"](#bios-basic-inputoutput-system)
	- [UEFI "Unified Extensible Firmware Interface"](#uefi-unified-extensible-firmware-interface)
	- [Grub "Grand Unified Boot Loader"](#grub-grand-unified-boot-loader)
	- [ZBM "ZFS Boot Menu".](#zbm-zfs-boot-menu)
	- [Linux kernel](#linux-kernel)
	- [initrd aka initramfs "Initial Ram Filesystem"](#initrd-aka-initramfs-initial-ram-filesystem)
	- [LUKS "Linux Unified Key Setup"](#luks-linux-unified-key-setup)
	- [LVM "Logical Volume Manager"](#lvm-logical-volume-manager)
	- [UKI "Unified Kernel Image"](#uki-unified-kernel-image)
		- [Advantages of UKI](#advantages-of-uki)
		- [Disadvantages of UKI](#disadvantages-of-uki)
	- [ZFS "Zettabyte FileSystem"](#zfs-zettabyte-filesystem)
		- [History and facts](#history-and-facts)
		- [Advantages of ZFS](#advantages-of-zfs)
		- [Disadvantages of ZFS](#disadvantages-of-zfs)
	- [Btrfs "B-Tree File System"](#btrfs-b-tree-file-system)
		- [Btrfs advantages over ZFS](#btrfs-advantages-over-zfs)
		- [Btrfs drawbacks compared to ZFS](#btrfs-drawbacks-compared-to-zfs)
- [Question: How does the PC/Linux boot process work?](#question-how-does-the-pclinux-boot-process-work)
	- [UEFI stage](#uefi-stage)
	- [Bootloader](#bootloader)
		- [Grub or ZMB](#grub-or-zmb)
		- [systemd-boot](#systemd-boot)
	- [The Linux Kernel, initrd, and an init system](#the-linux-kernel-initrd-and-an-init-system)
- [Question: Aren't the ZFS CDDL and Linux kernel GPLv2 licenses incompatible?](#question-arent-the-zfs-cddl-and-linux-kernel-gplv2-licenses-incompatible)
- [Question: Is ECC memory required for ZFS?](#question-is-ecc-memory-required-for-zfs)
	- [Why someone might deliberately choose non-ECC memory](#why-someone-might-deliberately-choose-non-ecc-memory)
	- [An unlikely corruption-detecting boost for non-ECC systems, and valuable complement to ECC](#an-unlikely-corruption-detecting-boost-for-non-ecc-systems-and-valuable-complement-to-ecc)
	- [The urban legend of ZFS and ECC memory](#the-urban-legend-of-zfs-and-ecc-memory)
- [Question: Why not use ...](#question-why-not-use-)
	- [Btrfs instead of ZFS?](#btrfs-instead-of-zfs)
	- [native ZFS encryption for root, rather than wrapping it all in Luks?](#native-zfs-encryption-for-root-rather-than-wrapping-it-all-in-luks)
	- [the well-regarded ZFS Boot Menu "ZBM" instead of systemd-boot?](#the-well-regarded-zfs-boot-menu-zbm-instead-of-systemd-boot)
	- [rEFInd instead of systemd-boot?](#refind-instead-of-systemd-boot)
	- [Grub2 instead of systemd-boot?](#grub2-instead-of-systemd-boot)
	- [Dropbear instead of dracut-sshd?](#dropbear-instead-of-dracut-sshd)
	- [the approach that Ubuntu once used for similar goals?](#the-approach-that-ubuntu-once-used-for-similar-goals)
	- [systemd-homed for per-home encryption?](#systemd-homed-for-per-home-encryption)
	- [an actively-maintained FUSE-based stacked filesystem project for per-home user encryption?](#an-actively-maintained-fuse-based-stacked-filesystem-project-for-per-home-user-encryption)
	- [fscrypt for per-home encryption?](#fscrypt-for-per-home-encryption)
	- [Debian's default initramfs-tools instead of dracut?](#debians-default-initramfs-tools-instead-of-dracut)
	- [SystemD instead of, say, OpenRC, SysVinit, dinit, runit/s6, etc.?](#systemd-instead-of-say-openrc-sysvinit-dinit-runits6-etc)
	- [Fedora|OpenSUSE|Arch|Gentoo|NixOS|Void|Alpine|Slackware as the base, instead of Debian?](#fedoraopensusearchgentoonixosvoidalpineslackware-as-the-base-instead-of-debian)
	- [Immutable root filesystem?](#immutable-root-filesystem)
- [General questions](#general-questions)
	- [How can I contribute to Tukzedo Linux?](#how-can-i-contribute-to-tukzedo-linux)
	- [How do I install Tukzedo Linux?](#how-do-i-install-tukzedo-linux)
	- [What are the system requirements for Tukzedo Linux?](#what-are-the-system-requirements-for-tukzedo-linux)
	- [I encountered an error during installation. What should I do?](#i-encountered-an-error-during-installation-what-should-i-do)
	- [I found a bug. How do I report it?](#i-found-a-bug-how-do-i-report-it)
	- [Where can I ask for help?](#where-can-i-ask-for-help)
	- [What license is Tukzedo Linux released under?](#what-license-is-tukzedo-linux-released-under)
	- [How can I get support for Tukzedo Linux?](#how-can-i-get-support-for-tukzedo-linux)
	- [Can I request a feature?](#can-i-request-a-feature)
- [Copyright and license](#copyright-and-license)

<!-- /TOC -->

## Definitions

### BIOS ("Basic Input/Output System")

It's a legacy firmware interface dating back to 1981. It was used in older x86 and x86_64 based computers to initialize hardware during the boot process, provide a few runtime services for the operating system, and manage low-level configuration settings. It operated in 16-bit real mode and used a MBR (Master Boot Record) disk partitioning scheme.

### UEFI ("Unified Extensible Firmware Interface")

Often just called "EFI". It replaced BIOS. The UEFI standard was introduced in 2005, and has become the only option on most systems and motherboards, since about 2020. It assumes that disks are formatted with the GPT scheme, which is a more modern and flexible replacement to MBR. (Though many UEFI firmware vendors still provide a "BIOS/MBR" boot option to emulate legacy systems for the purpose of booting MBR-based drives.)

- UEFI is a hybrid of "Core UEFI Firmware" (which is purely firmware like BIOS), and disk-based software on a special FAT32 partition called the "EFI System Partition" (or "ESP"), which allows more flexibility and features.

- The Core UEFI Firmware (necessarily mixed with vendor-specific firmware settings to manage proprietary hardware), is still colloquially called "BIOS".

### Grub ("Grand Unified Boot Loader")

Grub is generally considered to be a "legacy" bootloader, but is still the default on most Linux distributions. It dates back to 1995 (soon after the first installable distribution of Linux and GNU userland tools), with v2 released in 2005, and becoming nearly universal by about 2010.

- Grub has nothing to do with Linux. They share no code, and Grub can boot any PC-based OS, or older Intel-based MacOS.

- Grub uses it's own drivers, for devices and filesystems that may be necessary in the earliest boot stages. Some drivers are based on open specifications, some are reverse-engineered.

	- It's own custom-written ZFS driver, for example, often lags far behind the "official" OpenZFS repo, which necessitates placing strict limitations of the ZFS pool commonly named "bpool", that houses `/boot`.

- Grub was included as an early part of this project (as a fallback boot option), but removed as being too cumbersome and difficult to support.

### ZBM ("ZFS Boot Menu".)

Not used in this project, but early efforts focused on it, and it's still useful to understand.

ZBM is a third-party open-source bootloader + boot environment selector, for systems using ZFS as the root filesystem. The main feature in this context, is that it allows managing and selecting ZFS snapshots to boot to - for example to boot to a known-good configuration update went bad.

- Unlike Grub, it contains it's own Linux kernel and `initrd`, and its ZFS driver is an actual OpenZFS module.

- However, the previous point should probably be thought of as only a "convenience factor" for ZBM development, because by going this route, they avoid the pain and incompatibilities of writing everything from scratch ala Grub. They get a universe of device drivers and hardware support, CPU and memory management "for free", and more recent OpenZFS support.

- But none of that necessarily translates to immediately obvious direct advantages for the user, other than surely faster release cycles, fewer bugs, broader support, and more up-to-date ZFS compatibility. Which is not nothing, but the point here is that neither Grub nor ZBM use the system's _installed_ Linux kernel, `initrd`, nor ZFS drivers - which are typically farther ahead in versions (or "feature flags" for ZFS).

- More to the point: As soon as either Grub or ZBM hand-off control to the "real" kernel, the CPU is reinitialized, and anything that Grub or ZBM did (such as open Luks or load LVM), effectively disappears from memory. (Except for the real kernel, which Grub or ZBM load and transfer execution to, and the compressed `initrd` filesystem image which is also loaded into memory and the kernel given a pointer to.

- If you were to keep your ZFS feature flags up to date (which is tempting to do since `zpool status` gives a lengthy reminder about every time it's run), especially if running Debian Testing, it does occasionally happen that ZBM's own ZFS module is too far behind the feature flags of the bootable system, and you're stuck - ZBM can't find a suitable bootable filesystem. (This is a less likely occurrence for Debian Stable, but still possible.)

### Linux kernel

To be pedantic, when one says "Linux", the kernel is the only thing they are referring to. But in (often argued) "acceptable" modern parlance, it also refers to the whole OS - roughly analogous to "macOS" or "Windows".

- _And for the second form to be accepted, then both references have to be considered valid: "Linux" is a kernel, and it's an OS; the context disambiguates. English is riddled with stuff like this, including in widely-used tech-jargon - and it's the convention this project takes. If "Performant" can inexplicably become an accepted adjective without being a war crime, then we'll use "Linux" as both a kernel and an OS!_

The Linux kernel is the modular but otherwise monolithic core of the OS.

On macOS the kernel is "XNU" (which incorporates the "Mach microkernel").

On Windows the kernel is `ntoskrnl.exe`, aka "NT kernel".

<!--
- Richard Stallman, founder of the GNU project and Free Software Foundation, has for decades militantly [insisted](https://www.gnu.org/gnu/linux-and-gnu.html) that "Linux" - as a whole operating system - be referred to as "GNU/Linux". Stallman has been a hugely influential and beneficial early pioneer of - and advocate for - the open-source movement in general, for which the world owes him a considerable debt. And The "Linux" operating system would have almost certainly gone nowhere fast, had GNU userland tools not been ported to work with the Linux kernel. (E.g. `bash`, `gcc`, `make`, `ls`, `cp`, `cat`, `echo`, `grep`, `sed`, `awk`, `tar`, etc.) After all, just a kernel by itself is pretty useless.

	- How that came about: Around the same coincidental time that Linus Torvalds released his "hobby" Linux kernel for open-source in 1991, the GNU project had also been working on their own, more serious "GNU Hurd" microkernel. However, development on Hurd was problematic and endlessly delayed. GNU developers found that developing for the then-nascent Linux kernel was a better, easier, and actually working target. (The Hurd kernel wasn't abandoned though. Development is _still_ ongoing some 30 years later, but still - inexplicably - "experimental" quality.)

- While it may have been reasonable and justifiable to call it "GNU/Linux" in the early-to-mid 90s (when most users did in fact use mostly GNU tools on command-line-only systems), by now that's arguably not a very tenable proposition. The list of open-source projects bundled into any usable Linux distribution, is very long, of which GNU is but one among many considerable efforts.

	In fact, what most users interact with on a daily basis - Xorg/Wayland, a Desktop Environment ("DE") such as Gnome or KDE, and GUI applications - are far removed from the GNU organization. (Though GNU codebases may still be involved in some of the under-the-hool tooling, e.g. `glibc`, and the original GNU tools are still used in most terminal-based user activity.)

- If one were to _still_ militantly insist that it be called "GNU/Linux", then it would make more sense to call it, for example, "SystemD/GNU/util-linux/procps/BSD/LLVM/Xorg/Mesa/GTK/Gnome/udev/D-Bus/Python/Flatpak/OpenZFS/Linux". To _only_ call it "GNU/Linux" (or "Ganoo/Linn-ox" as Stallman pronounces it, while the kernel's creator's last name is pronounced "Leenis"), feels disrespectful to the millions of man-hours, and sometimes millions of dollars, put into the numerous other high-profile projects that make a modern Linux-based "operating system".

- TLDR: Calling an entire bundled OS distribution (such as Debian) just "Linux" as a shorthand expression in most general discussion contexts, is perfectly acceptable. Not everyone agrees, but such is the nature of pedantic debates over the vagaries of rapidly and constantly evolving human language. I mean, I believe that it's an unforgivable crime against humanity to use "Performant" as an adjective - but you don't see me sharpening my pitchfork over it, nor lecturing anyone about it.
-->

### initrd aka initramfs ("Initial Ram Filesystem")

On some systems, `initrd` is more accurately called _`initramfs`_ (e.g. on systems using `initramfs-tools` instead of `dracut`).

- That's usually not the full name, it usually has the kernel version it's paired with, somewhere in the name.

- It originally meant "initial RAM _disk_", but now it refers to "initial RAM _filesystem_". It's functionally the same thing, but now uses a lighter-weight technology.

- The documents and tools in this project may occasionally accidentally use `initramfs` instead of `initrd`. The only reason the latter is "preferred" even though less accurate, is because that's in the filenames that `dracut` creates.

- It's purpose is for the kernel to give itself a temporary filesystem - complete with drivers, helper scripts, etc. - located in memory and typically mounted as `/sysroot`. It's created by tools like `dracut` or `initramfs-tools`, automatically any time a new kernel is installed. It's stored as a compressed file. The kernel first creates a ramfs filesystem, then extracts the contents of `initrd` to it - and voila, it has a working filesystem containing everything it needs to continue, including loading a real "final" filesystem.

### LUKS ("Linux Unified Key Setup")

It is primarily used to create and manage "full-disk" encryption containers, very similar in concept to Microsoft Bitlocker, or macOS FileVault. LUKS2 is a more recent backward-compatible successor, and more flexible and secure, and should generally be used instead.

- It will be referred to in this project mostly as "Luks", meaning either LUKS or LUKS2.

- Note that "full-disk encryption" is a misnomer. PC-based Windows and Linux systems, as well as previous Intel-based MacOS, require\[d\] a small unencrypted FAT32 UEFI partition. So although the rest of the disk (and operating system) can be stored inside the encrypted container, that technically (pedantically) makes it full-_partition_ encryption, not full-_disk_. This applies to other technologies such as Bitlocker as well.

- If you need "partitions" _inside_ a single Luks container (e.g. for separate bpool, rpool, and swap partitions), you'll need to use LVM instead.

### LVM ("Logical Volume Manager")

While it has many functions, the only one we're concerned about here is it's ability to present and manage "Logical Volumes" inside any other block device. LVs are conceptually similar to physical disk partitions, but more flexible, and well-integrated into the Linux ecosystem. LVM can work with raw disks, in which case LVs are used instead of partitions. Or it could be LVs inside a mounted loopback file - e.g. a Luks container.

### UKI ("Unified Kernel Image")

- Normally, a bootable `.efi` file, the kernel image file, and its associated `initrd` image file - are three separate files. They may even be stored on different partitions and filesystems. The idea behind UKI is to merge all three into one directly bootable `.efi` file.

#### Advantages of UKI

- Since a bootloader doesn't need to potentially jump through hoops to find the kernel and `initrd` (e.g. by unlocking Luks, loading LVM, and scanning ZFS filesystems), it can be much lighter and simpler. All it has to do is know which `.efi` to hand off control to, and the rest is comparatively easy.

	- And don't need all of `/boot` exposed for that benefit.

- With it getting to the real/final Linux kernel and `initrd` immediately, the boot process is made more reliable and less brittle.

- You get to the real and "final" Linux kernel immediately, allowing far more flexibility and control from there.

- The drivers inside the `initrd` are exactly the same as what will be on the final mounted system. (This advantage is hard to overstate.)

#### Disadvantages of UKI

- This necessarily puts the kernel and `initrd` on the unprotected UEFI partition. This can (and "should") be mitigated by automatically cryptographically signing the UKI `.efi` files at the time they are built (e.g. with every new kernel and/or DKMS build), and enabling SecureBoot in firmware UEFI setup.

- SecureBoot can't protect against a skilled attacker with physical access. (At which point you're probably cooked anyway.) The objective of SecureBoot is to protect users against more common web-based threats such as silent rootkit installation, that insert themselves early in the boot process.

	- However, even physical access will be initially thwarted thanks to Luks. The real risk is your exposed kernel being replaced with something that can log your keystrokes, and/or exfiltrate data once the system is up and running.

	- Even if you didn't use a UKI `.efi`, and had the kernel and `initrd` safely inside the Luks container, the system still has to boot _some_ `.efi` on the unencrypted UEFI partition. And if a UKI `.efi` can be compromised, so can a regular `.efi`.

	- The point is that without SecureBoot, _any_ `.efi` - UKI or not - can be tampered with, and/or chainloaded to or from an arbitrary malicious `.efi`.

	- "VerifiedBoot" will help in this case in the near-future (see roadmap), and help further secure the boot process even from attackers with physical access.

### ZFS ("Zettabyte FileSystem")

ZFS was the first mainstream, enterprise-grade Copy-on-Write (CoW) filesystem that provided all of the features below at the same time. It's still arguably the best, although the newer (and Linux-native) Btrfs is also getting quite good.

#### History and facts

- ZFS was first released in production-ready stable form with Solaris 10 in 2005. It was open-sourced with OpenSolaris in 2008. When Oracle bought Solaris and moved further ZFS development to closed-source, the last version of open-source ZFS was forked by multiple projects.

- Arguably, the first production-ready stable form of ZFS for Linux, was OpenZFS's "ZFS On Linux", around 2013.

	- The Linux versions are still legally required to be licensed under the CDDL license, which is source-code incompatible with the Linux GPLv2 license. This is discussed in more detail later in this FAQ. This is why, to get ZFS on most Linux distributions, it's required to use DKMS - which builds the ZFS kernel modules from source against the installed Linux kernel C header files, for every kernel update. (Though Canonical distributes pre-compiled ZFS binaries for Ubuntu.)

#### Advantages of ZFS

- ZFS uses a "Copy-on-Write" scheme (where new data never overwrites old), which is a required foundation for these features:

	- "Free" and "instant" snapshots. (Free and instant to human perception anyway.) The entire filesystem can be snapshotted, even frequently automatically, so that mistakes can either be rolled-back in total, and/or individual files recovered by browsing previous snapshots. Since ZFS doesn't delete old data when new data is written, the filesystem is able to keep track of which blocks belong to which files. It's usually the case where a single block belongs to dozens or maybe hundreds of snapshotted versions of the same file (that's how snapshots don't inherently consume extra space unless the "live" version changes). But ZFS won't discard a block until all current and snapshotted files referencing it, are deliberately destroyed. (Which requires different sets of commands - one for the current filesystem state, another for snapshots. And is nearly impossible to do accidentally.)

		- In multiple published studies, the #1 single cause of data loss - usually by a significant margin - is "accidental deletion by user". Automatic snapshots can and do protect users from that top cause. Rather than waiting potentially days or even weeks for a cloud restore of dozens of TB to complete, or possibly hours from a local network backup, a simple ZFS snapshot rollback can _instantly_ recover from a total accidental folder deletion.

	- "Zero-size" and nearly instant file copies, via the `FICLONE` ioctl, if on the same filesystem. (E.g. `cp --reflink=auto` which is also the default behavior of many modern GUI file managers.) This also allows for "offline deduplication" of an entire filesystem via third-party tools, which can be a tremendous space-saver if you have many redundant copies of the same data.

- Checksummed file data and metadata. If the proverbial (I mean real) "cosmic ray" flips even a single bit of data on your drive, ZFS will know it when it reads the file. If there is redundancy - e.g. mirror or RAIDZ or even a good `copies` > 1, ZFS can self heal the problem on-the-fly. But at minimum for a single-drive pool, just _knowing_ that a specific named file is corrupt can be invaluable.

- Robust mirroring and "write-hole"-free parity RAID. ZFS's implementation of "RAID-5|6|7|etc" doesn't suffer from a potential parity RAID problem in certain condition (like power loss or kernel panic) called the "Write Hole", that Btrfs and other software RAID implementations do. (Though Btrfs parity RAID isn't ready for production anyway.)

- Transparent on-the-fly compression.

- Transparent on-the-fly encryption. This point is the main reason it was selected for Tukzedo Linux.

#### Disadvantages of ZFS

- Due to historical and architectural reasons, ZFS on Linux gets very grumpy when trying to import a pool from a different boot environment, that wasn't cleanly exported first from the previous one. This becomes an issue when installing, cloning, rescuing, or off-line maintaining a "root-on-ZFS" system.

	- When ZFS was first rolled out by Sun Microsystems in the mid-to-late aughts, it was often running in an environment of hundreds or thousands of LUNs on SAN fabrics, and/or as members of failover clusters.

		At the time, import time mattered because Solaris reboot time affected enterprise SLAs. The designers probably didn't foresee a future where the ZFS installation base - at least by user count independent of other metrics - evolved to become overwhelmingly installations on Linux with local-only NVMe, SATA, or SAS storage. Furthermore, Oracle maintains this enterprise focus to this day, and with a "if it ain't broke [for them] don't fix it" attitude. The quite large OpenZFS project (and ZFS-On-Linux) tends to follow Oracle's conservative lead.

		As a result we have:

		- `/etc/zfs/zpool.cache` - that ZFS uses to cache the volume layout for next boot so that it can avoid having to scan every device; and

		- `/etc/hostid` - a per-host unique value to make sure two or more clustered hosts don't accidentally import the same pool at the same time.

		The problem is, neither of these make sense at all when using ZFS as a root filesystem - because both files are literally stored on the very device they were intended to manage and protect _before_ mounting.

		So instead, both of these enterprise-class schemes cause massive headaches and gotchas for installing, cloning, and/or recovering a "root on ZFS" setup. None of which Btrfs doesn't suffer from. This is just an accepted fact of ZFS life. To get the advantages, you have to figure this stuff out. (As noted in the README's ["Project challenges" section](https://github.com/t00mietum/tukzedo-linux/blob/main/README.md#project-challenges).)

	- __This project aims to remove both of those issues as obstacles, with robust boot-time and userland tooling.__

		- Although the cachefile can be disabled (in favor of a slower "scan"-based discovery method), it really can't be. The ZFS property to do so is ephemeral and resets at next boot; and the cachefile itself, if deleted, regenerates. (Notably, "scan-based discovery" is the _only_ method that Btrfs uses.) This project takes several approaches to mitigating this problem, which can and occasionally does prevent booting under several specific scenarios. In part, by resetting that property on every boot, then deleting the cachefile.

- When creating a pool, or importing with default options, ZFS doesn't use the _only "one-true" device identifier_ to reference the block devices by. You just have to "know" (or painfully realize over time and lessons learned) that the only correct identifier is:

	`/dev/disk/by-partitionlabel`

	And reimport the pool with that label. (E.g. `zpool import -d /dev/disk/by-partitionlabel POOLNAME`. Once you do that once, you only need to re-do it any time new block devices are introduced to the pool.)

	Any other device identifier - even `/dev/disk/by-id/wwn-*`, can either change on next reboot or with hardware changes (e.g. `/dev/sdN`), or can be hidden by some weird hardware that otherwise doesn't interfere with device recognition. (E.g. some USB chasses present their own impermanent `/dev/disk/by-id/`, hiding the real, permanent drive IDs.)

	`/dev/disk/by-partitionlabel`, in contrast, is a "globally unique" identifier that ZFS writes to GPT metadata at pool or vdev creation time, and can't be hidden from the OS by hardware (at least not without preventing basic GPT drive operation).

	This "rule" isn't documented anywhere, AFAIK. You're just supposed to "know" it. And if you don't know it, you risk winding up with a pool that can't be imported into another system in an emergency, without nontrivial effort.

- ZFS can be difficult to set up and troubleshoot, as a primary Linux root filesystem. This is above and beyond the issues listed above.

	- To be able to rollback a botched filesystem update, requires initial setting it up with multiple ZFS filesystem under the main root. For example, when rolling back an update, you probably don't want to roll back anything under `/home`, `/var/log`, `/var/www`, etc. (And you probably don't even want to be snapshotting folders like `/tmp` in the first place.) Hence the ideal need for multiple filesystems.

		This is also true for _any_ snapshotting filesystem as the root, including Btrfs. But with ZFS, the "non-Linux" way it manages creating and then later mounting filesystems, is more brittle and error prone.

		- Doing things in the wrong order, or with mount-related properties set incorrectly (which are practically immune to mere intuition), too-often manifests as shadowed directories - where important directories show up to all available tools as "mounted", but appear empty. (Or worse, contain completely different data.)

		- This project aims to help alleviate this particularly large headache, by making automatic boot-time _and_ manual recovery-time mounting - scripted and self-problem-solving. (And by providing more information about what's really going on.)

- _Inline_ deduplication is a ZFS "feature". However, if naively enabled by an average desktop user, it is likely to lead to suffering, reduced performance, and earlier dive death. It comes with an exorbitant cost to memory - and if you don't have enough memory (up to 10x GB of free memory per 1 TB storage), you'll experience potentially punishing performance degradation and (ironically) drive write amplification. This cost is not just for writing data, but for reading any data that was previously written this way as well, even after inline deduplication (for new data) is turned off.

	- But to be clear: _offline_ deduplication [using the Linux `FICLONE` ioctl], has nothing to do with _inline_ deduplication. They use completely different code paths. _Offline_ deduplication, with third-party tools, can work wonders on highly redundant data - at zero performance cost later.

### Btrfs ("B-Tree File System")

Very similar to ZFS at a high-level (but with a totally different design). Shares most high-level features. The main differences:

#### Btrfs advantages over ZFS

- Far and away the most important and significant advantage of Btrfs over ZFS - for our purposes - is that a single bootable drive _is not tied in any way to a specific host_. Not even a large Btrfs HDD array.

	Once a Btrfs volume is unmounted - or even if shutdown uncleanly - it can be freely moved to any other host without a care in the world. (Above and beyond the "shutting down uncleanly" part, or potential backwards-compatibility issues - concerns shared by any filesystem.)

	Unlike ZFS, there is nothing comparable to a "ZFS host ID" that it checks, and will refuse to mount if different than what it was last time.

- Similar to the first point, the second and huge advantage of Btrfs over ZFS for our purposes, is the lack of an "array" configuration cache that is very difficult to persistently override to scan-based behavior. For ZFS, this causes similar problems as the ZFS host ID issue. Btrfs _always_ scans devices to identify array members and their configuration. (Or just single drives.)

- Similar to the first two points, Btrfs doesn't rely on the user knowing they should use the only "one-true" device label to import ZFS pools.

	Btrfs uses three IDs for every block device (`fsid`, `devid`, and `dev_item.uuid`), that it embeds in the Btrfs block metadata at creation time. Together, they uniquely identify the array, member, and how to put it together. These IDs cannot be obscured by any hardware (at least, not without prevent nearly any filesystem from being able to be recognized), and are persistent across reboots and hardware changes.

- Btrfs mounts deterministically at boot time. (Unlike ZFS which relies on a confusing array and careful interplay of `init` scripts, `systemd` services, and `canmount=` settings.)

	In contrast, Btrfs root and subvolumes mount one at a time, as specified in `/etc/fstab`. It's hard to overstate the value of this.

- Btrfs is Linux native, and the license is the same GPLv2. The source code is with the Linux kernel tree.

- DKMS is not required to rebuild the modules with every kernel update (a time-consuming process). The pre-compiled binaries are directly available from basically all Linux distributions.

- Btrfs "RAID1" is pretty amazing. It's not traditional "mirroring" (ala ZFS's mirroring), where two same-sized disks are kept clones of each other. Instead, by default, every 1GiB-sized block is written to two different drives. This allows RAID1 arrays of arbitrary numbers of disks, and of an arbitrary mix of sizes. (With some reasonably obvious mathematical limitations on maximum usable volume size if one drive is drastically larger than the combined capacity of the rest.) A "copies" property can be set, to increase the RAID1 default of writing each block to two drives, to more drives than than. (With `raid1c3` being common for larger arrays.)

- Very easy to grow - or _shrink_ - arrays.

#### Btrfs drawbacks compared to ZFS

- The CLI management interface is quirky. Although Linux-native, it's very different than most other Linux filesystem tools. It's fine (good, even?) once you get used to it - it's just different to a long history of existing tools. (Then again, most other tools aren't "full-stack" aware, as ZFS and Btrfs arguably need to be, so maybe it's just what "progress" looks like.)

- Constructing a subvolume hierarchy for root system drive snapshots is much more confusing for new users than with ZFS.

- A "flat" subvolume approach - that is mounted hierarchically - is usually the recommended approach; which however requires potentially over a dozen entries in `/etc/fstab`.

- While there are multiple third-party snapshot management tools available, none are as easy and "install and forget" as `zfs-auto-snapshot`. And most require their own rigid subvolume and snapshot folder structure, that may not fit your needs.

- Some major features have been perpetually alpha or beta quality. For example, RAID-5|6.

- While unfair by 2026 (and in fact well before), Btrfs is still regarded by many to be "not ready for production". (Except that it is in production in some of the world's largest enterprises using it for their most important data. Just not RAID-5|6.)

- Lack of inline on-the-fly encryption. Support for `fscrypt` was recently introduced on an experimental project branch, but it could be many years before it's production-ready. This is the main reason Btrfs is not used for Tukzedo Linux. (Described in more detail later in this FAQ.)

- Even when `fscrypt` is ready in Btrfs, it's not as robust as ZFS's encryption. For example, in the former case, at-rest encrypted data looks a lot like stacked-filesystem encryption (even though it's not) - and with the same flaws. File sizes, counts, and metadata are exposed. For ZFS encryption, at-rest encrypted data isn't even mounted - it's just not there. (Though the ZFS filesystem metadata as a whole is.)

## Question: How does the PC/Linux boot process work?

To understand this project - and be able to really troubleshoot any Linux installation, especially ones with nested filesystems like Tukzedo Linux, it can be highly beneficial to understand, in detail, how a Linux PC really _boots_.

The PC boot process goes through several stages. We'll skip the hardware level - which is complex, different for different hardware, and not directly relevant to this project. And jump straight to UEFI:

### UEFI stage

- Handles some pre-boot security tasks.

- Typically looks for a generic `\EFI\BOOT\bootx64.efi` as a bootloader. But Windows systems typically register instead, `bootmgfw.efi`. Linux distros typically register `grubx64.efi` for non-secured Linux booting, or `shim.efi` for Secure Boot (which is hard-coded to chain to `grubx64.efi` which must exist by name only to continue booting, even if Grub isn't installed.)

### Bootloader

- The bootloader is responsible, at minimum, for finding and copying into memory a Linux kernel and `initrd`.

- It then (at minimum) hands of execution control to the kernel, along with the memory address to the `initrd` file, and usually also some command-line parameters.

	- In the case of Grub, these parameters are managed by system tools and/or the user, in `/etc/default/grub`. With settings like `GRUB_CMDLINE_LINUX`, `GRUB_CMDLINE_LINUX_DEFAULT`, etc.

- The bootloader may also attempt to find - and tell the kernel about - what filesystem to mount as `/boot` and root (`/`). That will be described next.

- To briefly restate from the definition section above, _the bootloader is not "Linux"_. It doesn't _necessarily_ have anything to do with Linux. (Most can also boot Windows, for example.) Grub doesn't even share any code with Linux. ZBM does use a linux kernel and `initrd`, but it all effectively disappears from memory once it hands control off to the "real" kernel early in the boot process. So ZBM being "linux-ey" is irrelevant, from the point of view of a final booted system.

#### Grub or ZMB

In addition to being bootloaders, and in the context of Luks encryption with LVM volumes, Grub or ZBM:

- Prompts the user for a LUKS passphrase.

	- It will try this passphrase against all keyslots it can recognize, until one works.

		- Grub currently can currently only work with `pbkdf2` keyslots, which is older and less resistant to GPU-based attacks than something like `argon2id`. If using Grub and Luks, you should increase your password length and complexity by about 1.5 to 2x, to compensate.

	- This is possibly the first of two prompts to do the same thing, since Luks and/or LVM being "open" doesn't survive the handoff to the Linux kernel, since all of those memory structures disappear.

- Scans LVM logical volumes, and finds ZFS pools.

	- Note: It is told which LVs to scan for, from information hard-coded at install time via `grub-install`. If that information changes, `grub-install` may need to be run again.

- Scans the contents of readable ZFS filesystems for `/boot` (e.g. the backward-compatible "bpool" in the case of Grub), using it's own ZFS code. Doesn't actually "mount" anything, which has no meaning at this stage.

- When it finds the selected kernel version (and corresponding compressed `initrd` image file) inside the ZFS bpool, it copies both to memory.

- Grub or ZBM jumps to a predefined entry point in the Linux kernel that it already copied into memory. This effectively ends itself. No resources (e.g. memory, LUKS, or ZFS) are "closed" or "freed" - they just become irrelevant once the kernel starts, and are no longer "open".

	- The parameters in `GRUB_CMDLINE_LINUX`, `GRUB_CMDLINE_LINUX_DEFAULT`, etc. are also passed to the kernel during this phase.

Tukzedo Linux does not use Grub or ZBM - nothing that needs to unlock Luks, before it's unlocked \[again\] in the `init` process.

#### systemd-boot

- The only thing `systemd-boot` does, is automatically discover `.efi` binaries in certain standard locations on the UEFI partition, and also reads predefined entries from `/boot/loader/entries/*.conf` drop-in files. That's it.

	- It can't open Luks and/or LVM to discover bootable filesystems.

	- If using Luks and/or LVM, a bootable `.efi` (in the form of a UKI `.efi`) must exist somewhere on the unencrypted UEFI partition, that contains the kernel and `initrd`. (Alternately, one or more separate `.efi`s, Linux kernel\[s\], and `initrd` image\[s\] - on the UEFI partition or otherwise not inside an encrypted container.)

		Although these can (and ideally should) be protected with signed binaries and SecureBoot enabled, it's theoretically not quite _as_ secure as a Grub or ZBM-based bootloader, that can actually open up the encrypted container, and extract a kernel and `initrd` from it. However, everything is a tradeoff. In this case what is gained - a vastly more powerful, flexible, and scriptable boot environment - is more than worth it. (And in fact required for the goals of Tukzedo Linux.) Also, VerifiedBoot will soon cover the security gaps that Secure Boot can't.

### The Linux Kernel, initrd, and an init system

- Once given control by the bootloader, the (real and "final") kernel reinitializes the CPU, MMU, and other hardware... and becomes "Linux".

	- Anything that any bootloader did is now gone, other than loading the kernel and giving it a memory location to preserve for the loaded `initrd` image file, and command-line arguments.

	- Anything that happens from here on - e.g. unlocking Luks \[again\] and mounting ZFS pools - needs to be handled by modules and scripts pre-baked in the `initrd` filesystem image (e.g. by the `dracut` end-user tool).

	- The user will either need to enter a LUKS password (possibly again), _or_ it can be unlocked automatically via a second keyfile-based LUKS keyslot - either with the keyfile baked into the `initrd` image (which would be highly insecure for UKI `.efi`s located on the UEFI partition), or a keyfile on a USB image.

		_For Tukzedo Linux, there is to entering of a password twice, and no keyfile baked into the `initrd`_.

- Creates a ramfs filesystem, and extracts the compressed `initrd` image file to it, then discards the no-longer needed `initrd` image source file from memory.

- Executes a copy of the init system (whatever is installed, e.g. `systemd`) located in the extracted `initrd` filesystem image.

	- The init system mounts the ramfs at `/sysroot`, to load drivers, scripts, and executables from to accomplish early boot tasks.

	- The root pool is imported, and root `/` mounted.

	- All ZFS other `canmount=on` mountpoints, including `/boot`, will then be arbitrarily mounted at any time according to `systemd` dependencies and timing.

	- Mountpoints in `/etc/fstab` (e.g. `/boot/efi` and swapfiles and/or partitions) are mounted according to `systemd` dependencies and timing.

	- Once that is complete, the kernel executes a `pivot_root` operation to make `/` the working root filesystem, rather than `/sysroot`. That temporary mountpoint is then discarded, the memory recovered, and `initrd` now no longer exists.

- Init-based booting continues, but from `/` - including loading a graphical interface.

## Question: Aren't the ZFS CDDL and Linux kernel GPLv2 licenses incompatible?

That's partially true, but irrelevant to this project. This is a common misunderstanding in a complex legal context (Although to be fair it seems there is enough room for creative interpretation, that it's not a proven legal theory. Also, this author is not a lawyer, I've just stayed at a Holiday Inn Express before.)

- The license incompatibility is at the source code level, not for distributed binaries. This is why it will probably never be possible to include ZFS in the linux kernel source tree.

	- Even if Oracle decided to relicense ZFS to a GPLv2-compatible license, some of the original copyright owners who would need to legally sign off on it, have died. The only realistic path to a compatible ZFS license, would be a complete clean-room reimplementation from scratch. (In which case, those resources would probably be better spent on improving Btrfs, or arguably even BCacheFS.)

- Canonical has provided pre-compiled ZFS binaries in their main Ubuntu repositories, since 2016 - free of legal challenge. (And they guaranteed legal cover to their enterprise clients as a way to soothe concerns. The Canonical legal team apparently felt that the license language was clear enough that such a guarantee would never be exercised.)

- Most distros like Debian, however, use the DKMS approach - where binaries are compiled at install time (and recompiled with each kernel update).

- Even Oracle has included available ZFS binaries in their "Unbreakable Linux" distro since about 2012. Oracle holds the copyright to the original Solaris open-source ZFS code (and everything Oracle has done since to their own branch), but that doesn't exclude them from the legal license incompatibilities with the Linux kernel at the source code level. If anyone is going to try to sue over this issue, Oracle would be the "injured party" with cause to do so. But because they themselves bundle ZFS with Unbreakable Linux, they essentially removed any legal argument against doing so.

## Question: Is ECC memory required for ZFS?

No. In fact, contrary to some older myths and disinformation, if you don't or can't run ECC memory, ZFS (or Btrfs) is actually a much _better_ choice for the goal of on-disk data consistency - over legacy, non-checksumming filesystems.

### Why someone might deliberately choose non-ECC memory

While ECC is inarguably a good idea, there are some legitimate reasons normal users may intentionally not be using ECC:

- __Speed__: Some users want or need raw memory speed and low-latency, over incrementally higher odds of memory correctness. ECC memory is usually only available at significantly lower MHz than the high-end for regular RAM. (Examples might include gamers, 3D animators, heavy virtual machine users, etc. Such users may still benefit from ZFS regardless of such a choice.)

- __Cost__: Unbuffered ECC for desktops can cost 30-50% more than non-ECC (at slower speeds). Meanwhile, registered ECC for servers can run 200-300% more. (But the latter is usually a moot point since RDIMM slots are just part of server board designs and there's no other choice. You can't buy an enterprise server without ECC.)

- __No choice__: Most laptop motherboards just don't support ECC at all, even if the CPU (e.g. AMD) technically could. It's not a "choice".

	And ironically, laptops - while probably dealing with a lower volume and rate of data in memory - are more likely to be exposed to the primary cause of needing ECC in the first place - neutron flux - if used in an airplane.

	And yet, ZFS is just as useful on a laptop, as a desktop. (And as explained later, even _more_ important for a flying laptop with no ECC.)

What's more, ECC is fairly narrow in scope, and can't detect all common forms of corruption. It is not a cure-all panacea. Other common forms of system corruption that ECC has nothing to do with:

- Charged-particle or noisy EMF corruption along the long memory traces of PCIe lanes.

	- PCIe has a CRC scheme in the spec, but it's usually not enabled by default, and some devices ignore it.

- Peripheral device memory and circuitry - some but not all may have their own detection/correction schemes.

- Cache memory on consumer-grade CPUs.

	- AMD Ryzen chips have ECC on L1, 2, and 3 caches.

	- Intel typically only protects L3 with ECC on consumer-grade parts, if at all.

- DMA transfers - not protected by ECC.

- Cables and interconnects, etc. Potentially long cables of varying shielding quality, are susceptible to data corruption, including EMF noise.

	- Thunderbolt, NVMe, and SATA have good CRC-based protection, in approximate descending order of robustness.

	- USB does too, but weaker.

	- USB2 is arguably the weakest modern interconnect in that regard.

	- The Ethernet standard is the weakest of all. It relies on application layers to detect and "fix" (e.g. re-send) problems. But TCP itself isn't even that strong for error detection: 1 in 65,536 corrupted packets slip through undetected, just due to the weak algorithm - a real problem at 10 continuous Gbps. ECC can do nothing about any of that. But with application-level verification, on top of application-level _encryption_, on top of TCP - now we're getting somewhere more reliable. (That "encryption" part being emphasized plays into the next topic.)

Any environmental condition or operational requirement that makes ECC essential, is also going to apply equally to other common forms of corruption that ECC has nothing to do with.

For example: laptopping while flying in an airplane. At 35,000 ft, the cosmic ray flux is ~100x higher than sea level, and worse near the converging magnetic lines near the poles. The overwhelming primary cause of flipped-bits is neutron flux (mostly caused by high-energy cosmic ray collisions with atmospheric particles). Cosmic rays are high-speed charged particles such as alpha particles (helium nuclei), mostly originating far beyond our solar system, even other galactic cores. (Hence "cosmic". Black holes from other galaxies are messing with your data.) The second-most common cause are lower-energy alpha particles emitted by slightly radioactive contaminants in the materials of the computer itself. Noisy EMF environments can be a factor in extreme situations, like operating near big electric motors.

However you slice it, ECC is an important protective measure - but it's only one armored elbow-pad of protection for a MotoGP race. Or the helmet - might be a better analogy.

### An unlikely corruption-detecting boost for non-ECC systems, and valuable complement to ECC

Transparent memory encryption.

Intel calls it "TME", AMD "SME", other chipmakers and brands have similar tech. But for this purpose, it's called "TME" generically.

- This technology encrypts memory end-to-end to the memory controller (similar to ECC's endpoint), transparently to the OS.

	__It's sole purpose is as a security feature__. For example to thwart "cold boot" attacks and physical memory extraction.

	...But there are _unintended secondary_ benefits.

- All Apple Silicon (macOS and iOS devices) use their own version of TME - it's always on and can't be disabled. Most Android devices employ some form of it as well.

- For desktops and laptops, only high-end Intel SKUs support it (as of 2026), while all newer AMD CPUs do. Some Windows laptop vendors also enable it by default, but few desktop or server vendors turn it on by default.

- Either way, almost all AMD users, and some high-end Intel users, can turn it on themselves in BIOS setup.

- For the latest CPUs, the memory performance impact is sometimes within the limits of testing variance.

- So... why does this matter in a point about ECC?

	- In regular non-ECC memory, a single bit-flip can either cause silent data corruption, or often will lead to a memory address or assembler instruction causing an invalid memory area to be written to, triggering an unhandled exception. (Either immediately or eventually.) If it happens in code running at the kernel level, that will result in the OS purposely halting as a protective measure - a "bluescreen" or "panic". Or if in a user-mode application, the application will crash - which it might be able to warn you about before the OS cleans it up, or might not.

	- In other words - a single bit-flip in non-ECC, non-TME memory may or may not cause a system halt before corrupt data can be made permanent.

	- Regardless of the TME scheme's page size, AES-XTS operates on 128-bit blocks at a time.

	- If a single memory bit is flipped to the opposite value while TME is enabled, upon reading and decrypting the 128-bit block containing the flipped bit, the _entire block_ will become cryptographically scrambled, useless data. (In other words, an average of half of the 128 bits in the page will be wrong.)

	- While this might sound bad, it's actually better from a data integrity perspective, and provides an unintended protective effect: A single bit-flip anywhere between the memory controller and physical RAM, in either direction, will result in around 64 bits out of the 128 being randomly wrong. (Compared to only 1 wrong bit per 128.)

- In other words, TME gives you something around a 6,400% higher odds of triggering a (good) data-protecting fatal error/kernel panic, before the corrupt data can be persisted externally.

	- _Although it may not be that simple depending on the nature of the memory affected. "Between >0% and <~6,400% improvement in the odds of not silently passing on corruption", would be a more accurate statement._

		_If the corruption happens in the stack, or something like a vtable - then it's closer to 6,400% (and a practically guaranteed crash or panic). But if in the middle of heap data and of a nature that has no inherent program expectations or rules about how bits should be organized - which is pretty rare but PCM audio is one example - then the "detection" odds improvement ranges closer to 0%._

- Standard ECC _corrects_ single flipped bits per 64-bit memory word (and can tell the OS about it), with no need to crash anything. That's up to 4.3 billion flipped-bits in 32 GB of RAM if optimally (~impossibly) distributed. But studies show that single bit-flips are the overwhelming case (that's good), and when there are more, they tend to be clustered together (that's bad).

	Standard ECC _detects_, but can't correct, a maximum of two flipped bits at a time, per 64-bit memory word. Any more than than, and we're back to silent corruption. (And remember, >1 flipped bits tend to be clustered together.)

	So while that's usually enough, it's also an excellent argument for always running TME if you can. If you're also running ECC, it's capabilities will be complimented. (ECC operates first. TME operates on top of it.)

__TLDR__: It would be silly on its face to argue for ditching ECC memory, in favor of enabling TME. And both are ideal together - for different primary reasons, and complimentary secondary reasons. However the fact remains that _if_ you're stuck with non-ECC memory, _then_ TME - while not it's purpose and not remotely a guaranteed solution - does unintentionally and non-trivially increase the odds that memory corruption will result in a "safely" crashed program, or halted OS, before the bad data can be persisted to external devices.

_A note about DDR5: Although DDR5 includes per-die ECC (ODECC), it's purpose is to bring the read/write reliability of the denser cells back up to DDR4 standards - not exceed it. And only for data in-transit. It doesn't detect static bit-flips the way ECC does. So TME is also good for DDR5. And just good for security._

### The urban legend of ZFS and ECC memory

A confident urban legend seems to have started on message forums over a decade ago, going back to near ZFS's introduction on OpenSolaris.

That myth was, that ZFS _requires_ ECC. Not explicitly enforced in code, but as in - it's certain disaster if you run ZFS without it.

This arguably reached peaked hysteria in discussions on NAS forums from the 2010s, with titles like,

- "[ECC vs non-ECC RAM and ZFS](https://www.truenas.com/community/threads/ecc-vs-non-ecc-ram-and-zfs.15449/)", and
- "[ZFS Scrubs with no ECC (what could possibly go wrong?)](https://forums.truenas.com/t/zfs-scrubs-with-no-ecc-what-could-possibly-go-wrong/30863)".

These worst of these myths were ominously labeled...

"_The ZFS Scrub of Death_"

The short version being, a `zpool scrub` operation, if there was a "stuck bit" in memory, would wind up corrupting the entire pool.

The problem is, it's not true. There's no such thing as a "ZFS Scrub of Death".

The importance of using ECC for ZFS is no more important than while running _any_ filesystem. The filesystem doesn't matter. ZFS, Btrfs, ext4, NTFS, FAT32, AFS - ECC is a good idea as a protective measure.

Except...it's still actually not that simple. ZFS is actually slightly _protective_ against random memory bitflips, in ways that non-checksumming filesystems can't. (And redundancy can improve that even more.)

- This blog post from 2015 titled, "[Will ZFS and non-ECC RAM kill your data?](https://jrs-s.net/2015/02/03/will-zfs-and-non-ecc-ram-kill-your-data/)" by a ZFS admin, explains how that protective mechanism works.

- One of the ZFS cofounders from then-Sun Microsystems, and ongoing ZFS developer Matthew Ahrens, [explicitly debunked the pervasive myth of ZFS needing ECC more than any other filesystem](https://arstechnica.com/civis/threads/ars-walkthrough-using-the-zfs-next-gen-filesystem-on-linux.1235679/page-4#post-26303271) in a discussion comment.

Furthermore, ZFS is definitionally "always structurally consistent" (assuming consistent underlying hardware of course). Btrfs is as well, though has had more historical bugs than ZFS related to checksumming and scrubbing.

Legacy filesystems like Fat32 or NTFS, on the other hand, are _notorious_ for "lost clusters" after a system crash (e.g. due to corrupted memory), or power outage. Ext4 also similarly suffers from "orphaned inodes", but at least the ext4 `fsck` tool is a little better at finding where they belong, than `chkdsk` for FAT/NTFS.

Given that, it doesn't seem sane to _not_ consider ZFS (or Btrfs), over a legacy filesystem - unless configuration and maintenance simplicity, and/or raw performance, are overarching goals. (Which to be fair would be hard to argue against. To each their own.) Or for a VM's virtual filesystem `.img` file already sitting on ZFS or Btrfs underneath.

__TLDR__: If you choose not to or are physically unable to run ECC, you _should_ use ZFS for your most important data. That said - if possible and tolerable, it would be wise to use ECC for your next computer. The more valuable your data and the more of it you have (and also the more RAM you have), the higher your odds of experiencing some corruption - and the more you will benefit from ECC.

## Question: Why not use ...

### ...Btrfs instead of ZFS?

As described above in the "Definitions" section, ZFS and Btrfs have a highly overlapping set of features.

On the other hand, ZFS is generally regarded as more "mission-critical"-capable and battle-tested than Btrfs. Btrfs has had some famously data-eating bugs in the past.

But by 2026 (and in fact earlier) Btrfs is perfectly acceptable for enterprise-grade storage - as long as you avoid RAID-5|6. In most respects, it would make an ideal choice for Tukzedo Linux. (And in fact, this author uses it as a system drive filesystem on multiple systems.)

And as detailed in the definitions section, ZFS also has a few _extremely_ aggravating attributes (that Btrfs doesn't), in part related to it's original roots on Solaris, and in part simply due to unfortunate early architectual decisions that plague it to this day on any architecture or OS.

But ultimately, with the help of years of personal experience with both, the choice was fairly easy and came down to only a few points:

- ZFS has a much more manageable snapshot system, built-in. No scripting, third-party tools, or competing rigid filesystem layout schemes are required.

- As mentioned in the "Definitions" section, the `zfs-auto-snapshot` utility, which is a "recommended" package when installing ZFS on Linux, is incomparably more easy and "install-and-forget" for automatically creating and pruning snapshots, than the third-party utilities to do the same for Btrfs. (Mostly due to the way ZFS handles snapshots almost entirely internally, vs. the more flexible but more difficult way Btrfs does it.)

But those two comparative "weaknesses" of Btrfs, could have been worked around for Tukzedo Linux. And some even see them as advantages, as the "Btrfs way" does offer more flexibility - at the cost of complexity, a fair bit of required knowledge, and manual effort.

The main feature that made ZFS the only realistic choice for Tukzedo Linux:

_ZFS is the only production-ready CoW filesystem with native support for inline on-the-fly encryption_.

That's one of the primary project goals, in support of __per-user encrypted home folders__.

Furthermore:

- Encrypted ZFS "filesystems" don't need their own dedicated pools, partitions, or loopback files; they only consume as much space in the primary pool, as the encrypted files in them do - no different than files in a directory. (Which is also no different than `fscrypt`, but different than the `systemd-homed` loopback file option.)

- The ZFS encryption method is superior to what Btrfs may eventually offer with their effort to integrate `fscrypt`, which _might_ be production ready in five-to-ten years or so. As mentioned before, when ZFS encrypted data is unmounted, that filesystem disappears. On the other hand when `fscrypt` is unmounted (whether on ext4, XFS, F2FS, or future Btrfs), the encrypted data looks like that of a stacked encryption filesystem (even though it's not stacked), which still exposes quite a lot of useful information.

	- This could be an acceptable tradeoff to some. (Even for this author.) However there is no `fscrypt` support, or any encryption support, in any other production-ready Linux-compatible CoW filesystem. Not Btrfs, not BCacheFS.

### ...native ZFS encryption for root, rather than wrapping it all in Luks?

Since we're immediately loading the real Linux kernel via the UKI `.efi`, and skipping intermediate bootloaders like Grub and ZBM, we _could_ just use native ZFS encryption and do without the Luks container.

The bulletpoints below explain why it's not done that way in Tukzedo Linux. None are absolute dealbreakers - but for even basic, general desktop user security, the choice is pretty clear:

- ZFS only supports a single key slot for encryption. LUKS2 supports 32 - which can (and are) used for separate keyslots. While this limitation of ZFS is not insurmountable in terms of allowing multiple login _methods_ (which although not easy is a solved problem), that's not the issue here. For security, each _method_ should have a unique and different _key_ and key _type_.

	- To illustrate, consider the Tukzedo Linux decryption options:

		- __USB thumbdrive key__: - One key slot is dedicated a USB thumbdrive unlock. The general idea with a USB key is that you have one way "in" that you "__have__" - which requires physical access to use - _or_ one way in that you "__know__", which can be used at the physical console, or remotely. (For maximum security you could require _both_, which is the idea behind password+authenticator schemes.)

		- __Fallback password__: This keyslot should use a robust GPU-resistant cipher (e.g. `argon2id`), _and_ a reasonably difficult password or phrase. (Since presumably you can mostly lean on the USB key for "ease-of-use" for most boots.)

		- __Grub fallback password__. Grub can only work with an older, weaker cipher that is easier to leverage GPUs against (`pbkdf2`). For that reason, the only keyslot Grub will be able to open, should use a much stronger password, to compensate - ideally one you would need to open your phone-based password manager to reference. So if you were to want to build-in Grub fallback yourself for some reason, there you go.

	- The USB key and password should never be the same thing. Because if they were, and someone got a hold of what you _have_ (the USB key) - even momentarily without your awareness - then they can also trivially know what you _know_. With that, it's assumed they could get in at boot-time, remotely, at their leisure. (How they might know when the system boots isn't the point. The question may be less about "knowing when" and more "able to indirectly control".)

		- The USB thumbdrive key can and should be impossible to remember, if not also type. (E.g. a >= KiB-sized binary file.)

		- Note: This still isn't foolproof. A USB key could also just be physically _copied_ to another one, with some minor planning and preparation ahead of time. (Which would also assume a more motivated attacker than "hey what's on this thumbdrive?".) This risk could be closed by requiring _both_ a USB key _and_ a password/phrase. But to allow just one _or_ the other, the idea is not to seal every possible exploit regardless of the inconvenience. Barring comprehensive threat-modeling, the general approach most users take is to close the low-hanging fruit first, and keep going until the increasing inconvenience factor outweighs the diminishing risk of exposed data. So in this case for example, the key file could also be hidden on the device, in a way that is immune to a naive filesystem copy - which wouldn't _exactly_ be "security through obscurity", because it would legitimately shut down several vectors - but it shouldn't be considered a reliable solution to that particular risk.

	- __TLDR__: For security-conscious users or organizations, using the same passphrase for console/terminal-based unlock, _and_ USB key, should be considered an easily-exploited, and unacceptable, risk. That's why ZFS's single-slot key model presents a generally "unacceptable" risk, even just for general desktop users not dealing with juicy state or trade secrets.

	But we _do_ considered "acceptable", in this case, to use it as _layered_ encryption for home-directory security, which requires getting through Luks first. There's no logical contradiction.

- As mentioned more than once earlier, ZFS's native encryption still leaves exposed, metadata about the ZFS filesystems within the pool. Not anything about the files or directories - but the filesystems themselves could be investigated and/or messed with (e.g. some deleted to cause problems without immediately noticing why. Or potentially worse, filesystem properties changed in subtle ways. E.g. a `mountpoint` changed.)

- Secure hibernation: If native ZFS encryption were to be used, then the swapfile would have to go on a partition.

	- Due to an ancient ZFS bug that may be too hard to fix, swapfiles on ZFS cause kernel panics when they get full. So that approach is a non-starter.

	- An in-the-clear swap partition, that could be used for hibernation, is _highly_ insecure and not an option.

	- A common workaround is to use a random, ephemeral encryption for every new boot, in order to be secure. But that is fundamentally incompatible with hibernation, since the encryption key doesn't survive reboot.

	- The only solution, given these hard constraints, is to put a swap partition or file inside a Luks container. That's doable (and a solved problem). An encryption key is stored in a file (or the file itself), inside the encrypted root filesystem. Once the root filesystem is unlocked, the key is read to unlock it, then `dracut` triggers `/sys/power/resume` to load the hibernation image, if it exists. Not a trivially easy solution, but doable.

So ultimately, it comes down to the ZFS security model just not being enough for a security-minded project such as this. That's unfortunate, but layering Luks underneath is a common and robust solution with minimal performance and acceptable complexity impact.

### ...the well-regarded ZFS Boot Menu ("ZBM") instead of `systemd-boot`?

After all, not only does ZBM support modern ZFS features for the `/boot` pool (unlike Grub), it can also boot to snapshots, and even other distros on other ZFS pools.

But ultimately, ZBM is not much different from the highly problematic legacy Grub bootloader in principle, when it comes to integrating with this project. A herculean effort was made to base this project on ZBM.

Ultimately it was not possible to meet the other project goals with it, because __ZBM does not support our required logical on-disk stack of Luks → LVM → ZFS__, nor was it meant to.

It also doesn't seem to support a scripted approach to unlocking with USB key, SSH, _and_ password fallback.

Other issues:


- As described in more detail earlier, anything Grub or ZBM do at boot time (like open Luks, load LVM, and scan ZFS) - disappear in memory and process space, once the real kernel starts. So... why not just boot more directly to the "real" final kernel from the start?

- As also mentioned before, neither bootloader is compiled with support for the installed ZFS version. This is usually only an issue for Grub which can be two or more years behind, but it can happen that ZBM can't boot due to ZFS feature flag incompatibilities. While this can be mitigated by "well then just don't do that", it's still a deal-breaking risk for this project.

	- This isn't (necessarily) about protecting users from themselves. Two objectives of this project are to worry about only one kernel version from the moment of bootloading, and only one ZFS version - the ones installed. While any project like this involves balancing tradeoffs and eschewing "purity" in favor of "finishing", these were not just ideological deal-breakers - both wound up presenting way too many practical problems for accomplishing most of the other objectives combined.

- `systemd-boot` is part of SystemD, and probably not going anywhere. Although ZBM appears to be a healthy project, it seems from this point in time to be a safer _long-term bet_ to build on `systemd-boot`.

- There is just no getting around the significant advantage and flexibility afforded by loading the real kernel as soon as possible, i.e. a UKI `.efi`. In which case, the barebones `systemd-boot` was created for.

### ...rEFInd instead of `systemd-boot`?

Technically, the more sophisticated rEFInd project does about the same thing as `systemd-boot` - but with more visual polish, flexibility, and customizability.

- Like `systemd-boot`, rEFInd also doesn't care about nor attempt to unlock Luks, and can also immediately hand off control to the real, final Linux kernel inside a UKI `.efi`.

- In fact, rEFInd was a core part of this project right up until nearly the finish line, even when ZBM was in the mix. Trouble arose when it came to cryptographic signing for SecureBoot. However this is not an insurmountable challenge, and rEFInd may make a triumphant return at some point, with minimal impact to the project. It was more about "I'm only one person with limited bandwidth".

- Ultimately, `systemd-boot` won out over rEFInd because:

	- Fewer cryptographic signing and chaining issues.

	- `systemd-boot` can do most of what makes rEFInd special (e.g. be configured to boot multiple OSes), just with less GUI polish and real-time interactivity.

	- `systemd-boot` is a core, native component of the `systemd` init system that Debian already uses. No third-party components like Grub, ZFS Boot Menu, or rEFInd are needed.

		- _It should be noted that none of those projects are necessarily mutually exclusive on the same system. This project, in fact, has a "fallback to Grub" mode, which is installed even though it doesn't need to be. And if you wanted to add complexity, rEFInd and systemd-boot could easily coexist \[selectable in UEFI firmware setup\], or even chain to each other for some reason if you wanted to do that._

### ...Grub2 instead of `systemd-boot`?

The [definition of Grub](#grub-grand-unified-boot-loader), and as well as the [description of it's role in the boot process](#grub-or-zmb) - both in this same FAQ - answer this question. The TLDR:

- It's old and creaky.

- It's not Linux-native (not by itself necessarily a problem).

- The Grub project have to write and maintain their own device and filesystem driver codebase. (Hence very old ZFS and Luks support.)

- For Luks and LVM, the containers have to be unlocked, and loaded, twice in the boot process. That adds complexity and increases attack surface.

- For unlocking Luks it only supports an older, weaker encryption algorithm - requiring close to double the password length and complexity to achieve the same level of security as other, stronger keyslots.

- It's redundant and unnecessary, on a system using UKIs.

### ...Dropbear instead of dracut-sshd?

Either probably would have been fine. Dropbear seems to be the more common go-to solution to crack this problem. It's 1/3 the size (but compared to only 1MiB), and already built in to `dracut-network`.

_But_: Dropbear is less "native", and the upstream project is not as recent or active. `dracut-sshd` on the other hand, uses the full sshd stack and authentication features (which to be fair are both pros and cons), and standard SSH keys that don't require conversion.

In the end, the preference is not strong. It probably just came down to the fact that, for whatever reason, it was easier to get `dracut-sshd` up and running.

### ...the approach that Ubuntu once used for similar goals?

Various versions of Ubuntu from 19.10 through 24.04 allowed easy selection ZFS for the root filesystem, at GUI install time. Some of those versions also allowed for the selection of native ZFS encryption for root `/` (but not `/boot`).

And for a few glorious years in Linux history, it was not only possible to at least encrypt `/` with ZFS, but also individual user homes. Alas not with a GUI, nor at install-time, but at least after-the-fact with `ecryptfs-migrate-home`.

So for a few years it was not just possible but easy, out of the box, to at least have: Linux root on ZFS, _and_ encrypted root, _and_ additionally encrypted per-user home directories.

It didn't fully meet all of this project's goals (particularly the stacked filesystem encryption/ZFS snapshot problem), but was pretty close.

The reason that approach isn't possible anymore, is because:

- Canonical dropped strong support for installing on ZFS (and theirs was a problematic implementation); and

- Their approach still exposed `/boot` in the clear (not necessarily a deal-breaker with SecureBoot), as well as the inherent minor weakness of native ZFS encryption (without a Luks container) exposing ZFS filesystem metadata to inspection and manipulation. (But at least not individual files.)

- The `ecryptfs` project is no longer maintained - and has known security vulnerabilities.

	- `ecryptfs-migrate-home` no longer even works on many distros, including Debian - if you can even find it. (And the source code will be removed from the 7.0 kernel source tree.)

	- While there are modern alternatives to `ecryptfs` - and every one was carefully investigated if not also tried - none yet meet project requirements. No stacking encrypted filesystem does. More detail below.

### ...systemd-homed for per-home encryption?

That might have actually been preferred, and may be used in the future. On the surface it seems purpose-written for this use-case. Unfortunately, to date:

- It doesn't directly support encryption for top-tier CoW filesystem (i.e. ZFS or Btrfs).

- ZFS will probably never be supported, due to A) a desire to avoid even the perception of license incompatibilities for nervous corporate customers, and B) ZFS already supports it's own robust native encryption and will probably never support `fscrypt`, which `systemd-homed` seems more geared towards.

- While `systemd-homed` supports Btrfs, Btrfs support for `fscrypt` is in the earliest stages of experimental development.

- `systemd-homed`'s native support for any filesystem on top of a layered loopback Luks container, is intriguing. But ultimately it is problematic due the necessity of `systemd-homed` to frequently grow and shrink the user home's container (e.g. by poking sparse holes in it), and involves five layers of filesystem indirection. (E.g. the only way to meet project goals currently would be Luks → LVM → main Btrfs filesystem → Individual Luks loopback containers for home directories → separate Btrfs filesystems on each.)

### ...an actively-maintained FUSE-based stacked filesystem project for per-home user encryption?

Because:

- Stacked filesystems inherently knee-cap most of the benefits of CoW snapshots. While the underlying encrypted files can be snapshotted, the decrypted meaningful folder and filenames (decrypted only in memory on-the-fly) are not. You can roll back the whole thing to a prior snapshot, but the arguably more common case of surgically restoring a specific file from a snapshot folder (with cryptographically scrambled and meaningless folder and file names), is extraordinarily difficult.

- For most projects that store each virtual folder and file as a real folder or file with a cryptographically scrambled name and contents, much can still be learned about a user and their activity, from that available information alone. File counts, file sizes, dates and times - it's all available. And/or could be subtly messed with, e.g. surgical file deletion without the automatic ability to know about it. (At least one stacking encryption project, however, uses small same-sized containers with no meaningful metadata. Which obviates most of those specific problems.) With ZFS encryption, on the other hand, the entire mounted filesystem is simply nonexistent, until decrypted and mounted. And then in both cases, the encryption and decryption is transparent and on-the-fly, and no decrypted data ever exists on-disk. However with ZFS, the snapshots work with the native encryption so that the snapshots also appear decrypted.

- We're already stacking a lot. (Luks → LVM → ZFS.) Adding a fourth layer - especially via stacked FUSE-based encryption - feels excessive.

- PAM integration is important, and IIRC only one active stacked encryption project supports in. (Although to be fair, PAM doesn't directly support ZFS encryption either, and requires the same kind of scripting help that could be afforded to other options.)

In short, even if the legendary `ecryptfs` kernel module were still alive, it would also be a poor choice for this project, especially for the first two reasons.

### ...fscrypt for per-home encryption?

Because no top-tier CoW filesystem (i.e. ZFS or Btrfs) supports it yet.

As mentioned earlier, Btrfs appears to be many, many years away from supporting it in production-ready form.

### ...Debian's default initramfs-tools instead of dracut?

Because:

- The Debian distro itself is transitioning to `dracut`.

- `initramfs-tools` is (ironically in light of the first point) Debian-centric. `mkinitcpio` is Arch-specific. `dracut` is platform-agnostic.

- `dracut` is newer than initramfs-tools, and is arguably easier to configure and maintain. It's also (arguably) more powerful. This project would have probably been too complex and maybe not even possible (if for no other reason than pain), with `initramfs-tools`.

- Switching from one to the other on a basic system, is trivial. (Not so much for Tukzedo Linux, which relies heavily on `dracut`.)

### ...SystemD instead of, say, OpenRC, SysVinit, dinit, runit/s6, etc.?

Because changing would involve too much long-term upgrade fragility. Also, this author likes SystemD. Next question.

_Disclaimer: Anyone familiar with the "Linux init system flame wars" will "get" the attempted humor in the brevity of this answer. It comes down to different init projects having different objectives and scopes, and involve largely ideological and (IMO) unproductive arguments over those disagreements. `systemd` handles what is needed for this project well. And where it doesn't, \[e.g. `systemd-network` in the `initrd` stage being slightly too heavy\], it's easy enough to use something else._

### ...Fedora|OpenSUSE|Arch|Gentoo|NixOS|Void|Alpine|Slackware as the base, instead of Debian?

Because:

- Among that list, it's tied for first as the longest-running distribution. It has legs.

- Although a difficult number to nail down, Debian-based and ultimately derived distros account for a total of 47% of the Linux Desktop market share. Or probably with more appropriate precision, "about half". People are familiar with Debian, and the `apt` package manager. Ubuntu, Linux Mint, Elementary OS, Kali Linux, Knoppix, and myriad Ubuntu-based distros - all ultimately Debian-based.

- It's a robust "known quantity" to launch a new distro from, and has tools to help.

- The main drawbacks of Debian Stable compared to a few of the others:

	- It's not a rolling release - that _could_ be ideal. (Debian Testing and Unstable are heavy-quotes "rolling", but aren't viable candidates for Tukzedo Linux, yet.) But a rolling release could also introduce sudden breaking changes to Tukzedo Linux - or _any_ derived distro - at any time. In which case we'd have to always be in the middle. (Which would necessarily mean it's a legit distro gaining popularity and maintainer support, so a good problem to have.)

	- Debian is seen as boring momjeans. It doesn't have the edgy street cred like, say, NixOS. Nor the "I'm so cool and aloof, I don't even have a package manager" vibe of Slack. But who cares? It's Linux. It has almost exactly all the same things the others do - whether that's XFCE Desktop, or `grep`.

		If you want to suffer for the sake of street cred and/or art - rather than get stuff done quickly and easily - just uninstall the stock DE and install `dwm` - the apex of "hostile to casual users by design".

		Linux distro street cred is just about perception and always evolving "reputation", based on mostly no meaningful differences. (Except NixOS. _That_ is legitimately suffering for genuine art.)

		For Tukzedo Linux, Debian is a stable, reliable base with a great package manager. That's pretty much it.

		Speaking of...

- Package management:

	This is a significant, possibly majority portion of the choice in base distro.

	- `dnf` and `zypper` are generally considered the most graceful and user-friendly at automatic dependency resolution.

	- `nix` is arguably (and probably) the most "correct" solution to package management, as packages are isolated and atomic, and by definition have no dependency conflicts. It also has one of the largest set of available applications.

		- But it is ever-evolving and involves a pretty steep learning curve.

		- It isn't suitable for this project's goals. As one example, it is difficult to configure a system to automatically boot, without failure, between arbitrary systems that might have Nvidia, AMD, Intel, or virtual graphics drivers. But that comes for "free" with some of the other distros, including Debian.

		- The Nix package manager is available for other distros, not just NixOS. Including Debian.

			- It has a huge universe of applications.

			- But by its nature, disk usage can get huge, it can get messy with conflicting system-level dependencies from the native package manager, and it's complex.

			- Where `nix` really shines is as a _whole system_ package manager. To use it otherwise, is to knee-cap it and invite conflicts.

	- __Debian's `apt` ranks highly on dependency resolution__ as well - and where/when it falls short, it explains itself well.

	- `pacman`/`aur`, and `portage` are more hands-on and manual for dependency and conflict resolution, and were never really in the running for Tukzedo Linux, for that reason.

	- The `flatpak` package manager can run on most distros. Tukzedo Linux uses some `flatpak` applications.

		- Pros:

			- It accomplishes much of what `nix` does on NixOS for user applications, but for nearly any distro.

			- It works independently of, and free of conflict with, the native system package manager. (Unlike `nix` on non-NixOS systems.)

			- Like `nix`, applications have no dependency conflicts by definition.

			- `flatpak` applications are often more up-to-date than what can be installed from the native package manager.

			- Some distributions remove application packages from their repos - and your system - on upgrades. Which can be surprising if not annoying. (Especially for Testing and Dev tracks of a distribution. If you run on the bleeding edge, `flatpak` is for you.)

			- Low learning curve.

			- Flathub often has applications that can't be found in native repos. (But sometimes also vice-versa.)

		- Cons:

			- The sandbox environment can cause problems for some applications. Most can be alleviated by relaxing and/or expanding permissions (e.g. via the FlatSeal GUI), but it can at least be an extra burden.

			- Like `nix`, the total storage requirements for a given set of applications, is higher.

			- Useful mainly for user-mode GUI applications - typically not for applications that require deep system-level integration, nor usually for simple CLI-only binaries.

			- It uses an obscure filesystem hierarchy for executables, configuration, and cache files. Once you get used to it, it's understandable why it's so complex, and the assumption is that you don't need to go poking around it. But, it's still a con.

Other solutions:

- Snap packages: Snap is a app containerization solution, not so much a package manager. It was created by Canonical and remains mostly exclusive to Ubuntu - to quite visible public user backlash.

	Among other complaints (e.g. involving "consent"), it pollutes the `mount` space, and requires a deeper level of system integration than some users are comfortable with. (Though to be fair that can be considered an advantage over, say, `flatpak`.)

	It is often considered to be an annoyance to remove as soon as possible - with some difficulty - by Ubuntu power users, tinkerers, and/or homelab admins.

	Snap packages are not used on Tukzedo Linux, and will be completely avoided into the foreseeable future.

- AppImage: A standalone application bundling solution. (Not a package manager.)

	- Pros:

		- No runtime or installed infrastructure is required. It's an executable header, archive, and application+dependencies bundle, all bundled into one file. An elegant solution, really. Just download or copy, and run. All of it's required version-specific dependencies are in the bundle.

		- Like `flatpak` and `nix`, it eliminates dependency problems by definition.

		- Any generated user configuration and cache files are stored in the user's home directory, like any repo-installed application.

	- Cons:

		- Startup times are slower, since it has to extract everything from it's archive first.

		- It does mount a FUSE-based directory. (But unlike Snap, the mountpoint only lives for the lifetime of the application.)

		- There is no auto-update mechanism, unlike every other system mentioned here.

			- However there is a beta application called [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate) that uses an AppImage's own standardized embedded metadata, to differentially update an image file from the web.

			- An experimental program [appimaged](https://github.com/probonopd/go-appimage/blob/master/src/appimaged/README.md) can help further integrate AppImage applications into the user experience, if desired. (Including creating menu icons, uninstall, etc.)

		Tukzedo Linux uses at least one `.AppImage` application. Given the total lack of dependencies the format requires, the fact that it eliminates dependency problems, it's low system intrusiveness, and literally "drop-in-and-run" nature - there's no reason there may not be more in the future.

### ...Immutable root filesystem?

Distros like Fedora Silverblue, openSUSE MicroOS, NixOS, Endless OS, and blendOS - support "immutable" root filesystems. Tukzedo Linux could have been based on one of those.

The idea with immutability being, neither curious power-users nor unprivileged malware can modify the core operating system. They can only install applications in their own user environment, e.g. via Flatpak. The systems can still be administered, but it's harder to do by design.

Many of these distros are also "atomic", meaning an OS upgrade either all succeeds, or fails with no harm done or things left "half-way". While the two concepts are often conflated - and do often share technical underpinnings (e.g. Btrfs snapshots, ostree) - they are two different things conceptually, and don't have to be coupled. (And aren't always.)

It would be hard to argue that the concept of the "atomic upgrade" is not a universally great idea. Who would argue in _favor_ of failed updates resulting in a non-deterministically partially-upgraded system that may or may not boot?

The idea of immutability though, has generated endless heated debates. Often with no middle-ground allowed.

But the problem is, there _is_ middle-ground. As well as valid extremes on any end. It's possible - and healthy - to hold competing and even mutually exclusive ideas in one's mind, considered as valid perspectives, at the same time.

This author has tried most of those listed immutable OSes, and even considered them as bases for this project.

iOS, macOS, and to varying degrees Android devices use "immutable" system partitions. It seems Microsoft is trying to head in that general direction as well, much to the chagrin of many of their users. (E.g. with locked-down systems more resistant to malware and misconfiguration, secured boot and operating environments, required cloud accounts, etc.)

But one of the greater appeals of Linux - and apparently part of the reason it is making such gains against Windows in recent years - is that it actively rebels against that "locked-down" nature, in favor of highly personalizable and individualized devices.

In other words: Specifically for enthusiastic Linux desktop/laptop and homelab users, __an "immutable OS" may feel like a step backwards__.

But context and nuance do matter. An immutable Linux OS may be highly relevant and desired for servers with multiple administrators and high-uptime requirements, and/or for large corporations with managed user machines with strict controls and/or overworked admins.

But for the average desktop/laptop user that this project is specifically aimed at, the "problems" that immutable OSes solve, may do so for trivial gains, while introducing more problems than it's worth. Consider:

- Immutable security: Machines can already be locked-down with user account privileges. I.e., the idea behind `sudo` rights or not. No `sudo`, no monkey with the system.

	An immutable OS does add an extra layer of defense - which is usually a good thing, but in this case that extra immutable layer covers the exact same use-case and access method as `sudo`. In other words,the Venn Diagram of account-based access protection, and immutable OS protection, is a perfect circle.

	Once you've gotten through the first layer, _you're automatically able to get through the second_. There's no "layering", there's only "more difficult". That's not real security.

	If malware can gain root privileges., then the only benefit of an immutable OS is "security through obscurity", and/or extra steps. But any competent malware will know how to deal with it. And _especially_, a targeted attack will not be inconvenienced in the slightest by an immutable OS, once they get through the first and necessary access escalation phase.

	TLDR: __If it can be done by a user with `sudo`, it can be done by malware or a targeted attack, immutable or not__.

- Accidental OS tampering, file deletion, etc.

	- It inevitably happens that a Linux user accidentally enters something like `sudo rm -rf /etc`. With an immutable root filesystem, as long as the user isn't also in that system's "administer" mode, they are saved from themselves and may be quite grateful for it.

	- But CoW filesystems like ZFS already afford this protection, especially if you have automatic snapshots enabled. It is trivially easy to rollback such catastrophic accidents, with `sudo zfs rollback pool/dataset@snapshot`.

	They aren't mutually-exclusive though - in fact some immutable systems require e.g. Btrfs for it's CoW features. And you may not have a recent-enough snapshot to roll-back to. But if you were forced to chose only one or the other for some reason, CoW alone provides broader "protection from yourself" than just immutability alone. (Especially since system installations can be regenerated; user data can't always be.)

<!--
- Back in the old-old days, computers were too expensive for everyone to have one. So computers (often minicomputers accessed by dumb terminals) were managed by an administrator, and users were locked down. An immutable OS might have been a nice addition in that case.

	- But now, everyone has their own computing device. Homelab geeks (such as this author) often find themselves setting up multiple accounts for family on desktops and servers (or LDAP) - only to find themselves as the only user to ever "log in", in a way that even needs a user account. (Which is kind of the whole point of "services" - no traditional "login" account required.)
-->

- Most home computing is done with one-user-per-machine, on "local" accounts, and with only one account per machine.

	- The idea seems positively _quaint_ today, of an administrator protecting users from themselves on their own devices they paid for, with themselves as the only account.

<!--
		Even in many modern workplaces, users are given full control of their own devices - sometimes their own "BYOD". (Surely by company count easily - but possibly not by employee count, considering that the largest employers employ the most people, Pareto Principle-style. In the latter case, an immutable OS may make more sense for those company admins.)
-->

- Buying a laptop (e.g. macbook) or device (e.g. iOS) with an OS designed hand-in-hand with the hardware it runs on, to be immutable - generally also has a TPM, SecureBoot, full-disk encryption, and often transparent encrypted memory. Often in ways that can't be disabled by the user. These are (arguably) to date the pinnacle of modern security, maximum reliability, maximum ease-of-use - but also minimum choice and minimal flexibility (and if minimal privacy what could you even do about it?).

	Some people specifically choose more personal control, less lockdown, for some devices.

	However it's rarely an either-or situation. Who is the Linux desktop enthusiast-tinkerer, who doesn't also own an iOS or Android device? Each plays to their strength.

<!--
- There's an interesting trend that seems to be evolving on Linux discussion forums. Even just a decade ago, it used to be SOP that any time a user merely asked about running as `root` or removing the "annoying" prompt for `sudo`, they would get immediately lectured and browbeaten into leaving for such blasphemy. Without so much as asking why the user might want that. It's just Bad Security Practice. (And in most cases that's true.) But more and more, it seems commenters are pushing back against against such "personal security gatekeeping", encouraging awareness of context and nuance, and raising legitimate scenarios where it might make sense.

	This isn't to suggest anyone disable the `sudo` authentication prompt, it's to point out that the popular sentiment seems to be slowly turning in favor of understanding the reality of the modern Linux enthusiast desktop/laptop situation: every user has _their own_ computer, that no one else uses, there's no "administrator/user" dynamic, no one to "protect" from themselves; and if they hose their own system, most people have their data stored in the cloud and/or otherwise backed-up with high frequency, and many Linux enthusiasts find full-system reinstalls trivial. They may routinely tweak global driver settings, services, ZFS settings, etc. - and restart services without having to reboot.

	Homelab operator/tweakers may need to, say, edit `/etc/samba/smb.conf` and restart the service, without bringing down myriad Docker containers, VMs, and all the services within - for a full immutable OS reboot.
-->

- MicroOS (as one example) reboots nightly by default, since reboots are required for most system-level updates to take effect - even config files. While the default behavior can be changed, it's not acceptable to many desktop users.

<!--
- In summary, there's no one-size-fits all pat answer. It's more use-case dependent, but even then there is context and nuance.

	- Devices that are completely and fully locked-down, highly secure, fully integrated, and immutable - from the factory - like phones and tablets. Not even users can change core OS settings. Arguably the most secure devices in computing history. Most - not all - of us seem to want, need, and appreciate this level of security. (After all, these things are easily lost.)

	- Ultra-personalized desktops/laptops for enthusiasts, developers, and/or gamers who want full control. Once they have `sudo` access - and they will since they're definitionally the only owner of the device - OS immutability just adds unwanted friction to routine intentional system tweaks. (Granted this may be a dying breed.)

	- Homelab servers: It seems that any homelab tinkerer who thought an immutable OS would be a good idea, quickly realizes it's not.

	- Large corporations with a large user base and company-provided laptops: although the incremental security and change prevention that immutability offers over and above account privilege access control is relatively small (compared to the initial gains of the necessary first level of access control), it also may not be much additional burden, and ultimately a net-win. So why not?

	- Large, secure, high-uptime servers: Probably a great idea in most cases, where _any_ incremental gain may be worth any inconvenience. Live in-memory kernel patching can still take care of security updates.
-->

__TLDR__: Atomic updates would be great - and are already partially solved for Tukzedo Linux by ZFS. And are on the future roadmap as a full-blown feature. But immutability is explicitly and intentionally _not_ a desired roadmap feature.

<!--
### I don't like it that `systemd` supports age verification

OK, that's fine, and not a question. But as long as I'm putting up contrived straw-man objections that I'll obviously knock down, because that's what FAQs demand, let me - this author and primary contributor - offer that I agree in principle.

I agree that it's important to resist knee-jerk moral-panic-of-the-moment legislation that doesn't solve the fearmongering problem it's advertised to, and instead just further encroaches on our rights to privacy and free speech - and further consolidates power in the hands of a few who don't seem to have the best interests of me, my family, community, country, or world in mind.

But in this case, `systemd` added a "DOB" field to the `userdb` service. Stored as text in a JSON file along with other user data that has always gone above and beyond what gets stored by `adduser`.

That's literally all they did.

"But that's a slippery slope to full-blown age-verification!"

Well, if that's the crux of the argument without regard to the project's goals or team's actual written stance on the legislation, then the `userdb` service in the first place was where the slippery and/or slopery slipslope started.

There was considerable debate and contributor outrage about the addition. Dozens of project forks resulted overnight.

And yet, Lennart Poettering and other maintainers also object to the legislation. But in their project roles, they are are __more concerned about heading off an inevitable proliferation of fragmented and incompatible user database services__, that will only further fragment and confuse the Linux landscape, if there wasn't already a more convenient existing place to store it for third-party services.

Any Linux-based project developing an age-verification service to honor ill-conceived laws __will not be inconvenienced in the slightest by the lack of a "DOB" field in SystemD's `userdb`.__ They'll just make Yet Another User Database Service. (And probably name the first one "YAUDS" for that. Just like `YACC`, `YAST`, `YAML`, `YARN`, `YAPF`, `YABAI`, etc.) And sow further fragmentation.

The `systemd` team are on-record as _actively_ having no intention of developing an age-verification service.

Real beneficial progress that helps people, is often hampered by unnecessary "ideological purity". Especially when based on incomplete or mis- information. What are the two competing harms we are really struggling with here?

Some linux distros __are__ going to develop or adopt age-verification services. Users can object and abandon those platforms, but unless enough voters step up and force the repeal of the laws, most will distro projects will eventually have to comply, or die. (But that doesn't mean users will have to comply, even with such systems in place.)

Given that fact, the question the `systemd` team grappled with is: do we _also_ want to encourage, through inaction or misdirected protest, a mess of competing and incompatible user database services to enable the inevitable third-party age-verification services that are coming?

Reasonable people can - and should - disagree. Ideally with informed, respectful, good-faith, hopefully steelmanning debate. And not based on emotional hot takes ripped from misleading deliberately clickbaitey headlines.

Until then - I'm going to save my energy for the political and social realms, where the real problem lie. And vote accordingly, and continue to occasionally write my state legislators, and House representative. (Among who I've made the effort to at least meet almost all in person.) And try to get my concerns heard, with my lack of billions of dollars. I also reserve the right to object to new projects that actually actively develop age-verification services for Linux. But this ain't the hill to die on.

Boycotting a great project over a "DOB" field, _after_ such monumental legislation became law, is angrily slamming the barn door after the horse got out. Our real - and harder - task before us, is to find the horse and ship him to the glue factory. (Or maybe the idiot who left the barn door open. And/or pushed the horse out. I'm not really sure where this metaphor is going.)
-->

## General questions

### How can I contribute to Tukzedo Linux?

Please read our [Contributing](https://github.com/t00mietum/tukzedo-linux/blob/main/contributing.md) guide for details on how to get started.

### How do I install Tukzedo Linux?

Follow the instructions in [Tukzedo Linux on Debian Trixie](https://github.com/t00mietum/tukzedo-linux/blob/main/guides/Guide%20-%20Tukzedo%20Linux%20on%20Debian%20Trixie.md).

### What are the system requirements for Tukzedo Linux?

Pretty minimal. You need hardware acceleration support at minimum, which was supported by all major CPUs by 2011.

While it's a popular notion that "ZFS eats RAM for breakfast", that's no more true than any other well-designed filesystem - unless you have ZFS inline deduplication enabled. (Which is a rarely-used enterprise-grade feature that needs about 10x GB of RAM for every TB of deduplicating storage.) ZFS now supports third-party tool offline deduplication anyway, which works on a radically different principle under the hood, and does not require any extra memory before or after running.

The idea of "minimum system requirements" for an OS is a fairly outdated idea anyway, for modern desktop computers. That's because any modern web browser is by now far and away the heaviest consumer of CPU and memory resources - sometimes even GPU resources. Just having a few tabs open at the same time, dwarfs the requirements of most operating systems. Especially Linux. (Except for certain corner cases like TPM v2 for a default Windows 11 installation, allegedly an NPU for Windows 12, and specific technical requirements for each successive macOS release which you can't work around.)

The choice of Linux Desktop Environment, for example, is a commonly debated but more or less irrelevant decision when it comes to going "lightweight" - compared to what your web browser is going to wind up doing to your hardware.

If you wish to have more than a few browser tabs open at the same time, go for no less than 4 to 8 GB of RAM (as of 2026). The more memory, the better. If buying a new system with a fixed budget, just as general advice: more memory capacity will buy you more longevity, than a faster CPU.

### I encountered an error during installation. What should I do?

Search open and closed [Issues](https://github.com/t00mietum/tukzedo-linux/issues). If none address your issue, file a new one.

### I found a bug. How do I report it?

Open an [issue](https://github.com/t00mietum/tukzedo-linux/issues). But first, please make sure a similar bug hasn't already been filed. Include steps to reproduce the bug and any relevant logs.

### Where can I ask for help?

Ask a question on the [Discussions](https://github.com/t00mietum/tukzedo-linux/discussions) page.

### What license is Tukzedo Linux released under?

Tukzedo Linux is released under the GPLv2 license. See the [license](https://github.com/t00mietum/tukzedo-linux/blob/main/license.md) for details.

### How can I get support for Tukzedo Linux?

For community support, visit the [Discussions](https://github.com/t00mietum/tukzedo-linux/discussions) page. For commercial support, contact us at t00mietum_at_tukzedo.org.

### Can I request a feature?

Yes! Open a feature request on our [Issues](https://github.com/t00mietum/tukzedo-linux/issues) page.

## Copyright and license

> Copyright © 2026 t00mietum (ID: f⍒Ê🝅ĜᛎỹqFẅ▿⍢Ŷ‡ʬẼᛏ🜣)<br>
> Licensed under GNU GPL v2 <https://www.gnu.org/licenses/gpl-2.0.html>. No warranty.

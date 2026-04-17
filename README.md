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
# Tukzedo Linux

The purpose of Tukzedo Linux is to bring stronger security, more security _convenience_, and filesystem modernization to the Linux desktop.

And not coincidentally, to bring some optional - if controversial - features ready to go [that don't take up much space], that many Windows users use - while Microsoft is being percieved as making catastrophic, once-in-a-generation stumbles with Windows.

It's great for headless servers too; servers that need more _individual_ machine-level physical security, than datacenter-level security. (In that case the Windows-like optional features - as well as all GUI applications and DE stack - can be easily removed with a single provided command. Or just not installed in the first place.)

It would be hard to oversell the notion that the major features complete in Phase I haven't existed before in a single linux distro. (To this author's awareness and research.)

To be clear though, this is not yet a "distro". That's a stretch goal for now, a vision. For now it's a DIY recipe with all-native ingredients, and complete idiomatic build instructions - to put together a Debian-based OS nearly from the ground-up, that handles major ongoing upgrades as the parent distro intends.

You'll probably know if you need the existing "Phase I" features listed below, immediately. If so, it's probably because you've worked with some or even all of these features before. None are new or novel features. Many have appeared in other distros together. They've just never all been in one system at the same time.

<!-- TOC ignore:true -->
## Table of contents

<!-- TOC -->

- [Project challenges - SOLVED](#project-challenges---solved)
	- [ZFS as the root filesystem](#zfs-as-the-root-filesystem)
	- [Luks+LVM+ZFS-aware bootloader](#lukslvmzfs-aware-bootloader)
	- [USB key Luks unlock](#usb-key-luks-unlock)
	- [Ability to unlock Luks at boot-time via SSH, if there is no USB key](#ability-to-unlock-luks-at-boot-time-via-ssh-if-there-is-no-usb-key)
- [Roadmap](#roadmap)
	- [Phase I: Instructions for the DIYer to turn Debian Stable into Tukzedo Linux - COMPLETE](#phase-i-instructions-for-the-diyer-to-turn-debian-stable-into-tukzedo-linux---complete)
		- [Phase I features](#phase-i-features)
			- [Full disk encryption](#full-disk-encryption)
			- [Everything on ZFS](#everything-on-zfs)
			- [Boot-time drive encryption unlock via USB thumbdrive key](#boot-time-drive-encryption-unlock-via-usb-thumbdrive-key)
			- [SSH-capable pre-boot drive encryption unlock](#ssh-capable-pre-boot-drive-encryption-unlock)
			- [Boots directly to the real and final kernel via Unified Kernel Image "UKI"](#boots-directly-to-the-real-and-final-kernel-via-unified-kernel-image-uki)
			- [Signed .efi binaries and Secure Boot-capable](#signed-efi-binaries-and-secure-boot-capable)
			- [An optional additional layer of encryption for individual user home folders](#an-optional-additional-layer-of-encryption-for-individual-user-home-folders)
			- [Secure hibernation](#secure-hibernation)
			- [Doesn't use TPM](#doesnt-use-tpm)
			- [Focused and opinionated](#focused-and-opinionated)
	- [Phase Ib - additional features](#phase-ib---additional-features)
		- [VerifiedBoot](#verifiedboot)
		- [Atomic updates](#atomic-updates)
		- [Pre-boot ZFS snapshot boot selection](#pre-boot-zfs-snapshot-boot-selection)
		- [Combined package manager](#combined-package-manager)
	- [Phase II: Downloadable virtual .img file](#phase-ii-downloadable-virtual-img-file)
		- [Productivity and creative applications pre-installed](#productivity-and-creative-applications-pre-installed)
	- [Phase III: Move beyond the legacy Linux FHS](#phase-iii-move-beyond-the-legacy-linux-fhs)
	- [Phase IV: LiveCD .iso with automated installer](#phase-iv-livecd-iso-with-automated-installer)
	- [Phase V: Official Tukzedo Linux rolling distribution](#phase-v-official-tukzedo-linux-rolling-distribution)
- [How to create Phase I now](#how-to-create-phase-i-now)
- [Document history](#document-history)
- [Copyright and license](#copyright-and-license)

<!-- /TOC -->

## Project challenges - SOLVED

All of these challenges listed have been overcome, for the complete and working Phase I.

But some can and will be continually improved as the project rolls forward, in ways that are more predictive and tolerant of...

- ...Unexpected edge-cases while mounting ZFS as the root filesystem. For example, a system-critical mountpoint already having files in it, thus causing ZFS to balk at mounting over it.

- ...Curious power-users making what would otherwise seem like rational changes to easily-accessible settings, by the seat-of-their-pants - but that would otherwise soft-brick the system. For example, one might reasonably ask, "why is the root filesystem marked as `canmount=noauto`, when everything else is `=on`? Must be a mistake, I should change it to `on`. Oops, now the system won't boot." The system should be more resilient to trivial, reasonable mistakes like that.

- ...Major distribution upgrades that may make sweeping changes to underlying assumptions. So we can't be too narrow in assumptions made, for the sake of expediency and/or brevity. (Not addressing everything that "could" happen in the future - just not being obviously too restrictive in assumptions and underlying conditions that seem tied to arbitrary conditions of a moment in time, and/or that have a history of changing in the past.)

### ZFS as the root filesystem

ZFS carries with it myriad "gotchas" and challenges as a bootable root filesystem, as explained in more detail in [this FAQ section](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md#disadvantages-of-zfs).

As explained in more detail there, this is mostly due to ZFS's origins in large clustered SAN-based environments with strict startup SLAs, and the unwillingness of Oracle to change what has worked in that context. (With OpenZFS tracking Oracle's conservative and clunky corporate decisions closely.)

That link also explains the top specific technical reasons that can make installing, cloning, repairing, and sometimes just successfully _booting_ to root on ZFS, problematic.

It might seem like Btrfs would make a [better choice](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md#btrfs-advantages-over-zfs) as our root filesystem. After all, from day-1 it was designed with local storage and bootable root filesystems in mind. And like ZFS, it's Copy-on-Write, checksums all data and metadata, supports "free" snapshots, and "free" copies via the `FICLONE` ioctl (e.g. `cp --reflink=auto`), etc.

And in many ways Btrfs _would_ be a better choice - and in about ten years, it may be - with hopefully production-ready support for `fscrypt` by then.

However, for now, Btrfs has its own challenges as a root filesystem, although not nearly as many or as severe. But more importantly, it has no native encryption support - which is really the deal-breaker here.

ZFS is an amazing filesystem. It's mainly just quarrelsome when used as a bootable root FS, because that's not what it was designed for.

But as other ZFS-based distros have done, we have worked around the challenges - and in the exact same way they did. However it needs to be _more_ robust than that. More than any other distro has so far accomplished. (Which all basically follow the same recipe since it usually works.) It needs to boot as reliably as, say, ext4 - every time. (Less graceful crash handling of ext4 notwithstanding.) In part, because we know exactly what needs to be done, and it's perfectly sane and reasonable to accomplish (just effort and testing) - so why not. And also because the level of boot reliability previous ZFS-based distros have achieved, just isn't good enough.

### Luks+LVM+ZFS-aware bootloader

No existing bootloader currently supports all of the following:

- Unlock Luks
- Load LVM
- Supports arbitrarily up-to-date ZFS feature flags.
- Doesn't need a separate ZFS filesystem for `/boot`.
- (_And all the other stuff like accept USB key unlock, unlock remotely, console password fallback..._)

Unfortunately, even the excellent and well-regarded ZFS Boot Manager [can't do even the first three points let alone the last](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md#the-well-regarded-zfs-boot-menu-zbm-instead-of-systemd-boot).

Ironically, the absolutely ancient Grub2 is the closest thing that can do the first two points, but requires a separate pool for `/boot` that is limited to older legacy ZFS feature flags, and requires unlocking Luks and loading LVM twice. The reasons why are explained [here](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md#grub2-instead-of-systemd-boot).

The only workaround for this conundrum, currently, turned out to be (arguably) the best way to go for this project anyway: a [Unified Kernel Image ("UKI")](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md#uki-unified-kernel-image).

A UKI avoids the need for a complex ZFS-aware bootloader and allows booting directly to the real, final kernel immediately. (With no ephemeral intermediates like Grub or ZBM, each requiring their own collections of hardware drivers.)

A UKI also allowed placing of the complex logic of unlocking Luks with multiple key options, into arbitrarily complex, Linux-native, fully-functional Bash scripts via `dracut`. And unlike with Grub or ZMB, Luks only needs to be unlocked once - which is both more convenient, easier to script, and more secure.

Far and away more so than the "booting to root on ZFS" challenge, this (necessarily entangled up with USB and SSH unlock) was the toughest nut to crack. <!-- - spanning _years_ of effort, banging-head-against-the-wall, and backing out of dead-ends. Strangely, it took admitting defeat and basically giving up, for the real answer to present itself. (I'm sure there's a more heroic or positive way to frame that, but sometimes things just are what they are. In a Zen way almost like the joke, "Why is it that I always seem to find my car keys in the last place I look?") -->

### USB key Luks unlock

This was also a difficult challenge to solve - in a clean, reliable, portable way that doesn't get clobbered by upgrades. In the end the solution didn't require too much scripting. It was just finding the right places to do it, with the right dependencies. Other working examples weren't much help to solve the problem in a more native way that was desired.

### Ability to unlock Luks at boot-time via SSH, if there is no USB key

This was also another tough one. But once all the pieces were in place, it's elegant enough, maintainable, and upgrade-resistant.

## Roadmap

The vision for Tukzedo Linux is to roll it out in at least one - and up to five - phases:

### Phase I: Instructions for the DIYer to turn Debian Stable into Tukzedo Linux - COMPLETE

__Status__: Done. Instructions documentation and helper tooling are being refined.

#### Phase I features

##### Full disk encryption

The entire OS and all user data, except a cryptographically signed and Secure Boot-compatible Unified Kernel Image ("UKI") `.efi` boot image, is inside an encrypted LUKS2 container.

_Note: "Full disk encryption" has always been a bit of a misnomer, since most non-proprietary all-in-one encrypted system drives have a necessarily unencrypted UEFI partition. It has always been more accurately "Everything but the UEFI partition is encrypted in one container". Even proprietary non-UEFI systems necessarily have __some__ non-encrypted boot component, almost always secured separately by something akin to Secure Boot to prevent or slow-down tampering._

The only things not encrypted by Luks, are the files in UEFI partition. Those are cryptographically signed, and the entire boot chain optionally attested and secured with Secure Boot (not involving TPM) - for protection against remote threats. (Like internet-acquired rootkits.) Complementing that in the near-future, the entire boot chain will also be binary checksummed in a way that can't be tampered with even with physical access (independent of Secure Boot), and the user notified of any changes.

##### Everything on ZFS

The entire OS and user folders reside on ZFS as the only primary filesystem. ZFS was the first mainstream Copy-On-Write filesystem, and still the most robust and feature-complete (though Btrfs is - arguably - slowly catching up). ZFS provides, in part:

- "Free" and "instant" snapshots

- Data integrity checksumming

	- _Also auto-healing if set up in a raid configuration - which is fiddly and impractical to configure for system boot drives_.

- Inline compression and/or encryption

- Automatic snapshot management (with `zfs-auto-snapshot`)

- "Zero-size" file copies (e.g. `cp --reflink=auto`), that unlike hardlinks, can later diverge from the originally shared blocks.

That said, as great and easy-to-use as ZFS is, it can be exceptionally difficult to work with as a bootable Linux system volume; often in very subtle and sometimes boot-breaking ways. A big part of this project has been building setup steps and runtime tooling to make sure those "gotchas" don't happen in a production environment, including across years of upgrades.

In spite of those challenges, ZFS is currently the only viable option to meet the project goals, even over the "close" Btrfs - as explained in the [FAQ](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md).

##### Boot-time drive encryption unlock via USB thumbdrive key

This allows a small USB thumbdrive with an encryption key on it, to be temporarily inserted at boot-time, to decrypt the system drive. Also:

- If not available at boot-time, the system falls back to ssh or console-based password input.

- With the convenience of a USB-based key, the secondary fallback password can be made much more complex, without compromising typical-case convenience.

- The USB-based key can be arbitrarily complex, even binary data.
	- In fact, the key can be an entire photo, music, or executable file. (Which gets hashed to `sha3-512`.)

	- This opens up possibilities like using a seemingly arbitrary executable from what appears to be (and may actually be) a bootable Linux or Windows drive, as the decryption key. (On ext4, FAT32, or exFat USB filesystem.) Or a real image or music file from a working thumbdrive media collection.

##### SSH-capable pre-boot drive encryption unlock

Uses native sshd (not a third-party products like _Dropbear_). If a USB-based decryption key is unavailable or fails, a password prompt will appear on the console as a fallback. During this time, if physical access to the console is not possible or inconvenient, a user with a matching SSH key can remotely access the pre-boot system, and enter the password. Once successful, the boot process will automatically resume.

##### Boots directly to the real and final kernel via Unified Kernel Image ("UKI")

This is for more immediate and direct pre-boot control, and better security. (As compared to the commonly-used legacy _Grub_ bootloader.)

##### Signed `.efi` binaries and Secure Boot-capable

While Secure Boot doesn't have to actually be enabled in your physical or virtual UEFI firmware, it can be for significantly enhanced security from web-based threats. The entire boot chain is signed, so it's ready to go for Secure Boot. As with any such measures, the main protection is against things like remote rootkit malware installation - but not against physical intrusion. (That's in part what the full-disk encryption helps address.)

##### An optional additional layer of encryption for individual user home folders

While not the default, an encrypted user home folder accomplishes two things:

- Protects the logged-out data of current or potentially future multiple sudo-capable users, from each other.

- The full-disk encryption key for this setup can be easily made immune to brute-force or dictionary attacks (e.g. with an arbitrarily long binary key on a temporarily-inserted-at-boot USB thumbdrive). With the right parameters, it is infeasible to break (without zero-day exploits) even for supercomputers and/or GPU farms. And is already post-quantum.

	- OS user passwords, on the other hand, even long ones, are typically very weak by comparison. If you need encryption, you don't want to be encrypting your user data with a "mere" easy-to-remember user password or even phrase.

	- But a user directory encrypted with a weak user password, _inside_ an impenetrable (by comparison) Luks container - now we're cooking with gas. And with careful attention to sector size and alignment, the hardware-accelerated performance impact and additional write amplification are trivial.

	- Note: There is at least one workaround to securing native ZFS encryption, outside the Luks container, with an encryption key that is as strong as a Luks key + user password. (E.g. by automatically generating a ZFS key by appending a long random key for a salt, that is stored on the filesystem inside the Luks container, onto the user login password.)

		- But that would still leave the exposed ZFS filesystem open to metadata inspection and manipulation.

		- Everything else equal, layered encryption is stronger than a single level, even if the combined keys are equally as strong. This is due to the growing risk (thanks in part to AI) of zero-day exploits. With layered encryption, an attacker must defeat two products in sequence.

##### Secure hibernation

The swap (hibernation) partition is securely tucked into the Luks container, but unlike ephemeral encryption on an exposed swap partition, it securely remembers restore state.

##### Doesn't use TPM

While TPM is great for automatically locking and unlocking full-disk encryption (especially with TPM v2 in integrated circuitry), and is perfect for mobile devices such as phones - it's not without obvious drawbacks that it was never intended to solve. And carries unfortunate historical baggage.

All of which the Tukzedo Linux approach sidesteps:

- Systems encrypted with TPM keys aren't easily portable, which obviates a major benefit of Linux. Linux is exceptionally physically portable - the same physical drive can be happily moved to different machines at will, booted via USB adapter, and/or booted into a VM without modification. And back and forth. This fact is also helpful for fixing Linux systems, if the boot process breaks.

	- Full-disk encryption via TPM ties the disk to a single host. While a system can be non-destructively reinitialized to a new TPM chip, it's not a trivial process to be done on a routine basis.

- TPM-based encryption is fundamentally insecure in several scenarios that it was never intended to solve.

	- For example, you may shut down a laptop, thinking the encryption is securely at-rest. However, this can be trivially foiled by... turning on the laptop. At that point, the full disk contents are available - either via weak user account passwords, zero-day exploits, or just the user settings not being configured to lock the screen on hibernation restore. (Or the desktop manager failing to do so as-configured.)

	- If a laptop was hibernated and not fully shut down (which you can never be sure of with macOS or Windows even if you chose "Shut Down"), then a deliberate attcker has all kinds of stuff to discover that will be loaded back into active memory, which may not be transparently encrypted.

	- TPM is a poor choice for desktop computer enthusiasts who frequently upgrade and tweak hardware. It's slightly annoying if your hardware changes enough to prohibit booting with Secure Boot enabled. But that can be easily disabled in UEFI setup. But with TPM refusing to unseal the drive decryption keys at all (a necessary security feature), even with Secure Boot disabled, now the annoyance is greatly compounded.

Note: Microsoft Bitlocker, combined with older TPM v1 on separate discreet chips, was vulnerable to some well-publicized physical attacks involving the proverbial Evil Maid with a soldering iron and alligator clips. It was never a realistic threat to most users worried more about theft from a coffee shop rather than state-sponsored targeted hacks from experts trained to do it in five minutes, but it was still a flashy and impressive exploit shown on innumerable youtube videos.

Microsoft also stores a backup of Windows users' Bitlocker TPM keys in the cloud, by default - and has recently announced it will hand over your decryption keys to law enforcement when asked. (And presumably has been doing so all along.) This can be avoided by either forcing setup with an offline account, and/or reprovisioning your TPM and Bitlocker key - but the potentially irreversible reputational damage has been done.

For those reasons, TPM has become unfairly associated with past flaws of Bitlocker, the weaknesses of TPM v1, and the unfortunate policy decisions of Microsoft. TPM now seems to have a "PR Problem" among many security-minded users.

That specific physical attack on TPM v1 and Bitlocker is no longer possible with integrated TPM v2 circuitry, nor was it ever possible with Luks (which enables the TPM's API that doesn't transmit the unsealed keys to the CPU in clear text over the then-macro-sized TPM circuitry).

Either way, worrying about how old your TPM chip is, or from what vendor, is something that can be easily eliminated - by simply not using it.

The Tukzedo Linux approach also eliminates the unavoidable TPM issue of unlocking the disk contents simply by turning on the machine. (Which again to be clear, is something TPM was _specifically designed to do_, and can be a great convenience and security-enhancer, in the right context.)

##### Focused and opinionated

This is not a "something for everyone" distro like Ubuntu. It is narrowly targeted at a combination of some of the most coveted features by security professionals and tech enthusiasts.

Nearly every feature is possible to install and configure without _too_ much trouble, on nearly any Linux distro. (E.g. Linux-on-ZFS is available on nearly all mainstream distros.) But together all in one working OS - has proven _exceedingly_ difficult. (And yet one main goal is configuration robustness and tolerance to ongoing major version upgrades over time, in the underlying Debian distribution.)

### Phase Ib - additional features

#### VerifiedBoot

"VerifiedBoot" is a custom system in the works that is similar and complimentary to Secure Boot. (And simpler.) It will probably be maintained and published as its own project, and integrated into Tukzedo Linux.

- __Similarities to Secure Boot__:

	- On every boot it verifies that the system hardware, UEFI firmware, and everything that exists on the UEFI partition - has not changed (i.e. tampered with) - since the last kernel & UKI `.efi` build.

- __Complimentary differences to Secure Boot__:

	- VerifiedBoot doesn't require physical security to be trusted (although that always helps), unlike Secure Boot, which can be disabled in the machine's UEFI setup. This is the main impetus behind VerifiedBoot.

		- Secure Boot was always intended to protect against _remote_ threats such as silent web-based rootkit installation. Not if attackers gain physical control.

	- Doesn't rely on cryptographic signing, but instead on binary content checksums. (This accomplishes overlapping goals, but will also catch files that haven't been signed. In fact, will work without any cryptographic signing at all.)

	- All executables and data required for VerifiedBoot reside _inside_ the encrypted Luks container, and thus can't be disabled or tampered with as easily as physically disabling Secure Boot. (And if an attacker _could_ disable VerifiedBoot inside the encrypted container, then you have much bigger problems to worry about.)

		- In this way, it is highly complementary to Secure Boot. Each can do some things the other can't and wasn't designed for.

	- If there's no encrypted container to work inside of, VerifiedBoot would be a moot point, and a quick check to insure that's the case will be implemented.

	- As a result of the previous requirement of the encryption container, it will necessarily have to work later in the boot process than Secure Boot. That's both "more" secure, and "less" secure than Secure Boot, by two different perspectives and criteria. And either way, complimentary.

	- By default, it won't prevent booting if it detects a change, as Secure Boot does. (But optionally could.) Instead, it will alert users who log in, to the specific things that changed. (Or if they don't have sudo rights, just that there _was_ a suspicious change.)

	- Will have user-configurable levels of detection and warning. Some desktop enthusiasts, for example, may not want it to complain about minor (or any) hardware changes.

#### Atomic updates

Some immutable & atomic Linux distributions use Btrfs as the underpinning for both.

ZFS can serve the same purpose just as easily. (And already does, for multiple open-source projects. If not all exactly for inherent update atomicity, then they accomplish a similar effect by allowing user-selection of a prior known-good boot environment.)

As discussed in more detail in the [FAQ](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md), This OS intentionally won't be _immutable_. It's a genuinely useful feature in certain contexts - e.g. when built into a completely locked-down device from the ground up, that also includes some form of integrated TPM, cryptographic secure boot, and encrypted storage that can't be disabled. And encrypted memory. (E.g. iOS devices - arguably the most secure computers in history. Which there's no shortage of demand for. But they're also the least flexible; obviously an acceptable tradeoff to most people with a small device prone to loss or theft.)

But for a distribution and target audience like this, immutability isn't worth the necessary tradeoffs and inconveniences that inherently come with it. Especially when primary security is achieved through at-rest encryption, and live user account access restrictions - the latter which is a necessary basis for immutability in the first place. Once a user has `sudo`, immutability is just "inconvenient extra steps", not layered security or tamper prevention. The same applies to malware or targeted attacks, most of which must first achieve privilege escalation. (That is not the case with "true" layered security, like layered encryption - where once you're through the first layer either through brute-force, dictionary attack, or exploit - then you have a second layer to do all over again.)

But atomic system updates - where it either succeeds completely or nothing happens at all - that is a broadly useful feature that would be hard to argue against. Copy-on-Write filesystems make such atomicity easier to achieve.

#### Pre-boot ZFS snapshot boot selection

This would use the same basic underpinnings as atomic upgrades. Both may or may not leverage the existing tool `beadm` (probably not).

While conceptually similar to atomic updates, adding an optional ability for users to select an environment at the pre-boot stage (with a default selection and timeout), may be a herculean task, and possibly the first one to be pushed to a later phase. The [ZFS Boot Menu](https://github.com/zbm-dev/zfsbootmenu) ("ZBM") project tackled this, with the tremendous effort of more than one contributor. (The FAQ [addresses](https://github.com/t00mietum/tukzedo-linux/blob/main/FAQ.md#the-well-regarded-zfs-boot-menu-zbm-instead-of-systemd-boot) why it couldn't be used for this project.)

So, given the way Tukzedo Linux is architected, the only way this feature could be realized, is one or more of:

- A non-hacky, fully supported, Linux-native solution that allows boot environment selection, __in the init phase__, _after_ Luks is unlocked and LVM loaded. Possibly even after the zpool itself is imported. But either way, _before_ a specific filesystem within is mounted as root. This would bypass almost all of the work that ZBM has to do (and in fact _can't_ do in our case), or that Grub addons struggle to do - and get right to the heart of the matter, where it all goes down. In such a simple and obvious way that it could be (and would likely have to be) scripted, and integrated with `dracut`. Whether this is possible or not remains to be seen. It seems likely from this vantage point.

- Or, if ZBM ever adds native support for decrypting Luks and loading LVM.

#### Combined package manager

In the next phase, a downloadable virtual `.img` file, will have some `flatpak` applications, and at least one `.AppImage` application. (Among it's base of native `apt` system and user applications.)

So it would be nice to have an update manager that can holistically update, install, and remove applications from and/all three. This will be a handy tool before an `.img` release. There's already a working version that snapshots the filesystem and updates `apt` and `flatpak` in one go. They have very similar command-line interfaces.

Adding in the very nice `.AppImage` application packaging standard (with the help of [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate) and [appimaged](https://github.com/probonopd/go-appimage/blob/master/src/appimaged/README.md)), will help to take it the rest of the way.

The high-level idea being a command - let's call it `tkz_packager`, that accepts the options below, and might look something like this:

- __--update__

	~~~bash
	## Snapshot (rpool_t4frb/deb/ROOT has everything necessary to fully roll back a botched update)
	sudo zfs snapshot rpool_t4frb/deb/ROOT@$(date "+%Y%m%d-%H%M%S")_${DTOFFSET}_tkz-packager_pre-update

	## Apt
	sudo apt update
	sudo apt dist-upgrade
	sudo apt autoremove  ## Clean up after previous update and any removals from dist-upgrade

	## Flatpak
	sudo flatpak --system update
	flatpak      --user   update
	sudo flatpak --system autoremove
	flatpak      --user   autoremove

	## AppImage
	sudo find / -mount -iname ".appimage" \
		-not -regex '.*/\(boot\|dev\|home\|media\|mnt\|proc\|run\|tmp)/.*'
		-print0 2>/dev/null | parallel sudo appimageupdatetool --appimage-only "{}"
	find ${HOME} -mount -iname ".appimage" \
		-not -regex "${HOME}/\(mnt\|tmp)/.*" \
		-print0 2>/dev/null | parallel appimageupdatetool --appimage-only "{}"
	~~~

- __--update-no-remove__

	Almost the same as `--update`, but only does regular `sudo apt upgrade`, and no `apt` or `flatpack` "autoremove" commands.

- __--install APPNAME__

	Search all repos for APPNAME, present user with a list of app, version, date, and which repo. (With a configurable AppImageHub as the default for `.AppImage` searches.)

- __--remove APPNAME__

	Present any installed hits from `apt` and `flatpak`, and search the filesystem for `.AppImage` matches, similar to method in `--update`.

- __--purge APPNAME__

	Use built-in commands for `apt` and `flatpak`. For `.AppImage`, will have to settle for `$matching_name.home` and/or `$matching_name.config`.

### Phase II: Downloadable virtual .img file

__Status__: Not started.

__Phase II features__:

- Provide a fully-functioning system via a downloadable `.img` file, to either load in a VM, or `cat` to a real drive and boot live metal from.

	- Like many such images, it would contain a default user account to get going. From there, users can create new accounts and delete the default one.

	- A tool will (or could ideally) be provided that compares all distribution binary file checksums to some verified Debian source, so that users can trust the image is a clean and uncompromised system base to get going from; it should also list every discovered file that isn't included from Debian repositories, for manual inspection.

- Mostly Flatpak applications for slightly better security, but more importantly minimum upgrade conflict and generally more recent versions. (A current and ongoing feature into future phases.)

- This would likely ship with only one Desktop Environment choice - although swapping them out is trivial for users, and multiple at the same time are usually fine. Top candidates: XFCE, Cinnamon, KDE. (Not candidates as a default, out of personal preference: Gnome, LXDE, MATE. And not any of the micro-desktop environments, at least not alone.)

#### Productivity and creative applications pre-installed

At the top of _secondary_ goals of this phase of the project, is to entice regular Windows users who are frustrated with the modern Windows 11 experience. (E.g. Copilot, OneDrive, Teams, Edge; forced Microsoft online account, ads in the Start Menu, bloatware for Microsoft's benefit rather than users, storing users' hardware TPM keys in the cloud, sharing those keys with law enforcement, "black screen of death" updates, etc.)

What is explicitly not a high priority for this phase of the project, is passing "open-source purity tests".

<!-- Even the most pure and open of open-source projects, still require substantial help from closed-source microcode blobs. There is no truly 100% open-source OS, unless running on fully open-source hardware that average users can't buy and probably wouldn't want to. So the question becomes, where do you draw the line? -->

We believe the most effective way to maximize the adoption of open-source as broadly as possible, is to consider it a discussion of pros and cons among reasonable people, not a red line that someone decides on behalf of others. The 800 lbs gorillas of the consumer/professional desktop and laptop OS markets are stumbling due to self-inflicted wounds. Now is the time to aggressively take advantage of that, to get open-source into as many hands as possible - even if not "pure".

This project includes a curated, opinionated set of creativity and productivity software - that is mostly linux-native and open-source. Also included is a small set of closed-source (but free) creativity software, and even in at least one case, a free _Windows_ program.

These don't consume much space alone, relative to the rest of the OS installation size and modern drive capacities. But either way, anything not desired can be easily uninstalled.

The applications:

- __LibreOffice__ - productivity suite. As standard on most distributions. <!-- Open-source and Linux-native. We prefer this over "OnlyOffice". The latter looks more like Microsoft Office (aka "Microsoft 365 Copilot App"), but we've found OnlyOffice to have serious usability problems that has resulted in data loss before. And while open-source, its Russian origins make us a little uneasy. On the other hand LibreOffice is solid, stable, reliable, and has no questionable origins. -->

- __Affinity Photo__ for Windows - argued by many photographers to be a legitimate rising challenger to Photoshop. Packaged as a single `.Appimage` executable, complete with the requisite WINE layer and settings, by [this](https://github.com/ryzendew/Linux-Affinity-Installer) github project.

- __Photopea__ - a free Photoshop clone, that runs as a Progressive Web App. After the initial load, it runs 100% offline and locally. (It's closed-source but the JS can at least be deminified, deobfuscated, prettified, and inspected for safety.)

- __digiKam__ - feature-rich photo management application. (Not an editor.) Linux-native, open-source. Some overlapping features with Adobe Bridge.

- __darktable__ - currently one of the most popular open-source alternative to Adobe Lightroom.

- __Rapid Photo Downloader__ - photo and video card-downloader/renamer/organizer. Linux-native, open-source.

- __Reaper__ - digital audio workstation. Closed-source, but Linux-native. The free trial never expires.

- __Audacity__ - digital audio file editor. Open-source, Linux-native.

- __DaVinci Resolve__ - Video non-linear editor in the vein of Adobe Premiere. Linux-native, free, but closed-source. Allegedly a favorite for color-correction in some big-budget movie post-production studios.

- __Kdenlive__ - Highly-regarded Linux-native, open-source video NLE. Arguably not as advanced as DaVinci Resolve.

- __Blender__ - 3D modeling application that arguably covers some 70-80% of Autodesk Maya features, and 50-60% of 3ds Max features - as a Linux-native open-source applications. Award-winning movies have been made using only Blender (e.g. "Flow", "Sintel", others).

- __Steam__ - Windows and Linux game manager. This application may be a significant factor in the steepening rise of Linux Desktop market share recently. Many of the most popular Windows games install and run through the Steam application just as well as they on Windows. (Though games with aggressive Windows boot-time kernel-mode anti-cheat drivers can be problematic.) If a Linux version of a game is available, Steam will preferentially install that instead. It doesn't come with games - it manages ones you have or buy through the Steam Store, and manages it's own versions of the open-source Proton (WINE+Vulkan extensions) Windows compatibility layer.

- __Bottles__ - WINE manager. The recursive acronym means "WINE Is Not an Emulator. It's an API "thunking layer" to convert Windows API calls to Linux - while the application code itself (e.g. complex loops that don't involve API calls) executes natively. WINE can run 16-bit Windows applications, which not even Windows can anymore. Bottles is is open-source and Linux-native, and smaller in scope than Steam. (Bottles is generally better for installing your own small Windows applications.)

- __Lutris__ - multi-platform game emulation launcher and organizer. It can manage emulators and (your own) games including DOS, Windows, Xbox, Xbox 360, PlayStation II, Atari, Wii, N64, NES, Apple IIe, Commodore, and arcade games. Lutris itself is Linux-native and open-source.

- __Compiz__ - Yes, _that_ beloved Compiz, the advanced compositing window manager. The project died once, then came back to life for a time which few seemed to notice; then it fell back into unmaintained status again. Because of that, it's not enabled by default - just installed, pre-configured, and with convenient desktop launchers to enable and disable. It's still in the official Debian apt repos, and with the right settings (as defaulted in Tukzedo Linux), is just as stable as other native Xorg DE window managers such as `xfwm4`. On reasonably modern hardware it runs just fine even in a virtual machine without GPU acceleration. Unfortunately though, the good times probably won't last forever: eventually Compiz will surely suffer from "dependency bitrot" that even the Debian maintainers can't keep up with - not without reviving the project completely. And it will likely never be Wayland-compatible.

### Phase III: Move beyond the legacy Linux FHS

__Status__: Proof-of-concept started.

__Phase III features__:

- Provide a modern filesytem structure that moves forward from the Linux _Filesystem Hierarchy Standard_ (FHS), but in virtual form without breaking anything.

- The legacy Linux FHS will still have to exist for compatibility purposes, but is hidden from regular users, and a more modern hierarchy shown in its place.

- Users can choose to view the system as a modern filesystem, or the legacy FHS - and back and forth at runtime, without a reboot or logout.

	- By default, new users are shown the new virtual filesystem, with the legacy FHS hidden.

	- By default, user `root` or `sudo -i` is shown the legacy FHS.

	- Either can switch to the other view.

- Regardless of which hierarchy is shown to the user, direct access to either one (e.g. specific named paths) are honored.

- Experienced Linux users tend to be resistant to change, and almost surely won't like this - and would likely choose to only ever see the legacy FHS.

- How it works:

	- A filesystem filter driver intercepts calls (see source code proof-of-concept in this repo), and optionally remaps them. Only directory listings ("navigate via discovery") are remapped. But any direct reference to an explicit file or directory - either to an original FHS or new virtual FHS - will work. (Thus all existing kernel ABIs and userspace tools and applications will work - definitionally as a passing test condition. If not, it's a failing bug.)

	- This is (comparatively) trivial to do with FUSE (e.g. override `opendir`, `readdir`, `stat`, and remap `lookup`s), which will be the proof-of-concept and first version. But if it works well and test users like it, it will need to be implemented as a Kernel Loadable Module that registers itself as a stackable file system that intercept and modifies VFS operations. That's significantly harder, as there is quite a bit of "real filesystem" work that must be done (which the userspace FUSE project takes care of for the developer). But many existing projects do very similar if not _almost_ identical things at the kernel level, such as OverlayFS. The open-source code from such a project will need to be heavily borrowed from.

	- A real-world example of this in action, is ZFS's virtual `.zfs` hidden folder for each mounted filesystem. It's not just "hidden" by convention in the sense that it's a dotfile. It is literally invisible (by default) to any tool or application. It can't be navigated to via discovery (e.g. browsing via file manager or directory listing). _But_ if you type the specific magic path in manually to any application, it's there, along with all of its contents. Furthermore, you can set a flag on the ZFS filesystem to show it as a regular folder, and then it's visible normally, immediately. (But ZFS is itself a fully-formed filesystem, so such a simple dynamic realtime remapping is presumably trivial for it.)

	- Any performance impact would need to be imperceptible and close to not measurable in controlled tests.

	- For advanced users and server admins, the feature must be able to be disabled completely, so that there is nothing in-between user code, and the real top-level filesystem.

### Phase IV: LiveCD .iso with automated installer

__Status__: It's doubtful that this author will ever have the bandwidth to do this alone, and vibe-coding is not (yet) something that people can really trust for something as important as an OS installer. But maybe someday it will be, and/or other interested humans will pitch in.

__Phase IV features__:

- All the usual contents of a distro LiveCD: Boots directly into a decent minimum user environment, with a text and/or GUI installer available. Just like most LiveCDs.

### Phase V: Official _Tukzedo Linux_ rolling distribution

__Status__: The only way this will happen, is if the project gains so much traction that it's inevitable. To be realistic, this is pretty unlikely. Otherwise, this author personally will never have the bandwidth to create the infrastructure for such a thing.

__Phase V features__:

- Initially a repackaging around Debian Stable, as most new Debian-derived distros do.

- Eventually, with enough resources, moving to Debian Testing or Unstable - in order to provide a true rolling release.

	- Both Debian Testing and Unstable are effectively "rolling releases", except they periodically freeze progress, sometimes break, and/or core packages are temporarily removed from previously working systems along the way.

	- Basing a rolling release on Debian Testing or Unstable would be conceptually harder than what Ubuntu does - pulls from Unstable at the start of each development cycle, and stabilizes independently from there. However, a far more limited scope could likely turn that tide back - as might a future where AI-assisted CD/CI tools may more reliable and autonomous. (A potential AI future where essentially anyone can - and maybe everyone will - maintain their own robust and secure rolling distribution.)

## How to create Phase I now

There is currently one guide: ["Tukzedo Linux on Debian"](https://github.com/t00mietum/tukzedo-linux/blob/main/guides/tukzedo_debian_13_trixie/creation.md)

## Document history

- 2026-03-31: First "real" draft.
- 2026-04-13: Expanded.
- 2026-04-15: Expanded and fixed a few minor technical and factual inaccuracies with the help of an LLM.

## Copyright and license

> Copyright © 2026 t00mietum (ID: f⍒Ê🝅ĜᛎỹqFẅ▿⍢Ŷ‡ʬẼᛏ🜣)<br>
> Licensed under GNU GPL v2 <https://www.gnu.org/licenses/gpl-2.0.html>. No warranty.

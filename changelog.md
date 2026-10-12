<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD024 -- No duplicate headings [OK with no TOC] -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->
<!-- markdownlint-disable MD055 -- Table pipe style [Expected: leading_and_trailing; Actual: leading_only; Missing trailing pipe] -->
# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
## NEXT VERSION

### Notes

### Added

- `tkz_zfs-mount` mounts a dataset tree and keeps every mountpoint dir empty and `chattr +i`. Stray files found in a mountpoint get moved to a quarantine folder, never deleted. `tkz-zfs-mount-audit.service` checks every mountpoint once per boot. [20260907]

- `tkz_user` adds a user with an optional encrypted ZFS home, moves an existing home onto one, changes passwords, and shows each home's status. [20261011]

- LUKS can unlock at boot from a USB stick that has a key file on it. The key file can be any file that never changes, such as a photo. It's set in `/etc/tukzedo/usb-unlock.conf`. Typing the passphrase, or unlocking over SSH, still works. [20261011]

- `tkz_resign-sdboot` re-signs systemd-boot after an apt upgrade, so it still boots with Secure Boot on. [20261011]

- `tkz_user hold <user>` keeps the logout watchdog away from that user's home until `tkz_user release <user>`, or a reboot. [20261012]

### Changed

- `guides/.../creation.md` is rewritten as a complete build procedure. There's no Grub or boot pool. Signed UKIs go on a 4 GiB ESP, LUKS unlocks over SSH or from a USB stick, root is on ZFS, most users get an encrypted home, and the drive boots on Intel, AMD or Nvidia graphics. [20261011]

- `tkz_rebuild-uki` works with any pool name, and signs the systemd-boot copy that shim loads. [20261011]

- The logout watchdog and `tkz_zfs-mount` keep their locks in `/run/tkz`, which only root can get into. Before, any user could stop the watchdog, or block encrypted-home logins, by making the lock file first in `/dev/shm` or `/run/lock`. [20261012]

- `tkz_zfs-crypthome_login` mounts through `tkz_zfs-mount`, and falls back to plain `zfs mount` if the helper is missing. [20260907]

- The logout watchdog runs from a systemd timer every 5 minutes, plus a PAM `close_session` hook, so a home locks soon after its user logs out. This replaces the hourly cron job. A run that hangs gets killed by the unit's start timeout. [20260907]

### Removed

### Other work
-->

## v1.0.0-beta1

### Added

- Improved `install_dev.bash`; gets list of files to install from API, rather than hard-coded.

- Updated `tkz_rebuild-uki` to be more complete, ignore Grub by default, and check if `/boot/efi` is mounted before running.

- Added (and bugfixed) `tkz_insure-efi-mount`, already existed in a different (non-github) project.

- Added scripts that make the guts of Tukzedo. [20260601]

### Other work

- Finished first full draft of README.md [20260416]

- Finished first full draft of FAQ.md [20260416]

- Finished first full project structure [20260416]

- `guides/.../cloning.md` now has all the steps in it from the original `bash` format, but most are HTML-commented out because the formatting breaks `.md`. [≅20260414]

- `guides/.../creation.md` now has all the steps in it from the original `bash` format, but most are HTML-commented out because the formatting breaks `.md`. [20260415]

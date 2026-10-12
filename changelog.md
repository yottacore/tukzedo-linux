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

### Changed

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

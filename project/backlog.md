<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD055 -- Table pipe style [Expected: leading_and_trailing; Actual: leading_only; Missing trailing pipe] -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->

<!-- TOC ignore:true -->
# Project backlog

This is a product backlog just for pre-v1.0.0 release. After that, bugs, features, and enhancements will be managed in Github Issues, and/or [todo.md](../todo.md)

<!-- TOC ignore:true -->
## Table of contents

<!-- TOC -->

- [Conventions](#conventions)
- [First steps](#first-steps)
- [Backlog](#backlog)
	- [Bugs](#bugs)
	- [New features and enhancements](#new-features-and-enhancements)
	- [Deferred](#deferred)
	- [Canceled](#canceled)
- [Application name ideas](#application-name-ideas)

<!-- /TOC -->

## Conventions

In each section, items are listed approximately from newest to oldest.

Mark boxes with ✔️, 🚫, or ◐. Empty means not started, or WIP.

## First steps

## Backlog

### Bugs

- The logout watchdog locks a home whose key an admin loaded on purpose, within seconds. Any SSH session closing starts it, root's included, as does its 5-minute timer.
	- Opened: 20261012-071500
	- Keys loaded so `tkz_user passwd` can skip the current-password prompt get unloaded again before it runs.
	- A runtime mask doesn't help, since the unit file in `/etc/systemd/system` wins over `/run`. Taking the exec bit off the script works as a stopgap.
	- Wanted: a documented way to pause it, such as a flag file the watchdog checks, or a per-dataset property meaning "held open by an admin".

- ✔️ `tkz_zfs-mount --audit` and `--audit-all` tried to quarantine the whole live root, on root-on-ZFS.
	- Opened: 20261011-191500
	- Cause: for the dataset mounted at `/`, `fWithRawDir()` looked up the filesystem holding `/`, which is `/` itself, so the bind view was the full root.
	- Seen in a dry run on a fresh install: "would move 23 entries out of '/'". Enabling `tkz-zfs-mount-audit.service` as the guide said would have done it at boot.
	- Fixed: `fWithRawDir()` skips `/`.
	- Closed: 20261012-073244
	- Test case: none. No harness covers the mount helper yet.

- ✔️ A `systemd-boot` package upgrade replaced the MOK-signed `grubx64.efi` copies on the ESP with unsigned builds. With Secure Boot on, the next boot fails.
	- Opened: 20261011-193000
	- Cause: the package runs `bootctl update`, which updates every copy it recognizes as systemd-boot. `tkz_rebuild-uki` re-signs them, but only on kernel upgrades.
	- Fixed: new `tkz_resign-sdboot`, run from an apt `DPkg::Post-Invoke` hook. It re-signs only copies whose signature fails `sbverify`.
	- Closed: 20261012-073244
	- Test case: none. No harness covers package hooks yet.

- ✔️ `tkz_rebuild-uki` cleared the cachefile only on the hard-coded pools `rpool_t2nsn` and `bpool_t2nsn`, and required the bpool force-import dracut module.
	- Opened: 20261011-175000
	- Fixed: it clears the cachefile on whatever pools are imported, and no longer expects a bpool. Error paths that called a nonexistent `error` command now print.
	- Closed: 20261012-073244
	- Test case: none. No harness covers the UKI build yet.

- ✔️ Early boot wrote into the root dataset under `/var/lib` before the `/var/lib` dataset was mounted.
	- Opened: 20261011-190000
	- Cause: `zfs-mount.service` mounts with `zfs mount -a`, which systemd can't order against. `systemd-random-seed` wrote `/var/lib/systemd/random-seed` first. Separately, dracut's `nfs` module mounted `rpc_pipefs` under `/var/lib/nfs` from the initrd.
	- Fixed in the install guide: the OpenZFS mount generator (`/etc/zfs/zfs-list.cache/`), encrypted homes marked `org.openzfs.systemd:ignore=on`, and `nfs` added to `omit_dracutmodules`.
	- Closed: 20261012-073244
	- Test case: none. The fix is in the guide, not in code.

- ◐ The logout watchdog treated a user logged in only through `su - <user>` as logged out. It killed their shell and locked their home under them.
	- Opened: 20260914-101411
	- Cause: `su` opens no logind session and writes no utmp record, and the watchdog only asked logind and `who`.
	- Seen on b23 on 20260914. The 09:20:06 pass SIGKILLed a live `su - collierjr` shell, then unmounted and locked the home.
	- Fixed in `tkz_zfs-crypthome_logout-watchdog`:
		- A user with any process on a TTY counts as logged in.
		- It checks again for a login before each rung that signals or forces.
		- A process on a TTY is never signaled, whoever owns it. While one holds the tree there is no forced or lazy unmount. The pass fails and the next one retries.
		- `closing` stays out of the in-use states on purpose. A comment now says so.
	- Deployed to b23 on 20260914. The pause drop-in is removed and the timer is enabled again. Its first pass ran clean and left the logged-in user alone.
	- Still open:
		- Confirm on b23. With no desktop session for the user and only a `su -` shell open, run `sudo tkz_zfs-crypthome_logout-watchdog --dry-run` from a different account. It should log "has a process on pts/N" and leave everything alone.
		- The 09:03:22 pass found nothing holding the home and ran moments after a desktop login. Its cause is not confirmed. The unmount rungs that don't signal still run without a second check, so a login in that window can have idle child datasets unmounted under it.

### New features and enhancements

- A GUI for `tkz_user`: add a user with or without an encrypted home, change a password and the home key together, and migrate a plain home to encrypted.
	- Opened: 20261011-194500
	- The CLI does all of this now.

- Plain `passwd` changes only the login password. An encrypted home keeps its old ZFS key, and the next login fails to unlock it.
	- Opened: 20261011-194500
	- `tkz_user passwd` does both. A `pam_exec` hook on the password stack could do it for every password change, `passwd` and desktop tools included.

### Deferred

### Canceled

## Application name ideas


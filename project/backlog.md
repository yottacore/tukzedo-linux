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

- `tkz_rebuild-uki --all` leaves the UKIs it already rebuilt unsigned when a later kernel fails to build. With Secure Boot on, the default entry and its fallback won't boot.
	- ID: Code Review 20261012 item 1
	- Type: Bug
	- Severity: Critical
	- Opened: 20261012-090724
	- Origin: 118da99. No earlier review. Confirmed with stubbed `dracut` and `sbsign`: of 3 kernels, the newest failed for lack of `zfs.ko`, and the other 2 were left unsigned on the ESP.
	- Cause: dracut overwrites each UKI on the ESP in place, and signing waits until every build is done. `set -e` stops at the first failed build. That failure is the newest-kernel-without-ZFS case the n-1 default exists for, and `--all` is the documented deploy step.
	- Probable fix: build each UKI off the ESP, sign and `sbverify` it, then `mv` it into place, one kernel at a time.

- `tkz_user migrate` moves the contents of any directory into the user's home, and gives the user ownership, if `~/cache`, `~/tmp` or `~/var` is a symlink to it.
	- ID: Code Review 20261012 item 2
	- Type: Bug
	- Severity: Critical
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Confirmed: the migrate loop run with `zfs` stubbed moved a symlinked target's files into the new home.
	- Cause: `rsync -a` keeps the link, `[[ -d ]]` and the `mv .../*` glob follow it, and `fFixOwnership` then runs `chown -R`. A link to `/etc/mok` or `/root/.ssh` empties it.
	- Probable fix: skip any child that is a symlink.

- A `tkz_user migrate` that fails partway locks the user out. Every later login is refused until the leftover dataset is cleaned up by hand.
	- ID: Code Review 20261012 item 3
	- Type: Bug
	- Severity: Critical
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Confirmed: the login helper, run against a stubbed `zfs` in that state, refused the login.
	- Cause: the temp dataset gets the automount user property when it is created, keyed to the new password. The login password changes only at the end. An rsync error, a busy unmount or `~/tmp` being a file stops it in between.
	- Probable fix: set the property after the final rename, and add an EXIT trap that rolls back.

- Any user can stop the logout watchdog, and can block encrypted-home logins, by creating a lock file first.
	- ID: Code Review 20261012 item 4
	- Type: Bug
	- Severity: Critical
	- Opened: 20261012-090724
	- Origin: 11a730b (watchdog), 1a19cbe (`tkz_zfs-mount`), a6cf5dc (`tkz_user`). No earlier review. Confirmed downstream: with a lock file root couldn't open, `tkz_zfs-mount` failed and the login helper refused the login.
	- Cause: the locks sit in `/dev/shm` and `/run/lock`, which are world-writable and sticky. With `fs.protected_regular=2`, root can't open a file another user created there. The PAM line is `requisite`, and the fallback only covers a missing helper, not a failing one.
	- Sweep: `tkz_zfs-crypthome_logout-watchdog`, `tkz_zfs-mount`, `tkz_user`.
	- Probable fix: a root-only dir such as `/run/tkz/`, or `flock` on the script file itself.

- `tkz_zfs-mount` quarantine follows a symlink named `.tkz_premount-quarantine`. Root then makes the target mode 700 and moves files into it.
	- ID: Code Review 20261012 item 5
	- Type: Bug
	- Severity: High
	- Opened: 20261012-090724
	- Origin: 1a19cbe. No earlier review. The mechanism is confirmed in a simulation. A user can plant the link wherever a raw mountpoint dir sits under a dir they can write, such as a home whose child datasets were partly unmounted.
	- Probable fix: refuse a base that is a symlink or not owned by root, and create it with `mkdir -m 700` without `-p`.

- On branch `zfs-import`, `tkz-zfs-import.service` can be skipped silently at boot, because it runs its script from `/usr/local`, which may not be mounted yet.
	- ID: Code Review 20261012 item 6
	- Type: Bug
	- Severity: High
	- Opened: 20261012-090724
	- Origin: e932ac2, unmerged. No earlier review. Plausible.
	- Cause: `/usr/local` is its own dataset, and the unit has `DefaultDependencies=no` with nothing ordering it after `usr-local.mount`. When the mount loses the race, `ConditionFileIsExecutable` skips the unit with no error, so the cache file stays and declared pools aren't imported. ExecStop can lose the same race at shutdown.
	- Probable fix: install the script under `/usr/sbin` as the initrd does, and run it from there.

- On branch `zfs-import`, `zfs_force=1` force-imports every pool the initrd can see. The docs and `zfs-pools.conf` say pools outside the list are never forced.
	- ID: Code Review 20261012 item 7
	- Type: Bug
	- Severity: High
	- Opened: 20261012-090724
	- Origin: e932ac2, unmerged. No earlier review. Confirmed in Debian's 90zfs source (2.3.9): `zfs_force=1` adds `-f` to the initrd's `zpool import -aN` scan.
	- An external pool, or a disk passed through from another running host, gets force-imported at boot. That can corrupt it.
	- Against: the recorded "keep every import layer" decision lists `zfs_force=1` as a layer. Dropping it reverses that. Correcting the docs does not.
	- Note: the error text "rpool_edkh3: no such pool available" points more toward the scan racing LVM than toward a stale hostid. The retry with `lvchange -ay` covers that case without `-f`. Check `journalctl -b` on b28l before deciding.
	- Decisions: 20261012. Force-import only pools whose devices are inside the LUKS container. Pools outside it are never forced, whether or not they are in `zfs-pools.conf`. This replaces the blanket `zfs_force=1` layer.

- On branch `zfs-import`, a hung `zpool`, `lvm` or `udevadm` call in the initrd hangs the boot forever, with no emergency shell.
	- ID: Code Review 20261012 item 8
	- Type: Bug
	- Severity: High
	- Opened: 20261012-090724
	- Origin: e932ac2, unmerged. No earlier review. Confirmed with a stub `zpool import` that sleeps: the script ran past its own deadline, which is only checked between attempts.
	- Cause: `tkz-zfs-import-root.service` has `TimeoutStartSec=infinity`, and its comment says the script stops itself.
	- Probable fix: `TimeoutStartSec=5min`.

- The build guide's recovery steps fail. The copy of `tkz-vars.sh` it says to save has no UUIDs, and the ESP gets mounted twice, so `zpool export` fails at the end.
	- ID: Code Review 20261012 item 9
	- Type: Bug
	- Severity: High
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Confirmed from the guide's step order.
	- The guide says to copy the file off before partitioning, and the UUIDs are appended after. "Get back in" then opens LUKS and mounts by empty UUIDs.
	- "Get back in" mounts the ESP, then "Enter the chroot" mounts it again. Teardown unmounts it once, so the root stays busy, and the next import needs `-f`.

- The build guide's large-key-file advice uses the wrong `cryptsetup` flag. Followed as written, USB unlock silently falls back to the passphrase prompt.
	- ID: Code Review 20261012 item 10
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Confirmed against the `cryptsetup-luksAddKey` man page.
	- For `luksAddKey`, `--keyfile-size` limits the existing key. The new key file needs `--new-keyfile-size`. The keyslot ends up holding the whole file, while `usb-unlock` reads only `KEYFILE_SIZE` bytes. The test step after it also lacks `--keyfile-size`.
	- Sweep: the same advice is in the `usb-unlock.conf` comment.

- The build guide and README say a USB key file that is one photo among many doesn't stand out. Its stick UUID and path are stored in plain text in the UKI on the unencrypted ESP.
	- ID: Code Review 20261012 item 11
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Confirmed: `99usb-unlock/module-setup.sh` installs `/etc/tukzedo/usb-unlock.conf` into the initrd, so `lsinitrd` on a stolen drive names the file.
	- The default key name `.keys/<mUID>.hex` also matches the plaintext LUKS label.
	- Probable fix: state the exposure plainly. Hiding the path needs a different design, filed under enhancements.

- `tkz_rebuild-uki`'s preflight only warns, and part of it never runs. A renamed `zz-rebuild-uki` hook or a missing `x-systemd.after` lets the build go ahead after a 10-second pause.
	- ID: Code Review 20261012 item 12
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: fe1a936 and 7fe69b2. No earlier review. Confirmed by reading.
	- details.md calls the preflight a hard assert. `requiredFiles` (the usb-unlock module, `/root/.ssh/*`) is filled but never checked. Branch `zfs-import` adds the `forbiddenModules` check and leaves `requiredFiles` alone.
	- The local array is declared as `...DirsAndOrContent`, while the code uses `...DirsOrContent`, so the real array is an accidental global.

- The helper scripts in `utility/` don't work. `do_init.bash` and `do_init_user-specific.bash` source `core.sh`, which doesn't exist, and `core.bash`'s hostid check always passes.
	- ID: Code Review 20261012 item 13
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: 42ded6a, the first commit. No earlier review. Confirmed.
	- The hostid pipe ends in `od ... /etc/hostid`, which ignores its input, so both lines read the same file. The byte order is also reversed from what `hostid` prints.
	- `core.bash` still sets up `bpool_*`. `fPrepareZfsForReboot` turns on `zfs-import-scan` on the rescue host, which then auto-imports any attached pool at its next boot. Plausible.
	- Probable fix: move `utility/` to `legacy/` unless something still uses it.
	- Decisions: 20261012. Nothing still uses `utility/`. Move it under `legacy/`, and drop the cloning.md step that copies it.

- `tkz_user migrate` copies a home that is still in use when the user is logged in only through `su -`, on a TTY, or by cron.
	- ID: Code Review 20261012 item 14
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Plausible.
	- It asks only `loginctl`, which the watchdog's recorded TTY rule says isn't enough. Writes after the copy go to the old home, and a busy unmount leads to item 3.
	- Probable fix: reuse the watchdog's `fIsUserInUse`.

- `tkz_user` leaves things half done on failure or without saying so.
	- ID: Code Review 20261012 item 15
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: a6cf5dc (`add`, `migrate`), 4ea029d (`passwd`). No earlier review. Plausible.
	- `migrate` never changes the GNOME keyring password, which is the problem 4ea029d fixed for `passwd`.
	- A failed `add`, for example `useradd` failing on a missing `sudo` group, leaves the encrypted home mounted and its key loaded. The watchdog skips it as "no such user" forever, and a rerun refuses because the dataset exists.
	- If `passwd` can't mount the home, it skips the keyring with no warning and still reports "Done".

- The build guide's password-change section says no script changes the login password and the home key together, then gives manual steps that skip the salt file and the keyring.
	- ID: Code Review 20261012 item 16
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: a6cf5dc and 4ea029d. No earlier review. Confirmed by reading against `tkz_user`.
	- On a salted host, following those steps breaks the next login. `tkz_user passwd` does it right.
	- The guide also says `tkz_user passwd` can reset a forgotten password. For an encrypted home it needs the current one.

- cloning.md says resetting the LUKS keyslots gives a clone its own keys. The volume key stays the same, so every clone can decrypt every other one.
	- ID: Code Review 20261012 item 17
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: 42ded6a. No earlier review. Confirmed from how LUKS keyslots work. ZFS `change-key` likewise keeps the master key.
	- Also in cloning.md: `cd tukzedo` names the wrong directory, the Grub fallback steps contradict creation.md, and the list of things to change for a new host leaves out `uki-cmdline.conf`, `usb-unlock.conf`, fstab, the `zfs-list.cache` file name, both sets of SSH host keys, the MOK and the salt file. Renaming the host breaks every encrypted home on a salted system.
	- Probable fix: `cryptsetup reencrypt`, and re-create encrypted homes.

- `install_dev.bash` overwrites live scripts in place, and its header says it warns first when local files are newer. It doesn't check that.
	- ID: Code Review 20261012 item 18
	- Type: Bug
	- Severity: Medium
	- Opened: 20261012-090724
	- Origin: dcfe3f1. No earlier review. Plausible for the failure, confirmed for the header.
	- A dropped download leaves a partial `tkz_zfs-crypthome_login`. That script is PAM `requisite`, so every password login then fails. The README and the build guide both pipe it.
	- Under `set -u`, a missing `USER` stops it.
	- Probable fix: download to a temp file beside the target, then `install` and `mv`.

- The usb-unlock initrd script can leave the key stick mounted into the real system, and may never show its IP address for SSH unlock.
	- ID: Code Review 20261012 item 19
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: a6cf5dc. No earlier review. Plausible.
	- A failed `umount` isn't checked. `/run` survives the switch to the real root, so the key file stays readable at `/run/usb-unlock-key`.
	- The module doesn't install `ip`, so the message reads "No IP address yet" unless another module brings it in.

- `tkz_startup-log` mixes up blocks from callers that run at the same time, and a usage error exits 1, though it says it always exits 0.
	- ID: Code Review 20261012 item 20
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: 11a730b. No earlier review. Confirmed with the logger stubbed: for A begin, B begin, A end, B end, A's duration and depth came out wrong.
	- `tkz-apply-tunables` and `tkz-insure-efi-mount` aren't ordered against each other, so this can happen at boot.
	- Probable fix: one stack per caller.

- `tkz_show-startup-log -F` hangs, and records from the plain `logger` fallback never show.
	- ID: Code Review 20261012 item 21
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: 11a730b. No earlier review. Plausible.
	- Options are lowercased, but the follow check is case-sensitive, so `journalctl -f` runs inside `$(...)`. The fallback records have no `TKZ_CALLER`, so the filter drops them.

- `tkz_insure-efi-mount` and `tkz_apply-tunables` don't do what their help says.
	- ID: Code Review 20261012 item 22
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: 11a730b, 5ee7b63. No earlier review. Plausible.
	- `tkz_insure-efi-mount --dry-run` exits 0 while the mount is unhealthy, against its exit-code doc. `-v` and `--version` skip sudo but the parser rejects them.
	- `tkz_apply-tunables --check --emit-native` writes the drop-ins, though `--check` says it changes nothing. `builtInNotes` is filled in a pipeline subshell and never read. `words=( $1 )` globs, which is wrong for a value with `*` or `?`. The `tunables.conf` header leaves out the dracut drop-in.

- `tkz_zfs-mount --audit-all` skips mounts whose path has a space in it.
	- ID: Code Review 20261012 item 23
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: 1a19cbe. No earlier review. Confirmed: `/media/u/My Disk` was read as `/media/u/My`.
	- Probable fix: read the filesystem type first and the target last, and decode `findmnt` escapes.

- On branch `zfs-import`, `tkz_zfs-import` reports the wrong reason when a forced import fails, and rejects some `root=` forms its comment says it takes.
	- ID: Code Review 20261012 item 24
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: e932ac2, unmerged. No earlier review. Confirmed with stubs for `root=`, plausible for the error text.
	- The `-f` retry's output goes to `/dev/null`, so "Last error" shows the non-forced message. `rootfstype=zfs root=pool/ds` and a quoted `"root=ZFS=..."` get "no root pool to import" and exit 0. The guide uses `root=ZFS=`, so b28l isn't affected.

- Small doc errors across the repo.
	- ID: Code Review 20261012 item 25
	- Type: Bug
	- Severity: Low
	- Opened: 20261012-090724
	- Origin: a6cf5dc for the build guide, 42ded6a for the rest. No earlier review. Confirmed.
	- FAQ says the cache file is reset on every boot. On main only `tkz_rebuild-uki` clears it. FAQ links to a guide path that doesn't exist.
	- contributing.md links `code%20of%20conduct.md`. The file is `code_of_conduct.md`.
	- design.md relies on fstab rbinds that only b23 has. todo.md has stale entries.
	- Build guide: `rm -rf /boot/efi/$(cat /etc/machine-id)` wipes the ESP root if machine-id is empty. The live ISO link names `13.7.0` under `current-live`, which breaks on the next point release. The example photo path is left as the active value right after the `.hex` key is made. The user examples reuse `alice` and `guest`, who exist by then. "Turn on Secure Boot" sits in the VM phase.
	- The login helper still points at the old `x9startup-log` path, which is dead code.

- The logout watchdog locks a home whose key an admin loaded on purpose, within seconds. Any SSH session closing starts it, root's included, as does its 5-minute timer.
	- Opened: 20261012-071500
	- Keys loaded so `tkz_user passwd` can skip the current-password prompt get unloaded again before it runs.
	- A runtime mask doesn't help, since the unit file in `/etc/systemd/system` wins over `/run`. Taking the exec bit off the script works as a stopgap.
	- Wanted: a documented way to pause it, such as a flag file the watchdog checks, or a per-dataset property meaning "held open by an admin".
	- Decisions: 20261012. A runtime hold per user: `tkz_user hold <user>` and `tkz_user release <user>` write and remove a root-only file under `/run/tkz/`, and the watchdog skips that user while it exists. It is cleared at reboot, so a forgotten hold can't outlive the boot.

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

- Write every file on the ESP to a temp file and rename it into place, and skip images whose signature already checks out.
	- ID: Code Review 20261012 item 26
	- Type: Enhancement
	- Priority: High
	- Opened: 20261012-090724
	- `tkz_rebuild-uki` signs UKIs and both `grubx64.efi` copies in place. A power loss or a full ESP mid-write leaves shim with nothing to load. `tkz_resign-sdboot` already uses a temp file.
	- Re-signing an already signed image adds another signature each run. Not reproduced here.

- Warn about the secrets the UKI puts on the unencrypted ESP, and pin the initrd SSH host key.
	- ID: Code Review 20261012 item 27
	- Type: Enhancement
	- Priority: Medium
	- Opened: 20261012-090724
	- `99fix-shadow` puts root's password hash in the UKI, where it can be cracked offline. The initrd SSH host keys are readable there too, so a stolen drive can impersonate the unlock prompt.
	- Ideas: require a root password used nowhere else, use a `HostKeyAlias <host>-initrd` with the fingerprint saved at build time, and find a USB key design that stores no path in the clear (item 11).

- Offer a recovery key for encrypted homes. A forgotten password loses the home.
	- ID: Code Review 20261012 item 28
	- Type: Enhancement
	- Priority: Medium
	- Opened: 20261012-090724
	- The guide should say so where homes are created.
	- Decisions: 20261012. Document only. The guide and `tkz_user add` say plainly that a forgotten password loses the home, and advise backups. ZFS allows one wrapping key per dataset, and an admin escrow key could open every home.

- Ship the PAM lines as a `pam-configs` profile.
	- ID: Code Review 20261012 item 29
	- Type: Enhancement
	- Priority: Medium
	- Opened: 20261012-090724
	- They are inserted inside the block `pam-auth-update` manages. A `pam-auth-update --force` or a profile change drops the `requisite` line, and homes stop mounting at login. Plausible.

- Make the guide's rollback steps rebuild the UKIs.
	- ID: Code Review 20261012 item 30
	- Type: Enhancement
	- Priority: Low
	- Opened: 20261012-090724
	- The ESP isn't rolled back, so the default entry can name a kernel whose modules are gone. Rolling back `/etc/shadow` also leaves encrypted-home keys out of step with the passwords.

- Speed up repeat auths and shorten lock holds.
	- ID: Code Review 20261012 item 31
	- Type: Enhancement
	- Priority: Low
	- Opened: 20261012-090724
	- Every `sudo` or screen-unlock auth reruns `tkz_zfs-mount`, which means bind mounts plus up to a 120-second lock wait. It could skip that when the whole tree is already mounted.
	- `tkz_user passwd` holds the watchdog lock while it waits at the prompts, so no home is locked meanwhile. It could prompt first.
	- `usb-unlock` mounts ext4 with plain `ro`, which still replays a dirty journal onto the key stick. `noload` avoids that.

- A GUI for `tkz_user`: add a user with or without an encrypted home, change a password and the home key together, and migrate a plain home to encrypted.
	- Opened: 20261011-194500
	- The CLI does all of this now.

- Plain `passwd` changes only the login password. An encrypted home keeps its old ZFS key, and the next login fails to unlock it.
	- Opened: 20261011-194500
	- `tkz_user passwd` does both. A `pam_exec` hook on the password stack could do it for every password change, `passwd` and desktop tools included.

### Deferred

### Canceled

- Code Review 20261012
	- Decided against: shellcheck SC2010 and SC2162 in `utility/core.bash`. Cosmetic, and item 13 may retire the file.
	- Decided against: removing `cron` and `sudo` from the `common-session` skip list. On Debian both include `common-session-noninteractive`, so the entries do nothing, but they keep working if that ever changes.

## Application name ideas


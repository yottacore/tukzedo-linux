<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD055 -- Table pipe style [Expected: leading_and_trailing; Actual: leading_only; Missing trailing pipe] -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->

<!-- TOC ignore:true -->
# Project design

<!-- TOC ignore:true -->
## Table of contents
<!-- TOC -->

- [Goal](#goal)
- [Architecture](#architecture)
	- [Language and stack](#language-and-stack)
	- [Logical code organization](#logical-code-organization)
	- [API](#api)
	- [Encrypted home logout watchdog](#encrypted-home-logout-watchdog)
	- [Mount helper and immutable mountpoints](#mount-helper-and-immutable-mountpoints)

<!-- /TOC -->

## Goal

## Architecture

### Language and stack

### Logical code organization

### API

### Encrypted home logout watchdog

- Purpose. Lock a user's encrypted ZFS home once no session of theirs is left.
	- Login mounts and unlocks through PAM (`tkz_zfs-crypthome_login`).
	- Nothing in PAM reliably fires on the last logout, so a separate watchdog does the other half.

- How it runs. One short-lived script, `tkz_zfs-crypthome_logout-watchdog`, run two ways.
	- A systemd timer every five minutes is the backstop.
	- A `pam_exec` `close_session` line in `common-session` kicks the same unit with `systemctl start --no-block`, so most logouts lock within seconds.
		- A `pam_succeed_if` line ahead of it skips cron, sudo, cups and samba. Those open and close PAM sessions constantly and never mean a logout.

- Why one-shot, not resident.
	- A resident loop with a hand-off flag on `/dev/shm` was considered. It needs its own liveness checks, a wait-for-predecessor dance, and still carries state across hours.
	- A fresh process every five minutes costs a few milliseconds and picks up script edits on the next run for free. No leak can outlive one run.

- Guards against stacking.
	- The script takes a `flock` on `/dev/shm` and exits at once if another copy holds it.
	- The unit is `Type=oneshot`. A timer tick or `systemctl start` while it runs joins the existing job. systemd never starts a second instance.
	- `TimeoutStartSec=4min` plus `TimeoutStopSec=30s` kill a wedged run, and everything in its cgroup, inside the five-minute period.
	- The only thing that can survive is a process stuck in D state on a dead filesystem, and then only one of them.

- Deciding who is logged out.
	- `loginctl` comes first, with `who` as a fallback.
	- `su -` opens no logind session and writes no utmp record. So a user with any process on a TTY also counts as logged in. It has to be a TTY and not just any process, or a stray daemon could keep the home mounted forever.
	- Sessions in the `closing` state count as gone.
	- Users with linger enabled are skipped as "in use".

- Unmount order.
	- First rung asks systemd to stop the mount units, parent first. Deepest-first unmounting tends to wedge; this order was found to work.
	- Then `zfs unmount` deepest first, then `umount -R` for foreign mounts nested in the tree, then SIGTERM, then SIGKILL with forced unmount, then lazy unmount.
	- Each rung that signals or forces checks for a login again first.
	- A process on a TTY is never signaled, whoever owns it. While one holds the tree, the forced and lazy unmounts are skipped and the pass fails, so the next pass retries. A missed unmount can wait. A killed shell is gone.
	- `zfs unload-key` last.
	- Mountpoint dirs carry `chattr +i`, so a half-finished unmount cannot let stray writes into the parent dataset.

- Logging.
	- Unattended runs write to a buffer on `/dev/shm` and only append it to the log when something happened or failed. A quiet run leaves no trace.
	- Interactive and dry runs print to the terminal as before.

- Files.
	- `filesystem/debian_13/usr/local/sbin/tkz_zfs-crypthome_logout-watchdog`
	- `filesystem/debian_13/etc/systemd/system/tkz-zfs-crypthome-logout-watchdog.{service,timer}`
	- `filesystem/debian_13/etc/pam.d/common-session` (one-host snapshot, copy the two lines only)

### Mount helper and immutable mountpoints

- Rule. Every mountpoint dir on the box is empty and carries `chattr +i`.
	- While nothing is mounted there, no program can write into it. Nothing leaks into the parent filesystem.
	- Once something is mounted, the flag is invisible and changes nothing.
	- Without it, stray writes hide under the mount forever. `overlay=on` is the Linux default, so `zfs mount` does not complain about a non-empty dir.

- One script owns the rule: `tkz_zfs-mount`.
	- Mount mode takes a dataset. Parents first: create the dir if missing, move any contents to a quarantine folder next to it, set the flag, mount, verify. Non-zero exit if any dataset that should mount did not.
	- `--audit` runs the same checks over every dataset of every pool. Mounted ones get their raw dir checked. Unmounted canmount=on ones get mounted. Unmounted noauto ones are left alone.
	- `--audit-all` adds every other mountpoint findmnt lists. Pseudo filesystems and paths under `/run`, `/proc`, `/sys`, `/dev` and container dirs are skipped. Only dirs on filesystems that support the flag are touched.
	- `--release` takes the flag off one dir, mounted or not.

- Reaching the raw dir under a live mount.
	- Bind the filesystem that holds the mountpoint, non-recursively, to a scratch dir in `/run`. That view shows the filesystem's own contents with nothing mounted on top.
	- The raw dir sits at the same relative path inside the bind. Nesting depth does not matter, since every mountpoint has exactly one holding filesystem.
	- Dedup by device and inode, so bind copies of the same tree are handled once.

- Quarantine, never delete.
	- Contents go to `.tkz_premount-quarantine/<name>_<timestamp>/` next to the mountpoint, in the holding filesystem.
	- Hidden content under a live mount is unreachable anyway, so audit moves it. Visible content in an unmounted noauto dir is only reported.

- Why the pool trees stay canmount=on.
	- The zfs mount generator turns every dataset into a systemd mount unit under `local-fs.target`. The fstab rbinds of the pools depend on that ordering.
	- noauto would trade that guarantee for a custom unit. The flag already removes the reason to want it.
	- So the stock path mounts, and `tkz-zfs-mount-audit.service` repairs once per boot, before user sessions open.

- Callers.
	- `tkz_zfs-crypthome_login` calls mount mode for the user's tree, then verifies. Plain `zfs mount` fallback if the helper is missing.
	- All runs take one lock, so the boot audit and a login never work on the same dir at once.

- Costs.
	- The flag travels with snapshots and `zfs send` of the parent. A restore into a flagged dir fails until `--release`.
	- `zfs rename` or `destroy` leaves an immutable empty dir behind. `--release`, then rmdir.

- Files.
	- `filesystem/debian_13/usr/local/sbin/tkz_zfs-mount`
	- `filesystem/debian_13/etc/systemd/system/tkz-zfs-mount-audit.service`

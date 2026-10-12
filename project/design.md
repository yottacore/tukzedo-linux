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

- It locks a user's encrypted ZFS home once no session of theirs is left.
	- Login mounts and unlocks through PAM (`tkz_zfs-crypthome_login`).
	- Nothing in PAM reliably fires on the last logout, so a separate watchdog does the other half.

- One short-lived script, `tkz_zfs-crypthome_logout-watchdog`, runs 2 ways.
	- A systemd timer runs it every 5 minutes, as a fallback.
	- A `pam_exec` `close_session` line in `common-session` starts the same unit with `systemctl start --no-block`, so most logouts lock within seconds.
		- A `pam_succeed_if` line ahead of it skips cron, sudo, cups and samba. Those open and close PAM sessions all the time and never mean a logout.

- It's one-shot rather than resident.
	- A resident loop with a hand-off flag on `/dev/shm` was considered. It needs its own liveness checks, has to wait for the copy before it, and keeps state across hours.
	- A fresh process every 5 minutes costs a few milliseconds, and picks up script edits on the next run. No leak can outlive one run.

- Guards against stacking:
	- The script takes a `flock` on a file in `/run/tkz` and exits at once if another copy holds it. Only root can get into that folder. On `/dev/shm`, any user could hold the lock and stop the watchdog.
	- The unit is `Type=oneshot`. A timer tick or `systemctl start` while it runs joins the existing job, and systemd never starts a second instance.
	- `TimeoutStartSec=4min` plus `TimeoutStopSec=30s` kill a stuck run, and everything in its cgroup, inside the 5-minute period.
	- The only thing that can survive is a process stuck in D state on a dead filesystem, and then only one of them.

- Deciding who is logged out:
	- `loginctl` comes first, with `who` as a fallback.
	- `su -` opens no logind session and writes no utmp record. So a user with any process on a TTY also counts as logged in. It has to be a TTY and not any process, or a stray daemon could keep the home mounted forever.
	- Sessions in the `closing` state count as gone.
	- Users with linger enabled are skipped as in use.
	- A user held with `tkz_user hold` is skipped until `tkz_user release`, or a reboot. The hold is a file in `/run/tkz`, which is a tmpfs. `hold` takes the watchdog's lock to write it, so a pass can't be halfway through that user when it appears.

- Unmount order, one rung at a time:
	- Ask systemd to stop the mount units, parent first. Deepest-first tends to hang, and this order was found to work.
	- Then `zfs unmount` deepest first, then `umount -R` for foreign mounts nested in the tree, then SIGTERM, then SIGKILL with a forced unmount, then a lazy unmount.
	- Each rung that signals or forces checks for a login again first.
	- A process on a TTY is never signaled, whoever owns it. While one holds the tree, the forced and lazy unmounts are skipped and the pass fails, so the next pass retries. A missed unmount can wait, but a killed shell can't be brought back.
	- `zfs unload-key` comes last.
	- Mountpoint dirs have `chattr +i`, so a half-finished unmount can't let stray writes into the parent dataset.

- Unattended runs write to a buffer in `/run/tkz`, and only append it to the log when something happened or failed. A quiet run leaves no trace. Interactive and dry runs print to the terminal.

- Files:
	- `filesystem/debian_13/usr/local/sbin/tkz_zfs-crypthome_logout-watchdog`
	- `filesystem/debian_13/etc/systemd/system/tkz-zfs-crypthome-logout-watchdog.{service,timer}`
	- `filesystem/debian_13/etc/pam.d/common-session` (a snapshot from one host; copy only the 2 lines)

### Mount helper and immutable mountpoints

- Every mountpoint dir on the box is empty and has `chattr +i`.
	- While nothing is mounted there, no program can write into it, so nothing leaks into the parent filesystem.
	- Once something is mounted, the flag is hidden and changes nothing.
	- Without it, stray writes hide under the mount forever. `overlay=on` is the Linux default, so `zfs mount` doesn't complain about a non-empty dir.

- `tkz_zfs-mount` enforces this.
	- Mount mode takes a dataset. Parents first, it creates the dir if missing, moves any contents to a quarantine folder next to it, sets the flag, mounts and verifies. It exits non-zero if any dataset that should mount didn't.
	- `--audit` runs the same checks over every dataset of every pool. Mounted ones get their raw dir checked. Unmounted canmount=on ones get mounted. Unmounted noauto ones are left alone. `/` has no raw dir under it, so it gets no raw dir check.
	- `--audit-all` adds every other mountpoint findmnt lists. Pseudo filesystems and paths under `/run`, `/proc`, `/sys`, `/dev` and container dirs are skipped. Only dirs on filesystems that support the flag are touched.
	- `--release` takes the flag off one dir, mounted or not.

- To reach the raw dir under a live mount, the filesystem that holds the mountpoint is bound, non-recursively, to a scratch dir in `/run`.
	- That view shows the filesystem's own contents with nothing mounted on top.
	- The raw dir is at the same relative path inside the bind. Nesting depth doesn't matter, since every mountpoint has exactly one holding filesystem.
	- Bind copies of the same tree are deduplicated by device and inode, so each is handled once.

- Contents are quarantined, never deleted.
	- They go to `.tkz_premount-quarantine/<name>_<timestamp>/` next to the mountpoint, in the holding filesystem.
	- Hidden content under a live mount can't be reached anyway, so audit moves it. Visible content in an unmounted noauto dir is only reported.

- The pool trees stay canmount=on.
	- The zfs mount generator turns every dataset into a systemd mount unit under `local-fs.target`. The fstab rbinds of the pools depend on that ordering.
	- noauto would give up that ordering for a custom unit. The flag already removes the reason to want noauto.
	- So the stock path mounts, and `tkz-zfs-mount-audit.service` repairs once per boot, before user sessions open.

- Callers:
	- `tkz_zfs-crypthome_login` calls mount mode for the user's tree, then verifies. It falls back to plain `zfs mount` if the helper is missing.
	- All runs take one lock, so the boot audit and a login never work on the same dir at once.

- Costs:
	- The flag goes along with snapshots and `zfs send` of the parent. A restore into a flagged dir fails until `--release`.
	- `zfs rename` or `destroy` leaves an immutable empty dir behind. Run `--release`, then rmdir.

- Files:
	- `filesystem/debian_13/usr/local/sbin/tkz_zfs-mount`
	- `filesystem/debian_13/etc/systemd/system/tkz-zfs-mount-audit.service`

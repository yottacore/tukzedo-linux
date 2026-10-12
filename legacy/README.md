<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->

# Legacy

These files were once part of a working Tukzedo system. They're kept for the decisions behind them, and are not meant to be deployed. Nothing under `legacy/` gets installed, and nothing here is kept in sync with the live system.

The layout mirrors `filesystem/`, so each file sits at the path it used to have.

## Retired 2026-08-13: the rc.local boot chain

Boot-time work moved from sourced shell fragments to systemd units. The replacements are the `tkz-*` units under `filesystem/debian_13/etc/systemd/system/`.

### etc/rc.localx9.d/020-insure-efi-mount

A wrapper that sourced `/usr/local/sbin/tkz_insure-efi-mount` into the shared `/etc/rc.local` shell. Replaced by `tkz-insure-efi-mount.service`.

Why it was dropped:

- `.` is a POSIX special built-in. Under dash, which is `/bin/sh` here, a missing or unreadable target aborts the whole shell. The trailing `;:` looks like it guards against that, but the abort happens inside `.`, so `:` never runs. One missing file quietly stopped every later step in the chain.

- Every step shared one shell. The sourced script's `fMain` overwrote the runner's own `fMain`, and both target scripts declared the same `mePath_1mvp0kj` variable.

- The wrapper and its target each hard-coded the wrapper's file name, with nothing linking the two. Renumbering the wrapper gave wrong logs without any error.

### etc/rc.localx9.d/040-empty-tmp and usr/local/sbin/tkz_empty-tmp

Emptied `/tmp` during `rc.local`. Retired with no replacement, since it was both redundant and harmful here:

- `/tmp` is a fresh tmpfs from systemd's `tmp.mount` on every boot, so there was never anything stale to clean. Ongoing cleanup belongs to `systemd-tmpfiles` (`/etc/tmpfiles.d/`), which handles age-based rules.

- By the time `rc-local.service` ran, services had already made their `PrivateTmp=` folders under `/tmp/systemd-private-*`, and the script deleted them. The journal showed it removing the private tmp of `colord.service` while colord was running.

- It special-cased `/tmp/var/log` only to protect the old startup log from itself. That log is in the journal now, so the special case has no use.

`tkz_empty-tmp` still runs if a manual `/tmp` purge is ever wanted. It has no guard against deleting the private tmp folders above, so read it first.

### etc/rc.localx9.d/010-set-kernel-params

Set sysctls, ZFS module parameters and disk I/O schedulers at `rc.local` time. Replaced by `/etc/tukzedo/tunables.conf`, `tkz_apply-tunables` and `tkz-apply-tunables.service`, which declare the same values in one place and generate the native drop-in files from them.

Its `Was: / Attempt: / Now:` reporting was kept. The rest went, because:

- It mixed 3 kinds of setting that each belong somewhere else: sysctls in `/etc/sysctl.d/`, module parameters in `/etc/modprobe.d/` plus the initrd, and per-device attributes in udev. So `sysctl --system` didn't reproduce the machine's own tuning.

- The scheduler loop ran once over `/sys/block/*` at boot. A disk plugged in later kept the kernel default. Only a udev rule covers hotplug.

- It wrote `cfq` to every scheduler first, in case the kernel was too old. On any modern kernel that put an `echo: I/O error` in the boot log on every boot.

- It set `zfs_arc_max` and `zfs_prefetch_disable` again, after `/etc/modprobe.d/zfs.conf` had already declared them. That made 2 sources for the same values.

That last one mattered more than it looks. The initrd is built generic (`hostonly=no`), so dracut leaves out `/etc/modprobe.d/`, and `zfs` gets loaded by the initrd. So `zfs.conf` did nothing at all. This script was the only thing applying those parameters, and the 2 it didn't set again, `l2arc_norw` and `l2arc_feed_secs`, never once took effect. The replacement generates `/etc/dracut.conf.d/60-tkz-tunables.conf` to put the file in the initrd.

## Retired 2026-08-13: x9startup-log as the boot logger

It isn't stored here, since it belongs to a separate personal toolset at `/usr/local/bin/x9/`. The Tukzedo boot path no longer calls it. It was replaced by `tkz_startup-log` and `tkz_show-startup-log`, which write structured entries to the systemd journal instead of a plain-text log plus an indent counter in `/dev/shm`.

The journal already does what the old logger did by hand: timestamps, per-record identity, boot scoping, rotation, and access for several users without world-writable files. The old log was under `/tmp/var/log/`, so it also had to be moved out to `/var/tmp/` and back each time `/tmp` was emptied.

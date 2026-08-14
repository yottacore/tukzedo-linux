<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
# Legacy

Things that were once part of a working Tukzedo system, kept here because they document
decisions worth remembering — not because they should be deployed. **Nothing under
`legacy/` is installed, and nothing here is kept in sync with the live system.**

The directory layout mirrors `filesystem/`, so each file sits at the path it used to
occupy.

## Retired 2026-08-13 — the `rc.local` boot chain

Boot-time work moved from sourced shell fragments to real systemd units. See the
`tkz-*` units under `filesystem/debian_13/etc/systemd/system/`.

### `etc/rc.localx9.d/020-insure-efi-mount`

A wrapper that sourced `/usr/local/sbin/tkz_insure-efi-mount` into the shared
`/etc/rc.local` shell. Replaced by `tkz-insure-efi-mount.service`.

Why it had to go, beyond style:

- `.` is a POSIX **special built-in**, so under dash — which is `/bin/sh` here — a
  missing or unreadable target aborted the entire shell. The trailing `;:` idiom looks
  like it guards against that, but the abort happens *during* `.`, so `:` never runs.
  One missing file silently killed every later step in the boot chain.
- Everything in the chain shared one shell, so the sourced script's `fMain` overwrote
  the runner's own `fMain`, and both target scripts declared the same
  `mePath_1mvp0kj` variable.
- The wrapper and its target each hard-coded the wrapper's filename, with nothing
  cross-referencing the two, so renumbering the wrapper silently produced wrong logs.

### `etc/rc.localx9.d/040-empty-tmp` and `usr/local/sbin/tkz_empty-tmp`

Emptied `/tmp` during `rc.local`. Retired with no replacement, because it was both
redundant and actively harmful on this system:

- `/tmp` is a fresh tmpfs from systemd's `tmp.mount` on every boot, so there was never
  anything stale to clean. Ongoing cleanup is `systemd-tmpfiles` territory
  (`/etc/tmpfiles.d/`), which handles age-based rules properly.
- By the time `rc-local.service` ran, services had already started and created their
  `PrivateTmp=` roots under `/tmp/systemd-private-*`. The script enumerated and deleted
  them. Last boot's journal shows it removing `colord.service`'s private tmp while
  colord was running.
- Its `/tmp/var/log` special-casing existed only to protect the old startup log from
  itself — that log now lives in the journal, so the whole dance is moot.

`tkz_empty-tmp` is still a runnable script if you ever want a manual `/tmp` purge, but
it has no safeguards against the mount-point problem above. Read it before trusting it.

### `etc/rc.localx9.d/010-set-kernel-params`

Set sysctls, ZFS module parameters and disk I/O schedulers imperatively at `rc.local`
time. Replaced by `/etc/tukzedo/tunables.conf` + `tkz_apply-tunables` +
`tkz-apply-tunables.service`, which declare the same values in one place and generate
the native drop-ins from them.

Its `Was: / Attempt: / Now:` reporting was the good part and was kept. What had to go:

- It conflated three kinds of setting with different correct lifetimes — sysctls
  (`/etc/sysctl.d/`), module parameters (`/etc/modprobe.d/` + initrd), and per-device
  attributes (udev) — so none of them lived where the system would look for them.
  `sysctl --system` did not reproduce this machine's own tuning.
- The scheduler loop ran once over `/sys/block/*` at boot, so any disk plugged in
  afterward silently kept the kernel default. Only a udev rule can cover hotplug.
- It wrote `cfq` to every scheduler first "in case the kernel is too old", which on any
  modern kernel produced a real `echo: I/O error` in the boot log on every boot.
- It re-set `zfs_arc_max` and `zfs_prefetch_disable` that `/etc/modprobe.d/zfs.conf`
  also declared — two sources of truth for the same values.

**And the reason that duplication mattered:** the initrd here is built generic
(`hostonly=no`), so dracut omits `/etc/modprobe.d/` entirely, and `zfs` is loaded *by
the initrd*. `zfs.conf` was therefore inert — this script was the only thing actually
applying those parameters, and the two settings it did *not* re-set (`l2arc_norw`,
`l2arc_feed_secs`) had never once taken effect. The replacement generates
`/etc/dracut.conf.d/60-tkz-tunables.conf` to force the file into the initrd.

## Retired 2026-08-13 — `x9startup-log` as the boot logger

Not stored here (it belongs to a separate personal toolset at
`/usr/local/bin/x9/`), but the Tukzedo boot path no longer calls it. Replaced by
`tkz_startup-log` + `tkz_show-startup-log`, which record structured entries to the
systemd journal instead of maintaining a plain-text log plus a `/dev/shm` indent
counter.

What the journal gave us for free, which the old logger had to implement by hand:
timestamps, per-record identity, boot scoping, rotation, and multi-user access without
world-writable files. Notably, the old log lived under `/tmp/var/log/` and therefore had
to be shuffled out to `/var/tmp/` and back every time `/tmp` was emptied.

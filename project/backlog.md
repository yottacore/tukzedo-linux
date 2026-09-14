<!-- markdownlint-disable MD007 -- Unordered list indentation -->
<!-- markdownlint-disable MD010 -- No hard tabs -->
<!-- markdownlint-disable MD033 -- No inline html -->
<!-- markdownlint-disable MD055 -- Table pipe style [Expected: leading_and_trailing; Actual: leading_only; Missing trailing pipe] -->
<!-- markdownlint-disable MD041 -- First line in a file should be a top-level heading -->

<!-- TOC ignore:true -->
# Project backlog

This is a product backlog just for pre-v1.0.0 release. After that, bugs, features, and enhancements will be mananged in Github Issues, and/or [todo.md](../todo.md)

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

- ◐ The logout watchdog treated a user logged in only through `su - <user>` as logged out. It killed their shell and locked their home under them.
	- Opened: 20260914-101411
	- Cause: `su` opens no logind session and writes no utmp record, and the watchdog only asked logind and `who`.
	- Seen on b23 on 20260914. The 09:20:06 pass SIGKILLed a live `su - collierjr` shell, pid 20595, then unmounted and locked the home.
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

### Deferred

### Canceled


## Application name ideas


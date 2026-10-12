#!/bin/bash
#  shellcheck disable=2154  ## dracut sets moddir, initdir and systemdsystemunitdir.
## Dracut module: imports the ZFS root pool before the stock one-shot 'zfs-import-scan.service'.
## It activates the rd.lvm.lv= volumes first, retries for up to 60s, and forces past a stale hostid
## only when the pool is inside the boot LUKS container.
## The logic lives in /usr/sbin/tkz_zfs-import, the same script the real system runs.

check() {
	require_binaries zpool || return 1
	[[ -x /usr/sbin/tkz_zfs-import ]] || return 1
	return 0
}

depends() { echo "zfs systemd"; }

install() {
	inst_script /usr/sbin/tkz_zfs-import /usr/sbin/tkz_zfs-import
	inst_multiple -o lvm udevadm modprobe sleep ls rm
	inst_simple "$moddir/tkz-zfs-import-root.service" "${systemdsystemunitdir}/tkz-zfs-import-root.service"
	inst_simple "$moddir/zfs-import-scan-nonfatal.conf" "${systemdsystemunitdir}/zfs-import-scan.service.d/tkz-nonfatal.conf"
	$SYSTEMCTL -q --root "$initdir" add-wants zfs-import.target tkz-zfs-import-root.service

	## The zfs module copies in /etc/zfs/zpool.cache if one exists at build time. Modules install in
	## numeric order, so this runs after it. A cache file in the initrd makes the stock import skip its scan.
	rm -f "${initdir}/etc/zfs/zpool.cache"
}

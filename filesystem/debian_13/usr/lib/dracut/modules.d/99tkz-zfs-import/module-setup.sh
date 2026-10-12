#!/bin/bash
## Dracut module: a fallback import of the ZFS root pool, after the stock one-shot 'zfs-import-scan.service'.
## It retries for up to 60s, activates the rd.lvm.lv= volumes first, and forces past a stale hostid.
## The logic lives in /usr/local/sbin/tkz_zfs-import, the same script the real system runs.

check() {
	require_binaries zpool || return 1
	[[ -x /usr/local/sbin/tkz_zfs-import ]] || return 1
	return 0
}

depends() { echo "zfs systemd"; }

install() {
	inst_script /usr/local/sbin/tkz_zfs-import /usr/sbin/tkz_zfs-import
	inst_multiple -o lvm udevadm modprobe sleep ls rm
	inst_simple "$moddir/tkz-zfs-import-root.service" "${systemdsystemunitdir}/tkz-zfs-import-root.service"
	inst_simple "$moddir/zfs-import-scan-nonfatal.conf" "${systemdsystemunitdir}/zfs-import-scan.service.d/tkz-nonfatal.conf"
	$SYSTEMCTL -q --root "$initdir" add-wants zfs-import.target tkz-zfs-import-root.service

	## The zfs module copies in /etc/zfs/zpool.cache if one exists at build time. Modules install in
	## numeric order, so this runs after it. A cache file in the initrd makes the stock import skip its scan.
	rm -f "${initdir}/etc/zfs/zpool.cache"

	## Nothing installs this today. If something ever did, its ZPOOL_IMPORT_OPTS="" would override the -f that
	## zfs_force=1 on the kernel command line gives the stock import, since EnvironmentFile= beats the generator.
	rm -f "${initdir}/etc/default/zfs"
}

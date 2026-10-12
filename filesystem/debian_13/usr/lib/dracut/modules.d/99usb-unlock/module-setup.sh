#!/bin/bash
## Dracut module: unlock LUKS from a key file on a USB stick, before the passphrase prompt.
## Settings come from /etc/tukzedo/usb-unlock.conf, copied into the initrd.

check() { [[ -f /etc/tukzedo/usb-unlock.conf ]] || return 255; return 0; }

depends() { echo "systemd systemd-initrd crypt"; }

install() {
	inst_simple /etc/tukzedo/usb-unlock.conf
	inst_script "$moddir/usb-unlock.sh"      /usr/sbin/usb-unlock.sh
	inst_simple "$moddir/usb-unlock.service" "${systemdsystemunitdir}/usb-unlock.service"
	inst_multiple mount umount cryptsetup blkid sleep
	## Filesystems the key stick may use. Debian's FAT default iocharset is utf8; codepage is 437.
	instmods ext4 vfat exfat nls_cp437 nls_utf8 nls_iso8859_1 usb_storage uas
	$SYSTEMCTL -q --root "$initdir" enable usb-unlock.service
}

#!/bin/bash
## Runs in the initrd. Never fails the boot: on any problem it exits 0 and the
## normal passphrase prompt (console or SSH) takes over.

source /etc/tukzedo/usb-unlock.conf

USB_MOUNTPOINT="/run/usb-unlock-key"
USB_TIMEOUT="${USB_TIMEOUT:-10}"

say(){ echo "usb-unlock: $*" >/dev/console; }

fShowNetInfo(){
	{
		echo ""
		echo "================================================================"
		echo "Network info (for SSH unlock):"
		ip -4 addr show scope global 2>/dev/null | grep -E ' inet|^[0-9]' || echo " No IP address yet."
		echo "================================================================"
		echo ""
	} >/dev/console
}

fMain(){
	local -i elapsed=0

	if [[ -e "/dev/mapper/${LUKS_NAME}" ]]; then
		say "'${LUKS_NAME}' is already open."
		return 0
	fi

	say "Waiting up to ${USB_TIMEOUT}s for the USB key..."
	while [[ ! -e "/dev/disk/by-uuid/${USB_UUID}" ]]; do
		((elapsed >= USB_TIMEOUT)) && { say "No USB key found, skipping."; fShowNetInfo; return 0; }
		sleep 1
		elapsed=$((elapsed+1))
	done

	mkdir -p "${USB_MOUNTPOINT}"
	mount -o ro "/dev/disk/by-uuid/${USB_UUID}" "${USB_MOUNTPOINT}" || { say "Couldn't mount the USB key, skipping."; return 0; }

	if [[ ! -f "${USB_MOUNTPOINT}/${KEYFILE_PATH}" ]]; then
		say "Key file not found on the USB key."
	elif cryptsetup open --allow-discards "UUID=${LUKS_UUID}" "${LUKS_NAME}" --key-file="${USB_MOUNTPOINT}/${KEYFILE_PATH}" \
			${KEYFILE_OFFSET:+--keyfile-offset="${KEYFILE_OFFSET}"} ${KEYFILE_SIZE:+--keyfile-size="${KEYFILE_SIZE}"}; then
		say "LUKS unlocked."
	else
		say "Key didn't work, passphrase prompt will follow."; sleep 3
	fi

	umount "${USB_MOUNTPOINT}"
	fShowNetInfo
	return 0
}

fMain
exit 0

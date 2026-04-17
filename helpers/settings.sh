#!/bin/bash
#  shellcheck disable=2034  ## '<Variable> appears unused. Verify use (or export if used externally).'

##	Purpose:
##		- Your specific (user/machine) settings go in these variables.
##		- This file will be read by other scripts. It's mostly useless (but harmless) to be run on it's own.
##	Notes:
##		- The existing values in this template won't work for you. They exist as examples of the kind of information that the variables should be set to.
##	Copyright and license ...: Toward bottom of this file.
##	History .................: At bottom of this file.


####
#### Settings defining the rescue environment, Live CD, or whatever you are setting up and chrooting into from.
#### Make sure you update these settings, if you boot to different environments along the setup process.
####

## The hostname of the rescue/setup/liveCD environment
declare chrootHostHostname='t1hcn'

## Temporary mount point inside the rescue/setup/liveCD environment, for new system's filesystem.
declare TEMPMOUNT_BASE='/mnt/zfswip'

## The ZFS-specific "HostID" of the rescue/setup/liveCD environment, located in '/etc/hostid'.
## May not exist until you create or import the new system's ZFS filesystem.
## It's a 4-byte binary value, that we'll work with in hex format.
## Can be obtained via: od -An -tx1 -N4 /etc/hostid  | tr -d ' '
declare zfsHostID_WorkingHost='bcfbfc05'


####
#### Settings defining the target new system that you're setting up and will eventually chroot into, then fully boot into.
####

## Real or virtual block device to partition and install the new system to.
## Ideally use an identifier (e.g. 'wwn-*' for SATA drives or eui.* for NVMe) that won't change over reboots or in other systems.
declare diskTarget_wwn='/dev/disk/by-id/wwn-0x5002538e408fe9b2'

## Real or virtual block device to partition and install the new system to.
## Used in only a few situations, but make sure it's accurate after every real or virtual reboot, wish something like:
##   echo; ls -lA /dev/disk/*/* | grep -P "${diskTarget_wwn} "; echo
declare diskTarget_dev='vda'

## New system's short "universally unique" (loosely) ID, that you just make up ahead of time - like now.
## It can be any string, but recommended to be short, meaningless, and loosely "universally unique".
## This will be used as part of new system's Luks, LVM, and ZFS names.
## Suggested but not required: Something like [POSIX time]/60 (for minute-level uniqueness), converted to ISO/IEC 10118-3:2018 Base32.
## For example: echo; printf "%x" $(($(date +"%s") / 60)) | xxd -r -p | base32 | tr 'A-Z' 'a-z' | tr -d '='; echo
declare mUID='t2nsn'

## New system's hostname
## Can be the same as mUID, but recommended to be different (for subtle and non-critical reasons that aren't important to elaborate).
declare newHostname='t2nsn'

## The partition UUID (not PARTUUID) of the UEFI Fat32 partition.
## You won't know this until you create the partition.
## Find with something like: echo; lsblk -o NAME,SIZE,FSTYPE,FSVER,LABEL,WWN,UUID "${diskTarget_wwn}-part1"; echo
declare    uefiUUID='75CA-2532'

## LUKS block ID UUID.
## You won't know this until you create the LUKS container.
## Find with something like: echo; sudo cryptsetup luksUUID "${diskTarget_wwn}-part2"; echo
declare    luksUUID='b121f4f6-31d7-439d-bc5c-b02581d6effb'

## Swap partition UUID.
## You won't know this until after you create it.
## Find with something like: echo; blkid | grep swap; echo
declare    swapUUID='dc38b82e-b352-4e85-b0e0-16836376a83a'

## Swap size.
## For hibernation, needs to be at least be >100% of physical RAM capacity (minimum 115% to be safe).
## For working swap capacity, should ideally be >=200% for <=8GB, >=150% for <=64GB, >=115% for >64GB (as of 2026 and will grow with increasing system memory demands over time).
declare -i swapSizeGB=32

## The ZFS-specific "HostID" of the target new system, located in '/etc/hostid'.
## May not exist until you import the new ZFS filesystem in a chroot environment for the first time.
## It's a 4-byte binary value, that we'll work with in hex format.
## You can create it yourself ahead of time, via: head -c 4 /dev/urandom | xxd -p | sudo tee /etc/hostid 1>/dev/null
## Then can be read back via: od -An -tx1 -N4 /etc/hostid  | tr -d ' '
declare    zfsHostID_NewSystem='f1f2ad22'

## USB unlock key's /dev/disk/by-uuid/ (not /dev/disk/by-partuuid/).
## Used to unlock luks during boot.
declare    keyUUID='91bbd247-0998-44d1-8eb7-605ab2cbfccd'




#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Generic script settings
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
#### Tell user it's harmless but useless to run this by itself, and also not sourced.
#### The 'key' arg1 isn't for security, it's just an unlikely value that signals, "I'm invoking you deliberately.'
declare -i module_loaded_settings=0
if    [[ "${BASH_SOURCE[0]}" == "$0" ]]             ; then echo -e "\nThis script only defines functions and variables for other scripts.\nIt's useless unless invoked via 'source $(basename "${0}")'.\n"; exit 1
elif  [[ "${1}" != "script_caller_id_57mz3qsniu" ]] ; then echo -e "\nThis script just defines functions and variables for other scripts.\nRun by itself like this without the expected key argument, it does nothing.\n"
else
	module_loaded_settings=1

	## List variables defined in this module:
	echo -e "\nVariables declared in '$(basename "${BASH_SOURCE[0]}")':"
	grep -P 'declare[ ]+[[:alnum:]_]+=['\''\"][^\n#]+['\''\"]' "${BASH_SOURCE[0]}" 2>/dev/null |
		awk '{sub(/^[[:space:]]*declare([[:space:]]+-[a-zA-Z]+)*[[:space:]]*/, ""); in_sq=in_dq=0; r=""; for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="\047"&&!in_dq)in_sq=!in_sq; else if(c=="\""&&!in_sq)in_dq=!in_dq; else if(c=="#"&&!in_sq&&!in_dq)break; r=r c} sub(/[[:space:]]+$/,"",r); print r}' |
		sort                          |
		tr $'\n'  $'\t'               |
		fold -s -w 80                 |
		column -t -s $'\t' -o '    '  ||
		true


fi




##	Copyright
##		Copyright © 2022-2026 t00mietum (ID: f⍒Ê🝅ĜᛎỹqFẅ▿⍢Ŷ‡ʬẼᛏ🜣)
##		Licensed under the GNU General Public License v2.0 or later. Full text at:
##			https://spdx.org/licenses/GPL-2.0-or-later.html
##		SPDX-License-Identifier: GPL-2.0-or-later
##			Preamble:
##				This program is free software: you can redistribute it and/or modify
##				it under the terms of the GNU General Public License as published by
##				the Free Software Foundation, either version 2 of the License, or
##				(at your option) any later version.
##
##				This program is distributed in the hope that it will be useful,
##				but WITHOUT ANY WARRANTY; without even the implied warranty of
##				MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##				GNU General Public License for more details.
##
##				You should have received a copy of the GNU General Public License
##				along with this program.  If not, see <https://www.gnu.org/licenses/>.
##	History:
##		- 20260401: Created.

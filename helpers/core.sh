#!/bin/bash
#  shellcheck disable=1090  ## 'ShellCheck can't follow non-constant source. Use a directive to specify location.'
#  shellcheck disable=2001  ## 'See if you can use ${variable//search/replace} instead.' Complains about good uses of sed.
#  shellcheck disable=2016  ## 'Expressions don't expand in single quotes, use double quotes for that.' I know, and I often want an explicit '$'.
#  shellcheck disable=2034  ## 'variable appears unused.' Complains about valid use of variable indirection (e.g. later use of local -n var=$1)
#  shellcheck disable=2046  ## 'Quote to prevent word-splitting.' (OK for integers.)
#  shellcheck disable=2086  ## 'Double quote to prevent globbing and word splitting.' (OK for integers.)
#  shellcheck disable=2119  ## 'Use foo "$@" if function's $1 should mean script's $1.' Confusing and inapplicable.
#  shellcheck disable=2120  ## 'Foo references arguments, but none are ever passed.' Valid function argument overloading.
#  shellcheck disable=2128  ## 'Expanding an array without an index only gives the element in the index 0.' False hits on associative arrays.
#  shellcheck disable=2154  ## '<variable> is referenced but not assigned.'
#  shellcheck disable=2155  ## 'Declare and assign separately to avoid masking return values.' Cumbersome and unnecessary.
#  shellcheck disable=2178  ## 'Variable was used as an array but is now assigned a string.' False hits on associative arrays with e.g. 'local -n assocArray=$1'.
#  shellcheck disable=2317  ## 'Can't reach.' I.e. an 'exit' is used for debugging and makes a visual mess.
## shellcheck disable=2002  ## 'Useless use of cat.'
## shellcheck disable=2004  ## '$/${} is unnecessary on arithmetic variables.' Inappropriate complaining?
## shellcheck disable=2053  ## 'Quote the right-hand sid of = in [[ ]] to prevent glob matching.' Disable for valid Yoda Notation warning?
## shellcheck disable=2143  ## 'Use grep -q instead of echo | grep'
## shellcheck disable=2162  ## 'read without -r will mangle backslashes.'
## shellcheck disable=2181  ## 'Check exit code directly, not indirectly with $?.'

##	Purpose:
##		- Functions to be used by potentially all other scripts, and/or directly from the CLI.
##		- Loaded into caller's environment via `source  core.sh  'script_caller_id_57mz3qsniu'`
##		- By itself, this script doesn't do anything, it just defines functions and variables.
##	Copyright and license ...: Toward bottom of this file.
##	History .................: At bottom of this file.


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# CLI output-only functions
# fEcho*() are mostly an easy way to avoid duplicate blank lines in CLI output.
# Minified but not obfuscated.
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
declare -i __fEcho_LastWasEmpty=0
declare -i __fEcho_LastMS=$(date +%s%3N)  ## Allows duplicate blank line supression to be reset after a few moments, i.e. not in a short-running script.
fEcho_ResetBlankCounter() { __fEcho_LastWasEmpty=0; __fEcho_LastMS=$(date +%s%3N)        ; }
fEcho()                   { { [[ -n "$*" ]] && fEcho_Clean "[ $* ]"; } || fEcho_Clean "" ; }
fEcho_Force()             { fEcho_ResetBlankCounter; fEcho "$*"                          ; }
fEcho_Clean_Force()       { fEcho_ResetBlankCounter; fEcho_Clean "$*"                    ; }
fEcho_Clean(){
	if [[ -n "${1:-}" ]]; then echo -e "$*"; __fEcho_LastWasEmpty=0
	elif [[ $__fEcho_LastWasEmpty -eq 0 ]] || [[ $(( $(date +%s%3N) - __fEcho_LastMS )) -ge 1500 ]]; then echo; __fEcho_LastWasEmpty=1; fi
	__fEcho_LastMS=$(date +%s%3N); }


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Other CLI input/output functions
# Minified but not obfuscated.
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
fThrowError(){
	local errMsg="${1:-}"         ; [[ -z "${errMsg}"      ]] && errMsg="An error occurred."
	local meNameLocal="${meName}" ; [[ -n "${meNameLocal}" ]] && errMsg="${meNameLocal}: ${errMsg}"
	local callStack=""
	for (( i = 1; i < ${#FUNCNAME[@]}; i++ )); do
		[[ "${FUNCNAME[i]}" =~ main|source ]] && continue
		[[ -n "${callStack}" ]] && callStack="${callStack}, "; callStack="${callStack}${FUNCNAME[i]}()"
	done
	[[ -n "${callStack}" ]] && callStack="Reverse call stack: ${callStack}"
	fEcho_Clean; echo -e "${errMsg}\n${callStack}\n" >&2; fEcho_ResetBlankCounter; return 1; }
fPressAnyKeyToContinue(){ echo -en "${1}Press any key to continue or CTRL+Break to abort: "; read -n 1 -s -r userAnswer; echo; fEcho_ResetBlankCounter; }
fChoiceYN(){
	[[ -n "${1}" ]] && echo -en "${1}"
	while true; do
		read -r -p "Continue? (y|n): " userAnswer
		if   [[ "${userAnswer,,}" == 'y' ]] ; then                                                break
		elif [[ "${userAnswer,,}" == 'n' ]] ; then echo -e '[ User aborted. ]\n'                ; return 1
		else                                       echo -e "Unknown response '${userAnswer}'."  ; continue
		fi; done; fEcho_Clean_Force; }


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Functions to show and do arbitrary commands.
# Minified but not obfuscated.
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
fEchoAndEval(){ fEcho; fEcho "Executing: '$1' ..."; eval "$1"; fEcho_Clean_Force; }
fEchoPromptEval(){
	[[ -z "${1}" ]] && { fThrowError "No command given to execute."; return 1; }
	fEcho_Clean; fChoiceYN "Going to execute:\n\n${1}\n\n" && { fEchoAndEval "${1}"; }; }


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Basic system helpers
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
fRebootNow()  { ( (nohup bash -c 'sleep 5; sudo reboot'   &>/dev/null) & disown ); sleep 0.5; exit; }
fPoweroffNow(){ ( (nohup bash -c 'sleep 5; sudo poweroff' &>/dev/null) & disown ); sleep 0.5; exit; }

fDetectEnvironmentAndDoEarlyInit(){
	## Populates caller's variable passed by reference, with one of: new_chroot|new_real|buildhost
	## Idempotent.

	## Args
	local -n varName_1mwv5w3=$1  ## Variable passed by reference by caller, to populate with which environment we're in.
	varName_1mwv5w3=""           ## Default return value (e.g. error)

	## Variables
	local hostFileContents="$(cat '/etc/hostname' 2>/dev/null || true)"

	if sudo systemd-detect-virt --chroot; then :
		## We're running in some chroot, hopefully the right one. Let's check.

		if [[ "${HOSTNAME}" != "${chrootHostHostname}" ]]; then
			fEcho_Clean
			#           X-------------------------------------------------------------------------------X
			fEcho_Clean "The chroot hostname doesn't match what's expected. Are you sure you've"
			fEcho_Clean "chrooting FROM the same system as defined in lib/settings.sh?"
			fEcho_Clean
			fEcho_Clean "  \$HOSTNAME .................................: '${HOSTNAME}'"
			fEcho_Clean "  \$chrootHostHostname from lib/settings.sh ..: '${newHostname}'"
			fThrowError; return 1

		elif [[ "${hostFileContents}" != "${newHostname}" ]]; then
			fEcho_Clean
			#           X-------------------------------------------------------------------------------X
			fEcho_Clean "The current hostname doesn't match what's expected. Are you sure the chroot"
			fEcho_Clean "you're in is for the new system?"
			fEcho_Clean
			fEcho_Clean "  /etc/hostname ......................: '${hostFileContents}'"
			fEcho_Clean "  \$newHostname from lib/settings.sh ..: '${newHostname}'"
			fThrowError; return 1

		else
			## Seems to be all good.
			varName_1mwv5w3="new_chroot"

			fEcho_Clean
			#           X-------------------------------------------------------------------------------X
			fEcho_Clean "FYI: We appear to be running in a chroot for the new system, from the correct"
			fEcho_Clean "build host. All OK ...."
			fEcho_Clean
			sleep 5

		fi

	elif [[ "${HOSTNAME}" == "${chrootHostHostname}" ]]; then :
		## Not chroot, in build host
		varName_1mwv5w3="buildhost"
		fEcho_Clean
		#           X-------------------------------------------------------------------------------X
		fEcho_Clean "FYI: We appear to be running in the build host environment; not in the new"
		fEcho_Clean "target system. All OK ..."
		fEcho_Clean
		sleep 5

	elif [[ "${HOSTNAME}" == "${newHostname}" ]]; then :
		## Not chroot, in new host
		varName_1mwv5w3="new_real"
		fEcho_Clean
		#           X-------------------------------------------------------------------------------X
		fEcho_Clean "FYI: We appear to be running in the real NEW system; not in a chroot, nor in"
		fEcho_Clean "the host build environment. All OK ..."
		fEcho_Clean
		sleep 5

	else
		## Don't know what's going on

		fEcho_Clean
		#           X-------------------------------------------------------------------------------X
		fEcho_Clean "The current hostname doesn't match what's expected. Are you sure you're in the"
		fEcho_Clean "right build host and/or new system?"
		fEcho_Clean
		fEcho_Clean "  /etc/hostname .........................: '${hostFileContents}'"
		fEcho_Clean "  \$HOSTNAME .............................: '${HOSTNAME}'"
		fEcho_Clean "  \$chrootHostHostname from settings.sh ..: '${chrootHostHostname}'"
		fEcho_Clean "  \$newHostname from settings.sh .........: '${newHostname}'"
		fThrowError; return 1

	fi
}


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Basic filesystem helpers
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

fMakeDir(){ [[ -n "${1}" ]] && [[ ! -d "${1}" ]] && sudo mkdir -p "${1}"; :; }

fWriteFileAsSudo(){
	## Syntax: fWriteFileAsSudo  [-a|--append]  "<FilePath>"  "[optional contents as argument, otherwise reads from pipe]"
	local doAppendFlag="" ; [[ " ${1,,} " =~ ' '(--append|-a)' ' ]]  &&  { doAppendFlag='-a'; shift || true; }
	local -r filePath="${1}" ; shift || true
	[[ -z "${filePath}" ]] && { fThrowError "No filename specified to create, overwrite, or append to."; return 1; }
	fMakeDir "$(dirname "${filePath}")"
	if [[ -t 0 ]]; then
		# Content is passed as a second argument
		echo "${1}" | sudo -s tee $doAppendFlag "${filePath}" >/dev/null
		sudo -s nano "${filePath}"
	else
		# Content is piped in
		sudo -s tee $doAppendFlag "${filePath}" >/dev/null
	fi
}

## Better than ls
fd(){    lsOfWhat="${1}"; [[ -z "${lsOfWhat}" ]] && lsOfWhat="$(pwd)"; fEcho_Clean; fEcho_Clean "Contents of '${lsOfWhat}':\n"; LC_COLLATE="C" ls -lA  --color=always  --group-directories-first  --human-readable  --indicator-style=slash  --time-style=+"%Y-%m-%d %H:%M:%S"  "${lsOfWhat}" | grep -Pv '^total ' | less -RFSX; echo; df -h "${lsOfWhat}"; fEcho_Clean_Force; }
fdAlt(){ lsOfWhat="${1}"; [[ -z "${lsOfWhat}" ]] && lsOfWhat="$(pwd)"; lsOfWhat="${lsOfWhat%%/}"; [[ -z "${lsOfWhat}" ]] && lsOfWhat='/'; fEcho_Clean; find "${lsOfWhat}" -maxdepth 1 -exec ls -ld --color=always  --human-readable  --indicator-style=slash  --time-style=+"%Y-%m-%d %H:%M:%S" {} + | awk '{print $6, $7, $1, $2, $3, $4, $5, $8}' | sort -r | column -t; fEcho_Clean_Force; }

## Formatted drive listing
fDriveInfo(){ fEcho_Clean 'Disks and partitions:'; fEcho_Clean; lsblk -o NAME,TYPE,FSTYPE,FSVER,MODEL,SIZE,FSUSE%,MOUNTPOINT,WWN,UUID,LABEL,PARTLABEL $1; fEcho_Clean_Force; }


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# ZFS helpers
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
fZfsListProps_AutoSnapshot(){ fEcho_Clean; zfs get all -t filesystem | grep -P 'NAME|auto-snapshot' | sort | less -FRX; fEcho_Clean_Force; }
fZfsListProps_Mount(){ fEcho_Clean; sFields="name,mountpoint,canmount,mounted"; zfs list -t filesystem -o $sFields | sort; fEcho_Clean_Force; }
fZfsListUnmountedThatShould(){ fEcho_Clean; fEcho_Clean "Datasets that should be listed as 'mounted=yes' but aren't:"; fEcho_Clean; sFields="name,mountpoint,canmount,mounted"; zfs list -t filesystem -o $sFields | grep -iPv 'off[ ]+no' | grep -iPv '(on|noauto)[ ]+yes' | sort; fEcho_Clean_Force; }
fMount_ListZfs(){ fEcho_Clean; { echo -e 'DATASET\tMOUNTED'; mount | grep ' type zfs ' | sort | awk '{print $1, "\t", $3}'; } | column -t; fEcho_Clean_Force; }

fZfsCreatePool(){
	## Args
	local -r zPoolName="$1"         ; shift || true
	local -r permMountPoint="$1"    ; shift || true
	local -r tmpMountBase="$1"      ; shift || true
	local blockDev="$1"             ; shift || true

	## Variables
	local -i is_bpool=0; [[ "${zPoolName}" == "bpool"* ]] && is_bpool=1

	## Validate
	{ [[ -z "${zPoolName}" ]] || [[ -z "${permMountPoint}" ]] || [[ -z "${blockDev}" ]]; } && { fThrowError "One or more required variables is|are empty."; return 1; }

	## Make mount point if it doesn't exist.
	[[ -n "${permMountPoint}" ]] && [[ "${permMountPoint,,}" != 'none' ]] && [[ ! -d "${tmpMountBase}/${permMountPoint}" ]] && sudo mkdir -p "${tmpMountBase}/${permMountPoint}"

	## Build command string
	local cmdStr=""
	cmdStr="sudo zpool create -f"
	((is_bpool)) && cmdStr="${cmdStr} -o compatibility=grub2"
	cmdStr="${cmdStr} -o ashift=12 -o autotrim=on -O devices=off -O sync=disabled"
	cmdStr="${cmdStr} -O xattr=sa -O atime=off -O compression=lz4 -O normalization=formD -O utf8only=on -O acltype=posixacl -O sharenfs=off -O sharesmb=off"
	cmdStr="${cmdStr} -O logbias=latency -O secondarycache=none"
	cmdStr="${cmdStr} -O canmount=off -O mountpoint='${permMountPoint}'"
	[[ -n "${tmpMountBase}" ]] && cmdStr="${cmdStr} -R '${tmpMountBase}'"
	cmdStr="${cmdStr} ${zPoolName} '${blockDev}'"

	## Execute
	fEchoPromptEval "${cmdStr}" || return 1
	fZfsListProps_Mount
}

fZfsCreateDataset(){
	## Args
	local -r zDatasetName="$1"   ; shift || true
	local -r permMountPath="$1"  ; shift || true  ## Not temporary mount path
	local -r canMount="$1"       ; shift || true
	local    doAutoSnap="$1"     ; shift || true

	## Validate
	if   [[ "${doAutoSnap,,}" =~ ^(y|t|1|yes|true|on)$   ]]; then doAutoSnap="true"
	elif [[ "${doAutoSnap,,}" =~ ^(n|f|0|no|false|off)$  ]]; then doAutoSnap="false"
	else doAutoSnap=""; fi

	## Create directory if necessary (esp important when pool created or imported with -R); and this is why order of dataset creation is very important.
	if [[ -n "${permMountPath}" ]] && [[ "${permMountPath,,}" != 'none' ]] && [[ "${permMountPath}" != '/' ]] && [[ -n "${TEMPMOUNT_BASE}" ]] && [[ ! -d "${TEMPMOUNT_BASE}/${permMountPath}" ]]; then
		sudo mkdir -p "${TEMPMOUNT_BASE}/${permMountPath}"
	fi

	## Build command string
	local cmdStr=""
	cmdStr="sudo zfs create"
	cmdStr="${cmdStr} -o canmount=${canMount}"
	[[ -n "${permMountPath}"  ]] && cmdStr="${cmdStr} -o mountpoint=${permMountPath}"
	[[ -n "${doAutoSnap}"     ]] && cmdStr="${cmdStr} -o com.sun:auto-snapshot=${doAutoSnap}"
	cmdStr="${cmdStr} ${zDatasetName}"
	[[ -z "${zDatasetName}" ]] && { fThrowError "First arg for 'dataset name' is empty"; return 1; }

	## Execute
	fEchoPromptEval "${cmdStr}"
	fEcho_Clean; zfs get all ${zDatasetName} | grep -iP "NAME[ ]+PROPERTY|mount|com.sun:auto-snapshot|com.ubuntu.zsys"; fEcho_Clean_Force

	## Manually mount 'noauto' datasets with a valid path, so that future necessary 'mkdir's will be meaningful.
	if [[ -n "${permMountPath}" ]] && [[ "${permMountPath,,}" != 'none' ]] && [[ "${canMount}" == 'noauto' ]]; then
		sudo zfs mount "${zDatasetName}"
	fi

	## Show properties
	[[ "${canMount}" != "off" ]] && { fEcho_Clean; mount | grep 'on ${TEMPMOUNT_BASE}/${permMountPath} '; fEcho_Clean_Force; }
}

fZfsListExpectedOnDiskDirs(){ fEcho; fEcho "Contents of various 'check' dirs:"; fEcho; { fdAlt ${TEMPMOUNT_BASE}/; fdAlt ${TEMPMOUNT_BASE}/etc; fdAlt ${TEMPMOUNT_BASE}/home/; fdAlt ${TEMPMOUNT_BASE}${HOME}/; fdAlt ${TEMPMOUNT_BASE}/usr; fdAlt ${TEMPMOUNT_BASE}/var; } | grep -v '^$' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | column -t | sort -u -k 8,8; fEcho_Force; }




#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Generic script settings and module-loading
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

## Error and exit settings
#set  -u  ## Require variable declaration. Stronger than mere linting. But can struggle if functions are in sourced files.
#set  -e  #................: Exit on errors. No bueno for 'sourced' scripts.
#set  -E  #................: Propagate ERR trap settings into functions, command substitutions, and subshells.
set   -o pipefail  #.......: Make sure all stages of piped commands also fail the same.
shopt -s inherit_errexit  #: Propagate 'set -e' ........ into functions, command substitutions, and subshells. Will fail on Bash <4.4.
shopt -s dotglob  #........: Include usually-hidden 'dotfiles' in '*' glob operations - usually desired.
shopt -s globstar  #.......: ** matches more stuff including recursion.

#### Globalb variables to set below
declare    whatEnvironment=""  ## new_chroot|new_real|buildhost
declare -i module_loaded_core=0

#### Tell user it's harmless but useless to run this by itself, and also not sourced.
#### They 'key' arg1 isn't for security, it's just an unlikely value that signals, "I'm invoking you deliberately.'
if    [[ "${BASH_SOURCE[0]}" == "$0" ]]             ; then echo -e "\nThis script only defines functions and variables for other scripts.\nIt's useless unless invoked via 'source $(basename "${0}")'.\n"; exit 1
elif  [[ "${1}" != "script_caller_id_57mz3qsniu" ]] ; then echo -e "\nThis script just defines functions and variables for other scripts.\nRun by itself like this without the expected key argument, it does nothing.\n"
else
	module_loaded_core=1

	## Load settings module
	loadFile="$(dirname "${BASH_SOURCE[0]}")/settings.sh"
	if [[ ! -f "${loadFile}" ]]; then  echo -e "\nError in $(basename "${BASH_SOURCE[0]}"): 'settings.sh' not found.\n"; return 1
	else                               source  "${loadFile}"  'script_caller_id_57mz3qsniu'
	fi

	## Load more functions depending on what environment we're in
	fDetectEnvironmentAndDoEarlyInit whatEnvironment || return 1
	## General environment, build host or new system.
	case "${whatEnvironment}" in
		"new_"*) :

			#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
			# Dracut helpers
			#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

			fCheckModule(){
				## Args
				local -r modFile="${1}" #.........................................: '.EFI' or '.img' file.
				local -a checkModuleList; read -ra checkModuleList <<< "${2}" #...: One string with a space-delimited list of modules to individually grep for. Each item can be quoted and have spaces, and/or be its own 'grep -P' expression.
				## Variables
				local -i grepCount=0; local -i atLeastOneZero=0; local    allModList=""; local    outStr=""
				## Validate
				[[   -z "${modFile}" ]]            && { fThrowError "No '.EFI' or '.img' file specified."                                          ; return 1; }
				[[ ! -f "${modFile}" ]]            && { fThrowError "Specified '.EFI' or '.img' file doesn't exist: '${modFile}'."                 ; return 1; }
				[[ ${#checkModuleList[@]} -le 0 ]] && { fThrowError "No space-demited list of modules to check for in '${modFile}' via 'grep -P'." ; return 1; }
				fEcho_Clean "Checking '${modFile}' for modules (0 is not good):"
				allModList="$(lsinitrd "${modFile}" 2>/dev/null | grep -P ' root[ ]+root ')"
				[[ -z "${allModList}" ]] && { fThrowError "No modules were listed in '${modFile}'. Could be a bug in function?"; return 1; }
				for sItem in "${checkModuleList[@]}"; do
					sItem="$(sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/" <<< "${sItem}")"  ## Strip inner matched single or double quotes from this element, if they exist.
					[[ -z "${sItem}" ]] && continue
					grepCount=$(grep -P -c "${sItem}" <<< "${allModList}")
					((grepCount == 0)) && atLeastOneZero=1
					[[ -n "${outStr}" ]] && outStr="${outStr}\n"
					outStr="${outStr}${sItem}\t${grepCount}"
				done
				outStr="$(echo -e "${outStr}" | sort -u | column -t -s $'\t' | sed 's/^/  /')"
				echo -e "${outStr}"
				((atLeastOneZero)) && fPressAnyKeyToContinue "\nWARNING: At least one necessary module wasn't found."
				fEcho_ResetBlankCounter
			}

			fCheckImportantRelativeDates(){
				fEcho_Clean; fEcho_Clean "initrd.img-* and vmlinuz.EFI should be newer than config files."
				fEcho_Clean              "If they aren't, not you need to run fRebuild_Dracut."; fEcho_Clean
				{ fdAlt /boot/; fdAlt /etc/dracut.conf.d/; } | sort -ru | column -t; fEcho_Clean_Force
			}

			fRebuild_Dracut(){
				## Old backups
				[[ -f /boot/boot_backup.old1.zip ]]  && sudo rm /boot/boot_backup.old1.zip
				[[ -f /boot/boot_backup.zip ]]       && sudo mv /boot/boot_backup.zip  /boot/boot_backup.old1.zip

				## New backup
				fEcho; fEcho 'Backing up '/boot/' ...'
				[[ -d /boot ]] && [[ -n "$(which zip 2>/dev/null || true)" ]]  && sudo zip -j  /boot/boot_backup.zip  /boot/*  -x '*/*.zip' '*.zip'

				## Build
				/usr/sbin/rebuild-uki --all
				fCheckImportantRelativeDates
			}

		;;
		"buildhost") :

			#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
			# General system helpers
			#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

			fBindMount(){
				local mntSrc="$1"
				local mntDir="$2"
				[[ -n "$(mount | grep "${mntSrc}" | grep "${mntDir} " | head -n 1 2> /dev/null || true)" ]] && return 0
				fMakeDir "${mntDir}"
				fEchoAndEval "sudo mount --bind  '${mntSrc}'  '${mntDir}'";
			}

			fEnterChroot(){
				## Mount and verify all ZFS filesystems, in the correct way and order (very important!)
				fMountFilesystems

				## Mount system stuff
				fBindMount  /dev      "${TEMPMOUNT_BASE}/dev"
				fBindMount  /proc     "${TEMPMOUNT_BASE}/proc"
				fBindMount  /sys      "${TEMPMOUNT_BASE}/sys"
				fBindMount  /run      "${TEMPMOUNT_BASE}/run"
				fBindMount  /dev/pts  "${TEMPMOUNT_BASE}/dev/pts"  ## mount -t devpts devpts apparently can cause stuff to break.

				## resolv.conf
				{ [[ ! -f "${TEMPMOUNT_BASE}/etc/resolv.conf" || ! -s "${TEMPMOUNT_BASE}/etc/resolv.conf" ]] && fEchoAndEval "sudo cp  '/etc/resolv.conf'  '${TEMPMOUNT_BASE}/etc/resolv.conf'"; } || true

				## Message
				fEcho_Clean
				echo "## Once in chroot:"
				echo "mount -t efivarfs efivarfs /sys/firmware/efi/efivars"
				echo "export HOSTNAME=${mUID}; hostname \$HOSTNAME"
				#  shellcheck disable=2028  ## 'echo may not expand escape sequences. Use printf.'
				echo 'echo -e "\n/etc/hosts:\n$(cat /etc/hosts)\n\n/etc/hostname:\n$(cat /etc/hostname)\n"'
				echo 'fZfsListProps_Mount; fMount_ListZfs; fZfsListUnmountedThatShould'
				fEcho_Clean_Force
				## Chroot
					sudo chroot "${TEMPMOUNT_BASE}" /bin/bash --login
					echo -e "\n\n    #######################################\n    ######## NO LONGER IN CHROOT!  ########\n    #######################################\n\n"
			}

			#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
			# Critical ZFS helpers
			#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

			##	- Imports the ZFS and EFI filesystems to tempmountpoint, in a VERY SPECIFIC MANNER AND ORDER.
			##	  If not done this way, your file system will be totally munged, and easily screwed up by writing files to the wrong filesystems.
			##	- This should never be run from within the running system though, only from the build host environment.
			fMountZFS(){

				## rpool: Import without mounting (very important)
				fEchoAndEval "sudo zpool import -f -N -R '${TEMPMOUNT_BASE}' 'rpool_${mUID}' || true"

				## Then explicitly mount everything that can be, in the proper order.
				## If you don't do it this way, it will be ALL jacked up. (Yet, it somehow works out automatically when initrd mounts it at boot time, probably because initrd explicitly imports AND mounts root at the same time before the other filesystems have a chance to automount.)
				while IFS= read -r nexItem; do
					fEchoAndEval "sudo zfs mount -f '${nexItem}'"
				done < <(zfs list -o name,canmount -t filesystem | grep -P ' (on|noauto)$' | awk '{print $1}')

				## bpool: Import and mount (important to do AFTER rpool so that the /boot is not shadowed by rpool).
				fMakeDir "${TEMPMOUNT_BASE}/boot"
				fEchoAndEval "sudo zpool import -f -R '${TEMPMOUNT_BASE}' 'bpool_${mUID}' || true"  ## Must be mounted after / when doing manual work.

				## Validate
				[[ -z "$(sudo zpool status 2>/dev/null)" ]] && { fThrowError "No ZFS pools appear to be mounted."; return 1; }

				## Info
				fEcho; zpool status; fEcho_Force
			}

			## This idempotent function:
			##	- Opens Luks
			##	- Loads LVM
			##	- Carefully mounts rpool filesystems in the correct order.
			##	- Mounts bpool.
			##	- Mounts UEFI partition.
			## This should never be run from within the running system though, only from the build host environment.
			fMountFilesystems(){
				## Open LUKS and LVM
				fEchoAndEval "sudo cryptsetup open 'UUID=${luksUUID}' crypt_${mUID} || true; fEcho_Clean_Force; fDriveInfo; sleep 2; fd /dev/vg_${mUID}"
				fEchoAndEval "sudo vgchange -aay vg_${mUID} || true  ## -aay = Autoactivate, Yes"

				## Mount ZFS very carefully
				fMountZFS

				## Mount UEFI (important to do after ZFS is mounted so that /boot/efi doesn't get shadowed by /boot).
				fMakeDir "${TEMPMOUNT_BASE}/boot/efi"
				fEchoAndEval "sudo umount '${TEMPMOUNT_BASE}/boot/efi'; sudo mount  -o noatime  'UUID=${uefiUUID}'  '${TEMPMOUNT_BASE}/boot/efi'"

				## Status
				fZfsListProps_Mount; fMount_ListZfs; fZfsListUnmountedThatShould
				fEcho_Clean "Contents of '${TEMPMOUNT_BASE}/boot/':\n" ; sudo find -L "${TEMPMOUNT_BASE}/boot/" -type d 2>/dev/null | grep -iPv 'grub/themes/' | sort; fEcho_Clean_Force
			}

			## Unmounting a complex ZFS system can be very difficult, even with all files closed and nothing reported by `lsof`.
			## This makes a hurculean effort to unmount and export the pools cleanly.
			fZfsForceUnmountAndExport(){
				fEcho_Clean
				echo -e "Going to attempt to:\n"
				echo    "  1. Forcefully unmount all mounted datasets via ZFS."
				echo    "  2. Forcefully unmount all mounted datasets individually in reverse order via ZFS."
				echo    "  3. Forcefully unmount all mounted locations via filesystem in reverse order."
				echo    "  4. Repeat 2, 3, 2."
				echo    "  5. Forcefully export the pool."
				echo -e "\nWARNING: If this doesn't succeed cleanly, you will have to reboot to clear hung mountpoints."
				echo -e "This could be some setback, if even minor, to progress."
				fEcho_Clean_Force
				fChoiceYN || return 1
				fEchoAndEval 'sudo zfs unmount -a'
				fEchoAndEval 'sudo zfs unmount -a -fu'
				fEchoAndEval "zfs list -H -o name -t filesystem -r | sort -r | while read zFilesys; do sudo zfs unmount -fu \"\${zFilesys}\"; done"
				fEchoAndEval "while read -r isMounted mountPoint; do [[ \"\${isMounted}\" == 'no' ]] && continue; sudo umount -fRA \"\${mountPoint}\"; done < <(zfs list -t filesystem -o mounted,mountpoint | grep -v 'MOUNTED' | sort -r)"
				fEchoAndEval "zfs list -H -o name -t filesystem -r | sort -r | while read zFilesys; do sudo zfs unmount -fu \"\${zFilesys}\"; done"
				fEchoAndEval "while read -r isMounted mountPoint; do [[ \"\${isMounted}\" == 'no' ]] && continue; sudo umount -fRA \"\${mountPoint}\"; done < <(zfs list -t filesystem -o mounted,mountpoint | grep -v 'MOUNTED' | sort -r)"
				fEchoAndEval 'sudo zfs unmount -a'
				fEchoAndEval 'sudo zfs unmount -a -fu'
				fEchoAndEval 'sudo zpool export -a'
				fEchoAndEval 'sudo zpool export -af'
				fEchoAndEval 'sudo zpool status'
				fZfsListProps_Mount
				fMount_ListZfs
			}

			fPrepareZfsForReboot(){
				## VERY IMPORTANT TO DO THESE STEPS EVERY TIME THE ZPOOL IS MOUNTED BY A FOREIGN SYSTEM (E.G. RESCUE ENVIRONMENT)

				## Force unmount. This must suceed to continue; if in initial setup phase, this will probably fail.
				fZfsForceUnmountAndExport || { echo -e "\nfZfsForceUnmountAndExport() didn't run successfully, or at all.\n"; read -p "Press CTRL+BREAK multiple times." userAnswer; echo; sleep 5; }

				## Make sure rescue host's /etc/hostid is what we think it is (these MUST match):
				fEcho_Clean_Force
				fEcho_Clean "zfsHostID_NewSystem ..........: '${zfsHostID_NewSystem}'"
				fEcho_Clean "zfsHostID_WorkingHost ........: '${zfsHostID_WorkingHost}'"
				fEcho_Clean "Actual contents of /etc/hostid: '$(od -An -tx1 -N4 /etc/hostid | tr -d ' ')'"
				fEcho_Clean
				if fChoiceYN "The last two values must be identical, and different from the first. "; then  ## Don't do this programagically, let the user see the values and also give a chance to cancel.

					fEchoAndEval "echo -n '${zfsHostID_NewSystem}' | xxd -r -p | sudo tee /etc/hostid 1>/dev/null  ## Write new sys id temporarily to ZFS /etc/hostid."
					fEchoAndEval "sudo zpool import -f -N rpool_${mUID}  ## Force-import potentially 'foreign' pool, using new system's /etc/hostid."
					fEchoAndEval "sudo zpool import -f -N bpool_${mUID}  ## Force-import potentially 'foreign' pool, using new system's /etc/hostid."
					fEcho_Clean_Force; sudo zpool status; fEcho_ResetBlankCounter; fZfsListProps_Mount

					## Show hostIDs again, this time with temp contents of /etc/hostid, and what the pool now thinks.
					fEcho_Clean_Force
					fEcho_Clean "zfsHostID_WorkingHost ......: '${zfsHostID_WorkingHost}'"
					fEcho_Clean "zfsHostID_NewSystem ........: '${zfsHostID_NewSystem}'"
					fEcho_Clean "TEMP contents of /etc/hostid: '$(od -An -tx1 -N4 /etc/hostid | tr -d ' ')'"
					fEcho_Clean "What ZFS has for pool ......: '$(sudo zdb -C rpool_${mUID} | grep 'hostid' | grep -iPo '[0-9]+' | perl -ne 'chomp; print pack("N", $_)' | od -An -tx1 -N4 /etc/hostid | tr -d ' ')'"
					fEcho_Clean; fEcho_Clean "The last three lines should have the same ID."; fEcho_Clean

					fEchoAndEval "sudo zpool set cachefile=none rpool_${mUID}  ## Use scan-based pool discovery, though this setting is not persistent."
					fEchoAndEval "sudo zpool set cachefile=none bpool_${mUID}  ## Use scan-based pool discovery, though this setting is not persistent."
					fEchoAndEval "sudo zfs set mountpoint=/     rpool_${mUID}/deb/ROOT  ## Make sure root mountpoint is correct"
					fEchoAndEval "sudo zfs set mountpoint=/boot bpool_${mUID}/deb/BOOT  ## Make sure root mountpoint is correct"
					fEchoAndEval "sudo zpool export rpool_${mUID}  ## Export pool, baking in new system hostid."
					sudo systemctl enable  zfs-import-scan
					sudo systemctl disable zfs-import-cache
					sudo sync
					fEchoAndEval "sudo rm /etc/zfs/zpool.cache"
					fEchoAndEval "echo -n '${zfsHostID_WorkingHost}' | xxd -r -p | sudo tee /etc/hostid 1>/dev/null  ## Restore this rescue host ID to ZFS /etc/hostid."

					## Show hostIDs again, rescue value in /etc/hostid should be restored.
					fEcho_Clean_Force
					fEcho_Clean "zfsHostID_NewSystem ............: '${zfsHostID_NewSystem}'"
					fEcho_Clean "zfsHostID_WorkingHost ..........: '${zfsHostID_WorkingHost}'"
					fEcho_Clean "Contents of restored /etc/hostid: '$(od -An -tx1 -N4 /etc/hostid | tr -d ' ')'"
					fEcho_Clean; fEcho_Clean "The last two lines should have the same ID."; fEcho_Clean

					if fChoiceYN "Going to poweroff the rescue/liveCD host now. "; then
						fPoweroffNow
					fi
				fi
			}

		;;
	esac

	## Get more specific for new system, chroot or real
	case "${whatEnvironment}" in
		"new_chroot") :
		;;
		"new_real") :
		;;
	esac

	## List functions exposed in this module:
	fEcho_Clean; fEcho_Clean "Functions defined in '$(basename "${BASH_SOURCE[0]}")':"
	grep -oP '^(function\s+)?\K[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()' "${BASH_SOURCE[0]}" 2>/dev/null | sort | tr $'\n'  $'\t' | fold -s -w 80 | column -t -s $'\t' -o '    ' || true
	fEcho_Clean_Force

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
##		- 20260401: Separated existing functions in documentation, into actual script form.

#!/bin/bash
#  shellcheck disable=2016  ## Stubs are written with single-quoted printf on purpose; they expand when they run.

##	Purpose:
##		- Regression tests for the locks of the logout watchdog, tkz_zfs-mount and tkz_user, and for
##		  'tkz_user hold' and 'release'.
##		- A lock any user can reach lets them stop the watchdog, or block encrypted-home logins. So every
##		  lock taken during a run has to sit in a folder only root can get into, and nothing gets written
##		  to /dev/shm or /run/lock.
##		- Needs no root. Each case runs in its own user+mount namespace ('unshare -rm'), with the fake zfs
##		  from lib/fake_zfs.bash and stubs for loginctl, who, ps, getent, systemctl and the like. /run,
##		  /dev/shm, /home, /var/log and /usr/local/sbin are covered inside the namespace only.
##	Usage:
##		tests/tkz_locks.bash [case ...]
##	Copyright and license ...: Toward bottom of this file.

set -euo pipefail

testsDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sbinDir="$(realpath "${testsDir}/../filesystem/debian_13/usr/local/sbin")"
fakeZfs="${testsDir}/lib/fake_zfs.bash"
declare -r propUser="x9.custom.automount:user"
declare -r oldWatchdogLock="/dev/shm/tkz_zfs-crypthome_logout-watchdog.lock"
declare -r oldMountLock="/run/lock/tkz_zfs-mount.lock"
declare -ra sutNames=(tkz_user tkz_zfs-crypthome_logout-watchdog tkz_zfs-crypthome_login tkz_zfs-mount)

declare -ra allCases=(
	parity_run_dir
	watchdog_lock_root_only
	watchdog_planted_flock
	watchdog_planted_dir
	mount_lock_root_only
	mount_planted_dir
	run_dir_tightened
	run_dir_symlink
	run_dir_not_root
	hold_skips_user
	hold_waits_for_watchdog
	hold_needs_real_user
	hold_status
)


## Inside the namespace ##########################################################################

fCheck(){
	## $1: what's checked; the rest: the check. Failures are counted in a file, since cases run in $( ).
	local -r what="$1"; shift
	if "$@"; then return 0; fi
	echo "    not ok: ${what}"
	echo x >> "${D}/failures"
	return 0
}

fWriteStubs(){
	local -r bin="${D}/bin"
	mkdir -p "${bin}"
	## Before each zfs call, note every file the caller holds an flock on. The fd is inherited, so the
	## stub sees the script's own lock.
	cat > "${bin}/zfs" <<-EOF
		#!/bin/bash
		for fd in /proc/\$\$/fd/*; do
			t="\$(readlink "\${fd}" 2>/dev/null)"  ||  continue
			[[ "\${t}" == /* ]]  ||  continue
			read -r dev ino < <(stat -L -c '%d %i' "\${fd}" 2>/dev/null)  ||  continue
			## /proc/locks names the file as major:minor:inode, the first 2 in hex.
			key="\$(printf '%02x:%02x:%s' \$(( (dev >> 8) & 0xfff )) \$(( (dev & 0xff) | ((dev >> 12) & 0xfff00) )) "\${ino}")"
			if K="\${key}" awk '\$2=="FLOCK" && tolower(\$6)==ENVIRON["K"] {f=1} END {exit !f}' /proc/locks; then
				echo "\${t}" >> "\${FAKE_STATE}/locks_seen"
			fi
		done
		exec bash $(printf '%q' "${fakeZfs}") "\$@"
	EOF
	printf '#!/bin/bash\nexit 0\n' > "${bin}/chattr"
	printf '#!/bin/bash\necho "--------------e------- ${*: -1}"\n' > "${bin}/lsattr"
	printf '#!/bin/bash\nexit 0\n' > "${bin}/logger"
	printf '#!/bin/bash\nexit 0\n' > "${bin}/systemctl"
	printf '#!/bin/bash\nexit 0\n' > "${bin}/fuser"
	printf '#!/bin/bash\nexit 1\n' > "${bin}/pgrep"
	printf '#!/bin/bash\nexit 1\n' > "${bin}/logname"
	printf '#!/bin/bash\ncat "${FAKE_STATE}/who" 2>/dev/null\nexit 0\n' > "${bin}/who"
	cat > "${bin}/getent" <<-'EOF'
		#!/bin/bash
		## Like the real one, a key that's all digits matches the uid.
		[[ -f "${FAKE_STATE}/$1" ]]  ||  exit 1
		awk -F: -v k="${2:-}" 'k=="" || $1==k || ($3==k && k ~ /^[0-9]+$/) {print; found=1} END {exit !found}' "${FAKE_STATE}/$1"  ||  exit 2
	EOF
	cat > "${bin}/loginctl" <<-'EOF'
		#!/bin/bash
		## With $FAKE_STATE/pause there, a 'show-user' waits for $FAKE_STATE/go, so a pass can be caught
		## while it holds its lock.
		if [[ "$1" == show-user && -f "${FAKE_STATE}/pause" ]]; then
			touch "${FAKE_STATE}/paused"
			for ((i = 0; i < 100; i++)); do [[ -f "${FAKE_STATE}/go" ]] && break; sleep 0.1; done
		fi
		[[ "$1" == show-user ]]  &&  { echo "Failed to get user: not logged in or lingering" >&2; exit 1; }
		exit 0
	EOF
	cat > "${bin}/ps" <<-'EOF'
		#!/bin/bash
		## Lines in $FAKE_STATE/ps: user pid tty comm. Takes '-o a=,b= -u user'.
		fmt=""  user=""  found=0
		while (($#)); do case "$1" in -o) fmt="$2"; shift ;; -u) user="$2"; shift ;; esac; shift; done
		IFS=, read -r -a cols <<<"${fmt}"
		while read -r pu pid tty comm; do
			[[ "${pu}" == "${user}" ]]  ||  continue
			found=1; out=()
			for c in "${cols[@]}"; do
				case "${c%=}" in pid) out+=("${pid}") ;; tty) out+=("${tty}") ;; comm) out+=("${comm}") ;; esac
			done
			echo "${out[*]}"
		done < <(cat "${FAKE_STATE}/ps" 2>/dev/null)
		((found))
	EOF
	chmod +x "${bin}"/*
}

fCoverHostPaths(){
	## Mounts here vanish with the namespace. /run as on a real box: only root can create anything in it.
	mkdir -p "${D}/home" "${D}/varlog" "${D}/empty"
	mount -t tmpfs -o mode=755 tmpfs /run
	mkdir /run/lock; chmod 1777 /run/lock
	mount -t tmpfs -o mode=1777 tmpfs /dev/shm
	mount --bind "${D}/home" /home
	mount --bind "${D}/varlog" /var/log
	mount --bind "${D}/sut" /usr/local/sbin
	[[ -d /etc/cryptkeys ]]  &&  mount --bind "${D}/empty" /etc/cryptkeys
	return 0
}

fWorld(){
	## alice has an encrypted home with a child dataset, unlocked and mounted, and is logged out.
	zfs create -o mountpoint=none tpool
	zfs create -o mountpoint=/home tpool/home
	echo "alice:x:1001:1001::/home/alice:/bin/bash" > "${FAKE_STATE}/passwd"
	printf 'alicepass1\n' | zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=prompt \
		-o canmount=noauto -o mountpoint=/home/alice -o "${propUser}=alice" tpool/home/alice
	zfs mount tpool/home/alice
	zfs create -o canmount=on -o mountpoint=/home/alice/tmp tpool/home/alice/tmp
	echo "hello alice" > /home/alice/a.txt
	rm -f "${FAKE_STATE}/locks_seen"
}

fLock(){
	## Locks alice's home the way a reboot would.
	zfs unmount tpool/home/alice
	zfs unload-key tpool/home/alice
}

fWatchdog(){
	## Sets $rc. The pass's own log goes to /var/log, which is copied into the case's log.
	rc=0
	/usr/local/sbin/tkz_zfs-crypthome_logout-watchdog --unattended >> "${D}/out.log" 2>&1  ||  rc=$?
	cat /var/log/tkz_zfs-crypthome_logout-watchdog.log >> "${D}/out.log" 2>/dev/null  ||  true
	rm -f /var/log/tkz_zfs-crypthome_logout-watchdog.log
}
fTkzUser(){ rc=0; /usr/local/sbin/tkz_user "$@" >> "${D}/out.log" 2>&1  ||  rc=$?; }
fLogin(){ rc=0; printf '%s' "$1" | PAM_USER=alice /usr/local/sbin/tkz_zfs-crypthome_login >> "${D}/out.log" 2>&1  ||  rc=$?; }

fZfsVal(){ zfs get -H -o value "$2" "$1" 2>/dev/null; }
fSame(){ [[ "$1" == "$2" ]]; }
fIsNonZero(){ [[ "$1" != 0 ]]; }
fIsUnlocked(){ [[ "$(fZfsVal tpool/home/alice keystatus) $(fZfsVal tpool/home/alice mounted) $(fZfsVal tpool/home/alice/tmp mounted)" == "available yes yes" ]]; }
fIsLocked(){ [[ "$(fZfsVal tpool/home/alice keystatus) $(fZfsVal tpool/home/alice mounted) $(fZfsVal tpool/home/alice/tmp mounted)" == "unavailable no no" ]]; }
fNoFile(){ [[ ! -e "$1" && ! -L "$1" ]]; }

fNothingInSharedDirs(){
	## $1...: what the case planted there itself.
	local f=""  p=""  planted=0
	while IFS= read -r f; do
		planted=0
		for p in "$@"; do [[ "${f}" == "${p}" ]] && planted=1; done
		((planted))  ||  { echo "    found: ${f}"; return 1; }
	done < <(find /dev/shm /run/lock -mindepth 1 -maxdepth 1)
	return 0
}

fLocksRootOnly(){
	## Every lock seen held during the run is in a 0700 root folder, under folders nobody else can write.
	[[ -s "${FAKE_STATE}/locks_seen" ]]  ||  { echo "    no lock was seen held"; return 1; }
	local lockPath=""  d=""  mode=""
	while IFS= read -r lockPath; do
		d="$(dirname "${lockPath}")"
		if [[ -L "${d}" || "$(stat -c '%u %a' "${d}")" != "0 700" ]]; then
			echo "    ${lockPath}: its folder is $(stat -c '%U %a' "${d}")"
			return 1
		fi
		while [[ "${d}" != / ]]; do
			d="$(dirname "${d}")"
			mode="$(stat -c %a "${d}")"
			if (( (8#${mode} & 8#022) != 0 )); then
				echo "    ${lockPath}: '${d}' is mode ${mode}"
				return 1
			fi
		done
	done < <(sort -u "${FAKE_STATE}/locks_seen")
	return 0
}

fCase_watchdog_lock_root_only(){
	fWorld
	fWatchdog
	fCheck "watchdog ran" fSame "${rc}" 0
	fCheck "alice's home got locked" fIsLocked
	fCheck "the watchdog's lock is root-only" fLocksRootOnly
	fCheck "nothing left in /dev/shm or /run/lock" fNothingInSharedDirs
}

## Item 4. Any user can make files in /dev/shm and /run/lock.
fCase_watchdog_planted_flock(){
	fWorld
	flock "${oldWatchdogLock}" sleep 60 &
	local -r attacker=$!
	while flock -n "${oldWatchdogLock}" true 2>/dev/null; do sleep 0.05; done
	fWatchdog
	kill "${attacker}" 2>/dev/null  ||  true
	fCheck "alice's home got locked anyway" fIsLocked
	fCheck "the watchdog's lock is root-only" fLocksRootOnly
}

fCase_watchdog_planted_dir(){
	fWorld
	mkdir "${oldWatchdogLock}"
	fWatchdog
	fCheck "watchdog ran" fSame "${rc}" 0
	fCheck "alice's home got locked anyway" fIsLocked
	fCheck "nothing else left in /dev/shm or /run/lock" fNothingInSharedDirs "${oldWatchdogLock}"
}

fCase_mount_lock_root_only(){
	fWorld
	fLock
	fLogin alicepass1
	fCheck "login worked" fSame "${rc}" 0
	fCheck "alice's home is mounted" fIsUnlocked
	fCheck "tkz_zfs-mount's lock is root-only" fLocksRootOnly
	fCheck "nothing left in /dev/shm or /run/lock" fNothingInSharedDirs
}

fCase_mount_planted_dir(){
	fWorld
	fLock
	mkdir "${oldMountLock}"
	fLogin alicepass1
	fCheck "login worked anyway" fSame "${rc}" 0
	fCheck "alice's home is mounted" fIsUnlocked
	fCheck "nothing else left in /dev/shm or /run/lock" fNothingInSharedDirs "${oldMountLock}"
}

## An older tkz_startup-log made /run/tkz mode 755.
fCase_run_dir_tightened(){
	fWorld
	mkdir -m 755 /run/tkz
	fWatchdog
	fCheck "watchdog ran" fSame "${rc}" 0
	fCheck "/run/tkz is 0700 after the watchdog" fSame "$(stat -c %a /run/tkz)" 700
	fCheck "alice's home got locked" fIsLocked
	chmod 755 /run/tkz
	fLogin alicepass1
	fCheck "login worked" fSame "${rc}" 0
	fCheck "/run/tkz is 0700 after tkz_zfs-mount" fSame "$(stat -c %a /run/tkz)" 700
	chmod 755 /run/tkz
	fTkzUser hold alice
	fCheck "hold worked" fSame "${rc}" 0
	fCheck "/run/tkz is 0700 after tkz_user hold" fSame "$(stat -c %a /run/tkz)" 700
}

## Only root can make these, but a run must not write through them.
fRefusesRunDir(){
	## $1: a folder that must stay empty.
	fWatchdog
	fCheck "watchdog refused" fIsNonZero "${rc}"
	fCheck "alice's home wasn't touched" fIsUnlocked
	fTkzUser hold alice
	fCheck "hold refused" fIsNonZero "${rc}"
	fLock
	fLogin alicepass1
	fCheck "login refused, since tkz_zfs-mount did" fIsNonZero "${rc}"
	fCheck "no lock or hold made in '$1'" fSame "$(find "$1" -maxdepth 1 \( -name 'hold.*' -o -name '*.lock' \) | head -n 1)" ""
}
fCase_run_dir_symlink(){
	fWorld
	mkdir /dev/shm/elsewhere
	ln -s /dev/shm/elsewhere /run/tkz
	fRefusesRunDir /dev/shm/elsewhere
}
fCase_run_dir_not_root(){
	fWorld
	## Owned by the real root, which is nobody in here.
	mkdir /run/tkz
	mount --bind /usr/share/doc /run/tkz
	fRefusesRunDir /run/tkz
}

## The hold.
fCase_hold_skips_user(){
	fWorld
	fTkzUser hold alice
	fCheck "hold worked" fSame "${rc}" 0
	fCheck "hold file is there" test -f /run/tkz/hold.alice
	fWatchdog
	fCheck "watchdog ran" fSame "${rc}" 0
	fCheck "held home stayed unlocked" fIsUnlocked
	fTkzUser release alice
	fCheck "release worked" fSame "${rc}" 0
	fCheck "hold file is gone" fNoFile /run/tkz/hold.alice
	fWatchdog
	fCheck "home got locked after the release" fIsLocked
	fTkzUser release alice
	fCheck "a second release is fine" fSame "${rc}" 0
}

fCase_hold_waits_for_watchdog(){
	fWorld
	touch "${FAKE_STATE}/pause"
	fWatchdog &
	local -r watchdogPid=$!
	local -i i=0
	for ((i = 0; i < 100; i++)); do [[ -f "${FAKE_STATE}/paused" ]] && break; sleep 0.1; done
	fCheck "watchdog pass started" test -f "${FAKE_STATE}/paused"
	/usr/local/sbin/tkz_user hold alice >> "${D}/out.log" 2>&1 &
	local -r holdPid=$!
	sleep 1
	fCheck "hold waits while a pass runs" fNoFile /run/tkz/hold.alice
	touch "${FAKE_STATE}/go"
	wait "${watchdogPid}"  ||  true
	rc=0; wait "${holdPid}"  ||  rc=$?
	fCheck "hold worked once the pass ended" fSame "${rc}" 0
	fCheck "hold file is there" test -f /run/tkz/hold.alice
	rm -f "${FAKE_STATE}/pause"
	## The pass that was already running locked it. Unlock it by hand, as an admin would.
	if fIsLocked; then
		printf 'alicepass1\n' | zfs load-key tpool/home/alice
		zfs mount tpool/home/alice
		zfs mount tpool/home/alice/tmp
	fi
	fWatchdog
	fCheck "the next pass leaves the held home alone" fIsUnlocked
}

fCase_hold_needs_real_user(){
	fWorld
	local u=""
	for u in bob 1001 ../alice "alice/x" ""; do
		fTkzUser hold "${u}"
		fCheck "hold '${u}' refused" fIsNonZero "${rc}"
	done
	fCheck "no hold file made" fSame "$(find /run/tkz -name 'hold*' 2>/dev/null | head -n 1)" ""
	fTkzUser release bob
	fCheck "release of no such user refused" fIsNonZero "${rc}"
}

fCase_hold_status(){
	fWorld
	fTkzUser hold alice
	local out=""
	out="$(/usr/local/sbin/tkz_user status 2>&1)"  ||  true
	echo "${out}" >> "${D}/out.log"
	fCheck "status names the held user" grep -qiE 'held.*alice' <<<"${out}"
}

fInNamespace(){
	local -r name="$1"
	D="$2"
	read -r nsInside nsOutside _ < /proc/self/uid_map
	[[ "${nsInside} ${nsOutside}" != "0 0" ]]  ||  { echo "Refusing to run outside a user namespace." >&2; exit 2; }
	export FAKE_ZFS_ROOT="${D}/zfs"  FAKE_STATE="${D}/state"
	mkdir -p "${FAKE_ZFS_ROOT}" "${FAKE_STATE}" "${D}/sut"
	local s=""
	for s in "${sutNames[@]}"; do cp "${sbinDir}/${s}" "${D}/sut/${s}"; done
	cp "${fakeZfs}" "${D}/fake_zfs.bash"
	fakeZfs="${D}/fake_zfs.bash"
	chmod 755 "${D}/sut"/*
	fWriteStubs
	fCoverHostPaths
	unset SUDO_USER
	export PATH="${D}/bin:${PATH}"
	cd /
	"fCase_${name}"
	[[ ! -s "${D}/failures" ]]
}


## Outside ########################################################################################

fFuncBody(){ awk '/^function fRunDir\(\)\{/ {on=1} on {print} on && /^}/ {exit}' "$1"; }

fCase_parity_run_dir(){
	local a="" b="" s=""
	a="$(fFuncBody "${sbinDir}/tkz_zfs-crypthome_logout-watchdog")"
	[[ -n "${a}" ]]  ||  { echo "    not ok: fRunDir found in the watchdog"; return 1; }
	for s in tkz_user tkz_zfs-mount; do
		b="$(fFuncBody "${sbinDir}/${s}")"
		[[ "${a}" == "${b}" ]]  ||  { echo "    not ok: ${s}'s fRunDir matches the watchdog's"; return 1; }
	done
}

fMain(){
	if [[ "${1:-}" == "--in-ns" ]]; then
		fInNamespace "$2" "$3"
		return
	fi
	command -v unshare &>/dev/null  ||  { echo "unshare isn't installed." >&2; return 1; }
	local -a cases=("$@")
	((${#cases[@]}))  ||  cases=("${allCases[@]}")

	local -r runDir="/tmp/test_tkz_locks_$(date +%Y%m%d-%H%M%S%2N)"
	mkdir "${runDir}"
	local name=""  failed=""
	local -i passCount=0  failCount=0
	for name in "${cases[@]}"; do
		if [[ "${name}" == parity_run_dir ]]; then
			if fCase_parity_run_dir; then echo "ok   ${name}"; passCount=$((passCount + 1)); else echo "FAIL ${name}"; failCount=$((failCount + 1)); failed+=" ${name}"; fi
			continue
		fi
		mkdir "${runDir}/${name}"
		if unshare -rm --propagation private bash "${BASH_SOURCE[0]}" --in-ns "${name}" "${runDir}/${name}"; then
			echo "ok   ${name}"; passCount=$((passCount + 1))
		else
			echo "FAIL ${name}  (log: ${runDir}/${name}/out.log)"; failCount=$((failCount + 1)); failed+=" ${name}"
		fi
	done
	echo "${passCount} passed, ${failCount} failed.${failed:+ Failed:${failed}}"
	if ((failCount == 0)); then
		## Only the dir this run made, and only once nothing is mounted (the namespaces are gone).
		[[ "${runDir}" == /tmp/test_tkz_locks_* && -d "${runDir}" ]]  &&  rm -rf "${runDir}"
		return 0
	fi
	return 1
}

fMain "$@"


##	Copyright © 2026 t00mietum
##	Licensed under The MIT License.
##		https://spdx.org/licenses/MIT.html
##	SPDX-License-Identifier: MIT

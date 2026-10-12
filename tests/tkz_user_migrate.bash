#!/bin/bash
#  shellcheck disable=2016  ## Stubs are written with single-quoted printf on purpose; they expand when they run.
#  shellcheck disable=2088  ## '~/' in check names is text for people.

##	Purpose:
##		- Regression tests for 'tkz_user migrate': symlinked children, rollback after a failure partway,
##		  and the logged-in test it shares with the logout watchdog.
##		- Needs no root. Each case runs in its own user+mount namespace ('unshare -rm'), with a fake zfs
##		  (lib/fake_zfs.bash) and stubs for loginctl, who, ps, getent, chpasswd, chown and the like.
##		  /home, /run, /etc/skel and /usr/local/sbin are covered inside the namespace only.
##		- The login helper runs for real against the fake zfs, as the check that a login still works.
##	Usage:
##		tests/tkz_user_migrate.bash [case ...]
##		TKZ_USER=<path> tests/tkz_user_migrate.bash   ## Same cases against another copy of tkz_user.
##	Copyright and license ...: Toward bottom of this file.

set -euo pipefail

testsDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sbinDir="${testsDir}/../filesystem/debian_13/usr/local/sbin"
tkzUser="$(realpath "${TKZ_USER:-${sbinDir}/tkz_user}")"
loginHelper="$(realpath "${sbinDir}/tkz_zfs-crypthome_login")"
watchdog="$(realpath "${sbinDir}/tkz_zfs-crypthome_logout-watchdog")"
fakeZfs="${testsDir}/lib/fake_zfs.bash"
declare -r propUser="x9.custom.automount:user"

declare -ra allCases=(
	parity_in_use_test
	no_home_dataset
	ok_dataset
	ok_folder
	in_use_loginctl
	in_use_who
	in_use_su_tty
	in_use_cron
	in_use_lingering
	in_use_during_copy
	symlinked_children
	tmp_is_a_file
	fail_rsync
	fail_child_create
	fail_chpasswd
	fail_set_property
	killed_during_copy
	interrupted_during_copy
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
	printf '#!/bin/bash\nexec bash %q "$@"\n' "${fakeZfs}" > "${bin}/zfs"
	printf '#!/bin/bash\nexit 0\n' > "${bin}/chattr"
	printf '#!/bin/bash\nexit 0\n' > "${bin}/logger"
	printf '#!/bin/bash\necho "$*" >> "${FAKE_STATE}/chown.log"\n' > "${bin}/chown"
	printf '#!/bin/bash\n[[ "$1" == -gn ]] && { echo "$2"; exit 0; }\nexec %q "$@"\n' "$(command -v id)" > "${bin}/id"
	cat > "${bin}/getent" <<-'EOF'
		#!/bin/bash
		[[ -f "${FAKE_STATE}/$1" ]]  ||  exit 1
		awk -F: -v k="${2:-}" 'k=="" || $1==k {print; found=1} END {exit !found}' "${FAKE_STATE}/$1"  ||  exit 2
	EOF
	cat > "${bin}/chpasswd" <<-'EOF'
		#!/bin/bash
		[[ -f "${FAKE_STATE}/chpasswd_fail" ]]  &&  { echo "chpasswd: injected failure" >&2; exit 1; }
		while IFS=: read -r u p; do
			[[ "${1:-}" == -e ]]  ||  p="PLAIN=${p}"
			U="${u}" P="${p}" awk -F: -v OFS=: '$1==ENVIRON["U"] {$2=ENVIRON["P"]} {print}' "${FAKE_STATE}/shadow" > "${FAKE_STATE}/shadow.new"
			mv "${FAKE_STATE}/shadow.new" "${FAKE_STATE}/shadow"
		done
	EOF
	cat > "${bin}/loginctl" <<-'EOF'
		#!/bin/bash
		st="$(cat "${FAKE_STATE}/login_state" 2>/dev/null || true)"
		case "$1" in
			show-user)  [[ -n "${st}" && "$2" == alice ]]  &&  { echo "${st}"; exit 0; }
			            echo "Failed to get user: User ID 1001 is not logged in or lingering" >&2; exit 1 ;;
			list-users) [[ -n "${st}" ]]  &&  echo "1001 alice no ${st}"; exit 0 ;;
		esac
		exit 0
	EOF
	printf '#!/bin/bash\ncat "${FAKE_STATE}/who" 2>/dev/null\nexit 0\n' > "${bin}/who"
	cat > "${bin}/ps" <<-'EOF'
		#!/bin/bash
		## Lines in $FAKE_STATE/ps: user pid tty comm. Takes '-o a=,b= -u user', like the scripts use it.
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
	cat > "${bin}/rsync" <<-EOF
		#!/bin/bash
		[[ -f "\${FAKE_STATE}/rsync_fail" ]]  &&  { echo "rsync: injected failure" >&2; exit 23; }
		$(printf '%q' "$(command -v rsync)") "\$@"  ||  exit
		[[ -f "\${FAKE_STATE}/rsync_after" ]]  &&  bash "\${FAKE_STATE}/rsync_after"
		exit 0
	EOF
	chmod +x "${bin}"/*
}

fCoverHostPaths(){
	## Mounts here vanish with the namespace.
	mkdir -p "${D}/empty" "${D}/skel" "${D}/home"
	echo "## skel" > "${D}/skel/.bashrc"
	mount --bind "${D}/home" /home
	mount -t tmpfs tmpfs /run
	mount --bind "${D}/empty" /usr/local/sbin
	mount --bind "${D}/skel" /etc/skel
	[[ -d /etc/cryptkeys ]]  &&  mount --bind "${D}/empty" /etc/cryptkeys
	return 0
}

fWorld(){
	## $1: 'dataset' or 'folder', for how alice's plain home starts out.
	zfs create -o mountpoint=none tpool
	zfs create -o mountpoint=/home tpool/home
	echo "alice:x:1001:1001::/home/alice:/bin/bash" > "${FAKE_STATE}/passwd"
	echo "alice:PLAIN=oldpass11:20000:0:99999:7:::" > "${FAKE_STATE}/shadow"
	if [[ "$1" == dataset ]]; then zfs create tpool/home/alice; else mkdir /home/alice; fi
	mkdir -p /home/alice/docs /home/alice/.cache /home/alice/tmp /home/alice/var
	echo "hello alice" > /home/alice/docs/a.txt
	echo c1 > /home/alice/.cache/c1.txt
	echo t1 > /home/alice/tmp/t1.txt
	echo v1 > /home/alice/var/v1.txt
	baseLog="$(wc -l < "${FAKE_ZFS_ROOT}/log")"
}

fMigrate(){
	## Runs the migrate. Sets $rc. Output goes to the case's log.
	rc=0
	## The subshell keeps bash's "Killed" job notice out of the report.
	( printf 'newpass11\nnewpass11\n' | "${tkzUser}" migrate alice >> "${D}/out.log" 2>&1 ) 2>/dev/null  ||  rc=$?
}

fPwd(){ awk -F: '$1=="alice" {sub(/^PLAIN=/, "", $2); print $2}' "${FAKE_STATE}/shadow"; }
fLoginWith(){ printf '%s' "$1" | PAM_USER=alice "${loginHelper}" >> "${D}/out.log" 2>&1; }
fZfsVal(){ zfs get -H -o value "$2" "$1" 2>/dev/null; }
fNoneMarked(){ [[ -z "$(zfs get -H -t filesystem -s local -o name,value "${propUser}")" ]]; }
fNoLeftovers(){ ! zfs list -H -o name | grep -qE '_migrating-|_pre-encrypt-'; }
fZfsCreatedNothing(){ ! tail -n "+$((baseLog + 1))" "${FAKE_ZFS_ROOT}/log" | grep -q '^create '; }
fSame(){ [[ "$1" == "$2" ]]; }
fIsNonZero(){ [[ "$1" != 0 ]]; }
fFile(){ [[ -f "$1" && "$(cat "$1")" == "$2" ]]; }

fAssertUntouched(){
	## $1: dataset or folder. The state a migrate that was refused, or rolled back, has to leave.
	fCheck "migrate failed" fIsNonZero "${rc}"
	fCheck "password is still the old one" fSame "$(fPwd)" oldpass11
	fCheck "no dataset has ${propUser}" fNoneMarked
	fCheck "no temp or kept datasets left" fNoLeftovers
	fCheck "no kept folder left" fSame "$(compgen -G '/home/alice.pre-encrypt-*' || true)" ""
	fCheck "old home has its files" fFile /home/alice/docs/a.txt "hello alice"
	fCheck "old home has its tmp files" fFile /home/alice/tmp/t1.txt t1
	if [[ "$1" == dataset ]]; then
		fCheck "old dataset is mounted" fSame "$(fZfsVal tpool/home/alice mounted)" yes
		fCheck "old dataset's mountpoint is inherited again" fSame "$(zfs get -H -o source mountpoint tpool/home/alice)" "inherited from tpool/home"
		fCheck "old dataset's canmount is back" fSame "$(fZfsVal tpool/home/alice canmount)" on
		fCheck "old dataset isn't encrypted" fSame "$(fZfsVal tpool/home/alice encryption)" off
	else
		fCheck "no dataset at tpool/home/alice" fSame "$(zfs list -H -o name tpool/home/alice 2>/dev/null || true)" ""
	fi
	fCheck "login with the old password still works" fLoginWith oldpass11
}

fAssertMigrated(){
	fCheck "migrate succeeded" fSame "${rc}" 0
	fCheck "password is the new one" fSame "$(fPwd)" newpass11
	fCheck "home is encrypted" fSame "$(fZfsVal tpool/home/alice encryptionroot)" tpool/home/alice
	fCheck "${propUser} is set on the home" fSame "$(zfs get -H -s local -o value "${propUser}" tpool/home/alice)" alice
	fCheck "only the home has ${propUser}" fSame "$(zfs get -H -t filesystem -s local -o name,value "${propUser}" | wc -l)" 1
	fCheck "home is canmount=noauto" fSame "$(fZfsVal tpool/home/alice canmount)" noauto
	fCheck "home is locked after" fSame "$(fZfsVal tpool/home/alice keystatus)" unavailable
	fCheck "no temp dataset left" fSame "$(zfs list -H -o name | grep -c _migrating- || true)" 0
	fCheck "login with the new password works" fLoginWith newpass11
	fCheck "files came across" fFile /home/alice/docs/a.txt "hello alice"
	fCheck "no parked folders left in the home" fSame "$(compgen -G '/home/alice/*.migrating-*' || true)" ""
}

fAssertChild(){
	## $1: child name; $2: file in it; $3: its content.
	fCheck "~/$1 is a dataset" fSame "$(fZfsVal "tpool/home/alice/$1" mounted)" yes
	fCheck "~/$1/$2 came across" fFile "/home/alice/$1/$2" "$3"
}

fCase_no_home_dataset(){
	zfs create -o mountpoint=none tpool
	echo "alice:x:1001:1001::/home/alice:/bin/bash" > "${FAKE_STATE}/passwd"
	echo "alice:PLAIN=oldpass11:20000:0:99999:7:::" > "${FAKE_STATE}/shadow"
	mkdir -p /home/alice
	baseLog="$(wc -l < "${FAKE_ZFS_ROOT}/log")"
	rc=0; "${tkzUser}" status >> "${D}/out.log" 2>&1  ||  rc=$?
	fCheck "status fails when nothing is mounted at /home" fIsNonZero "${rc}"
	fMigrate
	fCheck "migrate fails when nothing is mounted at /home" fIsNonZero "${rc}"
	fCheck "migrate created nothing" fZfsCreatedNothing
}

fCase_ok_dataset(){
	fWorld dataset
	fMigrate
	fAssertMigrated
	fAssertChild .cache c1.txt c1
	fAssertChild tmp t1.txt t1
	fAssertChild var v1.txt v1
	fCheck "old dataset kept, canmount=noauto" fSame "$(zfs list -H -o name,canmount | awk '/_pre-encrypt-/ {print $2}')" noauto
}

fCase_ok_folder(){
	fWorld folder
	fMigrate
	fAssertMigrated
	fAssertChild var v1.txt v1
	fCheck "old folder kept" fFile "$(compgen -G '/home/alice.pre-encrypt-*' || true)/docs/a.txt" "hello alice"
}

## Item 14. Each of these is someone still using the home.
fRefused(){
	fMigrate
	fCheck "migrate created nothing" fZfsCreatedNothing
	fAssertUntouched dataset
}
fCase_in_use_loginctl(){  fWorld dataset; echo active > "${FAKE_STATE}/login_state"; fRefused; }
fCase_in_use_lingering(){ fWorld dataset; echo lingering > "${FAKE_STATE}/login_state"; fRefused; }
fCase_in_use_who(){       fWorld dataset; echo "alice    pts/1        2026-10-12 10:00" > "${FAKE_STATE}/who"; fRefused; }
fCase_in_use_su_tty(){    fWorld dataset; echo "alice 4242 pts/3 bash" > "${FAKE_STATE}/ps"; fRefused; }
fCase_in_use_cron(){      fWorld dataset; echo "alice 4243 ? backup.sh" > "${FAKE_STATE}/ps"; fRefused; }

fCase_in_use_during_copy(){
	fWorld dataset
	printf 'echo "alice 4244 pts/4 bash" > "%s/ps"\n' "${FAKE_STATE}" > "${FAKE_STATE}/rsync_after"
	fMigrate
	fAssertUntouched dataset
}

## Item 2.
fCase_symlinked_children(){
	fWorld dataset
	local -r out="${D}/outside"
	mkdir -p "${out}/cache" "${out}/tmp" "${out}/decoy"
	echo secret > "${out}/cache/secret.txt"
	echo t2 > "${out}/tmp/t2.txt"
	echo d1 > "${out}/decoy/d1.txt"
	chmod 1777 "${out}/tmp"
	rm -rf /home/alice/.cache /home/alice/tmp
	ln -s "${out}/cache" /home/alice/.cache
	ln -s "${out}/tmp" /home/alice/tmp
	ln -s "${out}/decoy" /home/alice/var.migrating
	fMigrate
	fAssertMigrated
	fCheck "file behind ~/.cache link stayed put" fFile "${out}/cache/secret.txt" secret
	fCheck "file behind ~/tmp link stayed put" fFile "${out}/tmp/t2.txt" t2
	fCheck "file behind ~/var.migrating link stayed put" fFile "${out}/decoy/d1.txt" d1
	fCheck "~/tmp link target kept its mode" fSame "$(stat -c %a "${out}/tmp")" 1777
	fCheck "~/.cache is still a link" fSame "$(readlink /home/alice/.cache)" "${out}/cache"
	fCheck "~/tmp is still a link" fSame "$(readlink /home/alice/tmp)" "${out}/tmp"
	fCheck "~/var.migrating is still a link" fSame "$(readlink /home/alice/var.migrating)" "${out}/decoy"
	fCheck "no .cache dataset" fSame "$(zfs list -H -o name tpool/home/alice/.cache 2>/dev/null || true)" ""
	fAssertChild var v1.txt v1
}

## Items 3 and 2: a file where a child dataset goes no longer stops the migrate.
fCase_tmp_is_a_file(){
	fWorld folder
	rm -rf /home/alice/tmp
	echo "just a file" > /home/alice/tmp
	fMigrate
	fAssertMigrated
	fCheck "~/tmp is still the file" fFile /home/alice/tmp "just a file"
	fAssertChild var v1.txt v1
}

## Item 3. Each fails at a different step, and has to leave alice able to log in as before.
fCase_fail_rsync(){       fWorld dataset; touch "${FAKE_STATE}/rsync_fail"; fMigrate; fAssertUntouched dataset; }
fCase_fail_chpasswd(){    fWorld dataset; touch "${FAKE_STATE}/chpasswd_fail"; fMigrate; fAssertUntouched dataset; }
fCase_fail_child_create(){
	fWorld folder
	echo 'create * tpool/home/alice/var' > "${FAKE_ZFS_ROOT}/fail"
	fMigrate
	fAssertUntouched folder
}
fCase_fail_set_property(){
	fWorld dataset
	echo "set ${propUser}=* tpool/home/alice" > "${FAKE_ZFS_ROOT}/fail"
	fMigrate
	fAssertUntouched dataset
}

## Item 3, the order: with no trap to run, the automount property must not be on a dataset keyed to a
## password that isn't the login password yet.
fCase_killed_during_copy(){
	fWorld dataset
	## The hook's parent is the rsync stub, whose parent is tkz_user.
	echo 'kill -KILL "$(awk '"'"'{print $4}'"'"' "/proc/${PPID}/stat")"' > "${FAKE_STATE}/rsync_after"
	fMigrate
	fCheck "migrate was killed" fSame "${rc}" 137
	fReboot
	fCheck "password is still the old one" fSame "$(fPwd)" oldpass11
	fCheck "no dataset has ${propUser}" fNoneMarked
	fCheck "login with the old password still works" fLoginWith oldpass11
}

fCase_interrupted_during_copy(){
	fWorld dataset
	echo 'kill -INT "$(awk '"'"'{print $4}'"'"' "/proc/${PPID}/stat")"' > "${FAKE_STATE}/rsync_after"
	fMigrate
	fCheck "migrate exited 130" fSame "${rc}" 130
	fAssertUntouched dataset
}

fReboot(){
	## Every encrypted dataset ends up unmounted and locked.
	local n="" root=""
	while IFS=$'\t' read -r n root; do
		[[ "${n}" == "${root}" && "$(fZfsVal "${n}" keystatus)" == available ]]  ||  continue
		zfs list -H -r -o name,mounted "${n}" | awk -F'\t' '$2=="yes" {print $1}' | tac | while read -r m; do zfs unmount "${m}"; done
		zfs unload-key "${n}"
	done < <(zfs list -H -o name,encryptionroot)
}

fInNamespace(){
	local -r name="$1"
	D="$2"
	read -r nsInside nsOutside _ < /proc/self/uid_map
	[[ "${nsInside} ${nsOutside}" != "0 0" ]]  ||  { echo "Refusing to run outside a user namespace." >&2; exit 2; }
	export FAKE_ZFS_ROOT="${D}/zfs"  FAKE_STATE="${D}/state"
	mkdir -p "${FAKE_ZFS_ROOT}" "${FAKE_STATE}" "${D}/sut"
	## The fake /home mount hides anything under the real /home, the repo included.
	cp "${tkzUser}" "${D}/sut/tkz_user"
	cp "${loginHelper}" "${D}/sut/tkz_zfs-crypthome_login"
	cp "${fakeZfs}" "${D}/sut/fake_zfs.bash"
	chmod 755 "${D}/sut"/*
	tkzUser="${D}/sut/tkz_user"  loginHelper="${D}/sut/tkz_zfs-crypthome_login"  fakeZfs="${D}/sut/fake_zfs.bash"
	fWriteStubs
	fCoverHostPaths
	export PATH="${D}/bin:${PATH}"
	cd /
	"fCase_${name}"
	[[ ! -s "${D}/failures" ]]
}


## Outside ########################################################################################

fFuncBody(){ awk '/^function fIsUserInUse\(\)\{/ {on=1} on {print} on && /^}/ {exit}' "$1"; }

fCase_parity_in_use_test(){
	local a="" b=""
	a="$(fFuncBody "${watchdog}")"
	b="$(fFuncBody "${tkzUser}")"
	[[ -n "${a}" ]]  ||  { echo "    not ok: fIsUserInUse found in the watchdog"; return 1; }
	[[ "${a}" == "${b}" ]]  ||  { echo "    not ok: tkz_user's fIsUserInUse matches the watchdog's"; return 1; }
}

fMain(){
	if [[ "${1:-}" == "--in-ns" ]]; then
		fInNamespace "$2" "$3"
		return
	fi
	command -v unshare &>/dev/null  ||  { echo "unshare isn't installed." >&2; return 1; }
	command -v rsync &>/dev/null  ||  { echo "rsync isn't installed." >&2; return 1; }
	local -a cases=("$@")
	((${#cases[@]}))  ||  cases=("${allCases[@]}")

	local -r runDir="/tmp/test_tkz_user_migrate_$(date +%Y%m%d-%H%M%S%2N)"
	mkdir "${runDir}"
	echo "tkz_user: ${tkzUser}"
	local name=""  failed=""
	local -i passCount=0  failCount=0
	for name in "${cases[@]}"; do
		if [[ "${name}" == parity_in_use_test ]]; then
			if fCase_parity_in_use_test; then echo "ok   ${name}"; passCount=$((passCount + 1)); else echo "FAIL ${name}"; failCount=$((failCount + 1)); failed+=" ${name}"; fi
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
		[[ "${runDir}" == /tmp/test_tkz_user_migrate_* && -d "${runDir}" ]]  &&  rm -rf "${runDir}"
		return 0
	fi
	return 1
}

fMain "$@"


##	Copyright © 2026 t00mietum
##	Licensed under The MIT License.
##		https://spdx.org/licenses/MIT.html
##	SPDX-License-Identifier: MIT

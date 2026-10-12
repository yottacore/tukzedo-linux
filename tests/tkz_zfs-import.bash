#!/bin/bash
#  shellcheck disable=2016  ## Stubs are written with single-quoted heredocs on purpose; they expand when they run.

##	Purpose:
##		- Regression tests for tkz_zfs-import and the units that run it at boot.
##		- Needs no root. Each script case runs in its own user+mount namespace ('unshare -rm'), with a fake
##		  zpool, lvm, udevadm, modprobe and sleep. /proc/cmdline, /sys/class/block, /dev/mapper, /etc/zfs and
##		  /usr/local/sbin are covered inside the namespace only.
##		- The fake zpool keeps its pools in files: which devices each one is on, and whether another host
##		  had it last. It refuses an import the way the real one does: 'no such pool' when a device is
##		  missing, and 'previously in use from another system' without '-f'.
##		- The 'unit_*' cases read the unit files and check what systemd would do with them.
##	Usage:
##		tests/tkz_zfs-import.bash [case ...]
##		TKZ_TREE=<dir> tests/tkz_zfs-import.bash   ## Test another copy of filesystem/debian_13
##	Copyright and license ...: Toward bottom of this file.

set -euo pipefail

testsDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
treeDir="$(realpath "${TKZ_TREE:-${testsDir}/../filesystem/debian_13}")"
declare -r luksUuid="5a185df4-1996-4b36-ad4c-a283fc810917"
declare -r baseCmdline="rd.luks.name=${luksUuid}=crypt_t rd.lvm.lv=vg_t/lv_rpool_t rd.lvm.lv=vg_t/lv_swap_t root=ZFS=rpool_t/deb/ROOT quiet"

declare -ra allCases=(
	lv_inactive
	lv_late
	lv_already_active
	lv_dashes
	never_appears
	stale_hostid_inside_luks
	stale_hostid_luks_uuid_form
	stale_hostid_outside_luks
	stale_hostid_partly_outside
	stale_hostid_no_luks
	force_fails_last_error
	root_rootfstype
	root_quoted
	root_not_zfs
	root_autodetect
	unit_root_before_stock_scan
	unit_root_timeout
	unit_no_usr_local
)


## Inside the namespace ##########################################################################

fCheck(){
	## $1: what's checked; the rest: the check. Failures are counted in a file.
	local -r what="$1"; shift
	if "$@"; then return 0; fi
	echo "    not ok: ${what}"
	echo x >> "${D}/failures"
	return 0
}

fWriteStubs(){
	local -r bin="${D}/bin"
	mkdir -p "${bin}"

	## Pool files: ${D}/pools/<name> has 'devs=( ... )' (names under /dev/mapper) and 'foreign=0|1'.
	cat > "${bin}/zpool" <<-'EOF'
		#!/bin/bash
		echo "zpool $*" >> "${D}/calls"
		imported="${D}/imported"; touch "${imported}"
		fDevsOk(){  ## $1 pool; rest: -d restrictions. 0 = all devices there, 1 = none, 2 = some.
			local pool="$1"; shift; local devs=() foreign=0 n=0 d
			source "${D}/pools/${pool}"
			for d in "${devs[@]}"; do
				[[ -e "/dev/mapper/${d}" ]] || continue
				if [[ "$#" -gt 0 ]] && [[ " $* " != *" /dev/mapper/${d} "* ]]; then continue; fi
				n=$((n + 1))
			done
			((n == ${#devs[@]})) && return 0; ((n == 0)) && return 1; return 2
		}
		case "$1" in
			list)    shift; [[ "$*" == "-H -o name" ]] && { cat "${imported}"; exit 0; }
			         grep -qx "${*: -1}" "${imported}" && { echo "${*: -1}"; exit 0; }
			         echo "cannot open '${*: -1}': no such pool" >&2; exit 1 ;;
			get)     echo "-"; exit 0 ;;
			set)     exit 0 ;;
		esac
		[[ "$1" == import ]] || exit 9
		shift; force=0; restrict=(); pool=""
		while [[ "$#" -gt 0 ]]; do
			case "$1" in
				-N) ;;
				-f) force=1 ;;
				-o) shift ;;
				-d) shift; restrict+=("$1") ;;
				*)  pool="$1" ;;
			esac; shift
		done
		if [[ -z "${pool}" ]]; then  ## Listing
			found=0
			for f in "${D}"/pools/*; do
				[[ -e "${f}" ]] || continue; p="${f##*/}"
				grep -qx "${p}" "${imported}" && continue
				rc=0; fDevsOk "${p}" "${restrict[@]}" || rc=$?
				((rc == 1)) && continue
				state=ONLINE; ((rc == 2)) && state=DEGRADED
				printf '   pool: %s\n     id: 123\n  state: %s\n config:\n\n\t%s  %s\n\n' "${p}" "${state}" "${p}" "${state}"
				found=1
			done
			((found)) || echo "no pools available to import"
			exit 0
		fi
		[[ -e "${D}/pools/${pool}" ]] || { echo "cannot import '${pool}': no such pool available" >&2; exit 1; }
		[[ -e "${D}/hang" ]] && sleep 600
		devs=(); foreign=0; source "${D}/pools/${pool}"
		rc=0; fDevsOk "${pool}" "${restrict[@]}" || rc=$?
		((rc == 0)) || { echo "cannot import '${pool}': no such pool available" >&2; exit 1; }
		if ((foreign && ! force)); then
			printf "cannot import '%s': pool was previously in use from another system.\nLast accessed by otherbox (hostid=1234abcd) at Mon Oct 12 07:00:00 2026\nThe pool can be imported, use 'zpool import -f' to import the pool.\n" "${pool}" >&2
			exit 1
		fi
		if ((force)) && [[ -e "${D}/force_fails" ]]; then echo "cannot import '${pool}': I/O error" >&2; exit 1; fi
		echo "${pool}" >> "${imported}"
		exit 0
	EOF

	## LVs: ${D}/lvs/<vg>/<lv> has the dm number. lvchange works once ${D}/pv_after reaches 0.
	cat > "${bin}/lvm" <<-'EOF'
		#!/bin/bash
		echo "lvm $*" >> "${D}/calls"
		[[ "$1" == lvs ]] && { echo "  LV  VG  Attr"; exit 0; }
		[[ "$1" == lvchange ]] || exit 0
		lv="${*: -1}"
		left=0; [[ -e "${D}/pv_after" ]] && left="$(< "${D}/pv_after")"
		if ((left > 0)); then echo $((left - 1)) > "${D}/pv_after"; echo "  Volume group \"${lv%%/*}\" not found" >&2; exit 5; fi
		[[ -e "${D}/lvs/${lv}" ]] || { echo "  Failed to find logical volume \"${lv}\"" >&2; exit 5; }
		vg="${lv%%/*}"; l="${lv#*/}"; name="${vg//-/--}-${l//-/--}"; n="$(< "${D}/lvs/${lv}")"
		: > "/dev/mapper/${name}"
		mkdir -p "/sys/class/block/dm-${n}/dm" "/sys/class/block/dm-${n}/slaves/dm-0"
		echo "${name}" > "/sys/class/block/dm-${n}/dm/name"
		echo "LVM-fake${n}" > "/sys/class/block/dm-${n}/dm/uuid"
		exit 0
	EOF

	printf '#!/bin/bash\necho "udevadm $*" >> "${D}/calls"\nexit 0\n' > "${bin}/udevadm"
	printf '#!/bin/bash\nexit 0\n' > "${bin}/modprobe"
	## The script sleeps 2s between tries. Shorter here, so a timeout case takes a few seconds.
	printf '#!/bin/bash\nexec /bin/sleep 0.2\n' > "${bin}/sleep"
	chmod +x "${bin}"/*
}

fAddDm(){
	## $1 dm number, $2 name, $3 dm uuid, rest: slaves.
	local -r n="$1" name="$2" uuid="$3"; shift 3
	local s=""
	mkdir -p "/sys/class/block/dm-${n}/dm" "/sys/class/block/dm-${n}/slaves"
	echo "${name}" > "/sys/class/block/dm-${n}/dm/name"
	echo "${uuid}" > "/sys/class/block/dm-${n}/dm/uuid"
	for s in "$@"; do mkdir -p "/sys/class/block/dm-${n}/slaves/${s}"; done
	: > "/dev/mapper/${name}"
}

fAddPool(){ printf 'devs=( %s )\nforeign=%s\n' "$2" "$3" > "${D}/pools/$1"; }

fSetup(){
	## Covers everything the script reads, so nothing on this host is used or changed.
	mkdir -p "${D}/sys" "${D}/mapper" "${D}/etc_zfs" "${D}/usr_local_sbin" "${D}/pools" "${D}/lvs/vg_t"
	echo "${baseCmdline}" > "${D}/cmdline"
	mount --bind "${D}/cmdline"        /proc/cmdline
	mount --bind "${D}/sys"            /sys/class/block
	mount --bind "${D}/mapper"         /dev/mapper
	mount --bind "${D}/etc_zfs"        /etc/zfs
	[[ -d /usr/local/sbin ]]  &&  mount --bind "${D}/usr_local_sbin" /usr/local/sbin
	fWriteStubs
	## The open LUKS container, and the LVs on it once activated.
	fAddDm 0 crypt_t "CRYPT-LUKS2-${luksUuid//-/}-crypt_t" sda2
	echo 1 > "${D}/lvs/vg_t/lv_rpool_t"
	echo 2 > "${D}/lvs/vg_t/lv_swap_t"
	fAddPool rpool_t vg_t-lv_rpool_t 0
}

fScript(){
	local s="${treeDir}/usr/sbin/tkz_zfs-import"
	[[ -x "${s}" ]]  ||  s="${treeDir}/usr/local/sbin/tkz_zfs-import"
	echo "${s}"
}

fRun(){
	## Runs the script as the boot does. Exit code goes in ${D}/rc, output in ${D}/out and ${D}/err.
	local rc=0
	PATH="${D}/bin:${PATH}" timeout 60 "$(fScript)" "$@" > "${D}/out" 2> "${D}/err"  ||  rc=$?
	echo "${rc}" > "${D}/rc"
	cat "${D}/out" "${D}/err"
}

fRc(){       [[ "$(< "${D}/rc")" == "$1" ]]; }
fImported(){ grep -qx "$1" "${D}/imported" 2>/dev/null; }
fSaid(){     grep -qF -- "$1" "${D}/out" "${D}/err"; }
fSaidErr(){  grep -qF -- "$1" "${D}/err"; }
fCalled(){   grep -qF -- "$1" "${D}/calls"; }
fNoForce(){  ! grep -q -- "^zpool import .*-f" "${D}/calls"; }

fCase_lv_inactive(){
	## What the stall was: the LUKS container is open, but nothing has activated the LVs yet.
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rpool_t imported"               fImported rpool_t
	fCheck "said it activated the LV"       fSaid "LV 'vg_t/lv_rpool_t' wasn't active yet. Activated it."
	fCheck "activated before importing"     awk '/^lvm lvchange/ {lv=NR} /^zpool import -N/ && !imp {imp=NR} END {exit !(lv && imp && lv < imp)}' "${D}/calls"
	fCheck "no -f"                          fNoForce
}

fCase_lv_late(){
	## The PV shows up on the third try.
	echo 3 > "${D}/pv_after"
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rpool_t imported"               fImported rpool_t
	fCheck "said it would retry"            fSaid "isn't there yet. Will retry."
	fCheck "no -f"                          fNoForce
}

fCase_lv_already_active(){
	fAddDm 1 vg_t-lv_rpool_t LVM-fake1 dm-0
	fAddDm 2 vg_t-lv_swap_t  LVM-fake2 dm-0
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "said it was active"             fSaid "LV 'vg_t/lv_rpool_t' was already active."
	fCheck "no lvchange"                    bash -c '! grep -q "^lvm lvchange" "$1"' _ "${D}/calls"
}

fCase_lv_dashes(){
	## dm doubles a dash inside VG and LV names.
	echo "rd.luks.name=${luksUuid}=crypt_t rd.lvm.lv=vg-x/lv-r root=ZFS=rp/ROOT" > "${D}/cmdline"
	mkdir -p "${D}/lvs/vg-x"; echo 3 > "${D}/lvs/vg-x/lv-r"
	fAddPool rp vg--x-lv--r 0
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rp imported"                    fImported rp
	fCheck "mapper name has doubled dashes" test -e /dev/mapper/vg--x-lv--r
	fRun --root
	fCheck "second run sees it as active"   fSaid "LV 'vg-x/lv-r' was already active."
}

fCase_never_appears(){
	echo 999 > "${D}/pv_after"
	fRun --root --timeout 2
	fCheck "exit 1"                         fRc 1
	fCheck "said FAILED, on stderr"         fSaidErr "FAILED after"
	fCheck "showed diagnostics on stderr"   fSaidErr "Pools zpool can see"
	fCheck "no -f"                          fNoForce
}

fCase_stale_hostid_inside_luks(){
	fAddPool rpool_t vg_t-lv_rpool_t 1
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rpool_t imported"               fImported rpool_t
	fCheck "said why -f was needed"         fSaid "previously in use from another system"
	fCheck "forced inside the container"    fCalled "zpool import -N -f -o cachefile=none -d /dev/mapper/crypt_t -d /dev/mapper/vg_t-lv_rpool_t -d /dev/mapper/vg_t-lv_swap_t rpool_t"
}

fCase_stale_hostid_luks_uuid_form(){
	echo "rd.luks.uuid=luks-${luksUuid^^} rd.lvm.lv=vg_t/lv_rpool_t root=ZFS=rpool_t/deb/ROOT" > "${D}/cmdline"
	fAddPool rpool_t vg_t-lv_rpool_t 1
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rpool_t imported"               fImported rpool_t
}

fCase_stale_hostid_outside_luks(){
	## A disk another running host may have imported. Never forced, and not waited on.
	fAddDm 7 usbpool_part LVM-other sdb1
	fAddPool usbpool usbpool_part 1
	SECONDS=0
	fRun usbpool --timeout 30
	fCheck "exit 1"                         fRc 1
	fCheck "not imported"                   bash -c '! grep -qx usbpool "$1"' _ "${D}/imported"
	fCheck "said it isn't forcing"          fSaidErr "Not forcing 'usbpool'"
	fCheck "never ran -f"                   fNoForce
	fCheck "gave up without waiting"        test "${SECONDS}" -lt 10
}

fCase_stale_hostid_partly_outside(){
	## A mirror with one side inside the container. Forcing would import it degraded.
	fAddDm 7 other_part LVM-other sdb1
	fAddPool rpool_t "vg_t-lv_rpool_t other_part" 1
	fRun --root
	fCheck "exit 1"                         fRc 1
	fCheck "said it isn't forcing"          fSaidErr "Not forcing 'rpool_t'"
	fCheck "never ran -f"                   fNoForce
}

fCase_stale_hostid_no_luks(){
	echo "rd.lvm.lv=vg_t/lv_rpool_t root=ZFS=rpool_t/deb/ROOT" > "${D}/cmdline"
	fAddPool rpool_t vg_t-lv_rpool_t 1
	fRun --root
	fCheck "exit 1"                         fRc 1
	fCheck "never ran -f"                   fNoForce
}

fCase_force_fails_last_error(){
	fAddPool rpool_t vg_t-lv_rpool_t 1
	: > "${D}/force_fails"
	fRun --root --timeout 1
	fCheck "exit 1"                         fRc 1
	fCheck "last error is the forced one"   grep -q "Last error: With -f: cannot import 'rpool_t': I/O error" "${D}/err"
}

fCase_root_rootfstype(){
	echo "rd.luks.name=${luksUuid}=crypt_t rd.lvm.lv=vg_t/lv_rpool_t rootfstype=zfs root=rpool_t/deb/ROOT" > "${D}/cmdline"
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rpool_t imported"               fImported rpool_t
}

fCase_root_quoted(){
	echo "rd.luks.name=${luksUuid}=crypt_t rd.lvm.lv=vg_t/lv_rpool_t \"root=ZFS=rpool_t/deb/ROOT\"" > "${D}/cmdline"
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "rpool_t imported"               fImported rpool_t
	echo "rd.luks.name=${luksUuid}=crypt_t rd.lvm.lv=vg_t/lv_rpool_t root=\"ZFS=rpool_t/deb/ROOT\"" > "${D}/cmdline"
	: > "${D}/imported"
	fRun --root
	fCheck "root=\"ZFS=...\" imported too"  fImported rpool_t
}

fCase_root_not_zfs(){
	echo "root=/dev/sda2 rootfstype=ext4 rd.lvm.lv=vg_t/lv_rpool_t" > "${D}/cmdline"
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "nothing imported"               bash -c '! grep -q "^zpool import" "$1"' _ "${D}/calls"
	fCheck "no LVs touched"                 bash -c '! grep -q "^lvm" "$1"' _ "${D}/calls"
}

fCase_root_autodetect(){
	echo "root=zfs:AUTO" > "${D}/cmdline"
	fRun --root
	fCheck "exit 0"                         fRc 0
	fCheck "left to the stock import"       bash -c '! grep -q "^zpool import" "$1"' _ "${D}/calls"
}

fInNamespace(){
	local -r name="$1"
	D="$2"; export D
	fSetup
	: > "${D}/calls"
	"fCase_${name}" > "${D}/out.log" 2>&1  ||  echo x >> "${D}/failures"
	cat "${D}/out.log"
	[[ ! -e "${D}/failures" ]]
}


## Unit files, read the way systemd reads them ###################################################

fUnitList(){
	## All values of key $2 in [Unit] or [Service] of file $1, space separated. Lists add up over lines,
	## and an empty assignment resets them.
	awk -v key="$2" -F= '
		/^\[/ {sec=$0; next}
		/^[[:space:]]*#/ {next}
		$1 == key { v = substr($0, index($0, "=") + 1); if (v == "") out = ""; else out = out " " v }
		END {print out}' "$1"
}

fInitrdUnit(){ echo "${treeDir}/usr/lib/dracut/modules.d/99tkz-zfs-import/tkz-zfs-import-root.service"; }

fCase_unit_root_before_stock_scan(){
	## The stock scan doesn't wait for LVM, so the unit that does has to go first.
	local -r u="$(fInitrdUnit)"
	local before after
	before=" $(fUnitList "${u}" Before) "; after=" $(fUnitList "${u}" After) "
	[[ "${before}" == *" zfs-import-scan.service "* ]]  ||  { echo "    not ok: Before=zfs-import-scan.service"; return 1; }
	[[ "${after}"  != *" zfs-import-scan.service "* ]]  ||  { echo "    not ok: not After=zfs-import-scan.service"; return 1; }
	[[ "${after}"  == *" cryptsetup.target "* ]]        ||  { echo "    not ok: After=cryptsetup.target"; return 1; }
	return 0
}

fCase_unit_root_timeout(){
	## A hung zpool or lvm call has to end in the emergency shell, not a hang. The script's own
	## default timeout has to fit inside, with room for one slow try.
	local -r u="$(fInitrdUnit)"
	local t sec=0
	t="$(fUnitList "${u}" TimeoutStartSec)"; t="${t##* }"
	case "${t}" in
		*min) sec=$(( ${t%min} * 60 )) ;;
		*s)   sec="${t%s}" ;;
		[0-9]*) sec="${t}" ;;
		*)    echo "    not ok: TimeoutStartSec is finite (it's '${t}')"; return 1 ;;
	esac
	local scriptDefault
	scriptDefault="$(grep -oE 'value=[0-9]+$' "$(fScript)" | head -1 | cut -d= -f2)"
	((sec >= scriptDefault + 60))  ||  { echo "    not ok: TimeoutStartSec (${sec}s) leaves room past the script's ${scriptDefault}s"; return 1; }
	return 0
}

fCase_unit_no_usr_local(){
	## Both units run before the pools' datasets mount, /usr/local included. Every program they run,
	## and the one the dracut module copies in, has to be on the root dataset and in this tree.
	local u key p bad=0
	for u in "${treeDir}/etc/systemd/system/tkz-zfs-import.service" "$(fInitrdUnit)"; do
		for key in ExecStart ExecStop ConditionFileIsExecutable; do
			for p in $(fUnitList "${u}" "${key}"); do
				[[ "${p}" == /* ]]  ||  continue
				[[ "${p}" == /usr/local/* ]]  &&  { echo "    not ok: ${u##*/} ${key} isn't under /usr/local: ${p}"; bad=1; }
				[[ "${u}" == *dracut* ]]  &&  continue  ## Initrd paths come from module-setup.sh.
				[[ -x "${treeDir}${p}" ]]  ||  { echo "    not ok: ${u##*/} ${key} is in the tree: ${p}"; bad=1; }
			done
		done
	done
	local src
	src="$(awk '/inst_script/ {print $2}' "${treeDir}/usr/lib/dracut/modules.d/99tkz-zfs-import/module-setup.sh")"
	[[ "${src}" != /usr/local/* ]]  ||  { echo "    not ok: module-setup.sh copies from outside /usr/local: ${src}"; bad=1; }
	[[ -x "${treeDir}${src}" ]]     ||  { echo "    not ok: module-setup.sh copies a file in the tree: ${src}"; bad=1; }
	return "${bad}"
}


## Outside ########################################################################################

fMain(){
	if [[ "${1:-}" == "--in-ns" ]]; then
		fInNamespace "$2" "$3"
		return
	fi
	command -v unshare &>/dev/null  ||  { echo "unshare isn't installed." >&2; return 1; }
	local -a cases=("$@")
	((${#cases[@]}))  ||  cases=("${allCases[@]}")

	local -r runDir="/tmp/test_tkz_zfs-import_$(date +%Y%m%d-%H%M%S%2N)"
	mkdir "${runDir}"
	local name=""  failed=""
	local -i passCount=0  failCount=0
	for name in "${cases[@]}"; do
		if [[ "${name}" == unit_* ]]; then
			if "fCase_${name}"; then echo "ok   ${name}"; passCount=$((passCount + 1)); else echo "FAIL ${name}"; failCount=$((failCount + 1)); failed+=" ${name}"; fi
			continue
		fi
		mkdir "${runDir}/${name}"
		if unshare -rm --propagation private bash "${BASH_SOURCE[0]}" --in-ns "${name}" "${runDir}/${name}" > "${runDir}/${name}.log" 2>&1; then
			echo "ok   ${name}"; passCount=$((passCount + 1))
		else
			echo "FAIL ${name}  (log: ${runDir}/${name}.log)"; failCount=$((failCount + 1)); failed+=" ${name}"
			grep "not ok" "${runDir}/${name}.log" || true
		fi
	done
	echo "${passCount} passed, ${failCount} failed.${failed:+ Failed:${failed}}"
	if ((failCount == 0)); then
		## Only the dir this run made, and only once nothing is mounted (the namespaces are gone).
		[[ "${runDir}" == /tmp/test_tkz_zfs-import_* && -d "${runDir}" ]]  &&  rm -rf "${runDir}"
		return 0
	fi
	return 1
}

fMain "$@"


##	Copyright © 2026 t00mietum
##	Licensed under The MIT License.
##		https://spdx.org/licenses/MIT.html
##	SPDX-License-Identifier: MIT

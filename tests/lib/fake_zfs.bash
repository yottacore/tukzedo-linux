#!/bin/bash

##	Purpose:
##		- Stand-in for 'zfs' in tests. Datasets are dirs under $FAKE_ZFS_ROOT, and a mount is a real bind
##		  mount, so it only runs inside a private user+mount namespace (see tests/tkz_user_migrate.bash).
##		- Covers what the tkz_* scripts call: list, get, set, inherit, create, destroy, rename, mount,
##		  unmount, load-key, unload-key. Mountpoint and user properties inherit like the real thing.
##		- Every call is appended to $FAKE_ZFS_ROOT/log. A glob per line in $FAKE_ZFS_ROOT/fail makes a
##		  matching call fail, before it changes anything.
##	Copyright and license ...: Toward bottom of this file.

set -euo pipefail

fDie(){ echo "cannot $*" >&2; exit 1; }

[[ -n "${FAKE_ZFS_ROOT:-}" ]]  ||  { echo "fake zfs: FAKE_ZFS_ROOT isn't set." >&2; exit 2; }
## Bind mounts on the real host would be a disaster. In 'unshare -r' the map is '0 <uid> 1'.
read -r nsInside nsOutside _ < /proc/self/uid_map
[[ "${nsInside} ${nsOutside}" != "0 0" ]]  ||  { echo "fake zfs: refusing to run outside a user namespace." >&2; exit 2; }

declare -r Z="${FAKE_ZFS_ROOT}"
mkdir -p "${Z}/ds" "${Z}/data"
echo "$*" >> "${Z}/log"
if [[ -f "${Z}/fail" ]]; then
	while IFS= read -r pattern; do
		[[ -n "${pattern}" ]]  ||  continue
		# shellcheck disable=SC2053  ## The right side is a glob on purpose.
		if [[ "$*" == ${pattern} ]]; then echo "fake zfs: injected failure: zfs $*" >&2; exit 1; fi
	done < "${Z}/fail"
fi

fDir(){ printf '%s/ds/%s' "${Z}" "${1//\//%}"; }
fExists(){ [[ -d "$(fDir "$1")" ]]; }
fNeed(){ fExists "$1"  ||  fDie "open '$1': dataset does not exist"; }
fAll(){
	local d=""
	for d in "${Z}"/ds/*; do
		[[ -d "${d}" ]]  &&  { d="${d##*/}"; echo "${d//%//}"; }
	done | LC_ALL=C sort
	return 0
}
fTree(){ fAll | awk -v n="$1" '$0==n || index($0, n "/")==1'; }  ## Parent first.
fLocal(){ local f; f="$(fDir "$1")/p/$2"; [[ -f "${f}" ]]  &&  cat "${f}"; }
fEncRoot(){
	local n="$1"
	while :; do
		[[ -f "$(fDir "${n}")/key" ]]  &&  { echo "${n}"; return 0; }
		[[ "${n}" == */* ]]  ||  return 1
		n="${n%/*}"
	done
}

## Sets V and S, the value and source 'zfs get' would show.
V="" S=""
fProp(){
	local n="$1"  p="$2"  a=""  r=""
	S="-"
	case "${p}" in
		name)          V="${n}"; return ;;
		guid)          V="$(cat "$(fDir "${n}")/guid")"; return ;;
		mounted)       [[ -f "$(fDir "${n}")/mounted" ]] && V=yes || V=no; return ;;
		encryptionroot) V="$(fEncRoot "${n}" || echo -)"; return ;;
		keystatus)
			if r="$(fEncRoot "${n}")"; then [[ -f "$(fDir "${r}")/keyloaded" ]] && V=available || V=unavailable; else V="-"; fi
			return ;;
		encryption)
			if r="$(fEncRoot "${n}")"; then V="aes-256-gcm"; [[ "${r}" == "${n}" ]] && S=local || S="inherited from ${r}"; else V=off; S=default; fi
			return ;;
		canmount)
			if V="$(fLocal "${n}" canmount)"; then S=local; else V=on; S=default; fi
			return ;;
	esac
	if V="$(fLocal "${n}" "${p}")"; then S=local; return; fi
	a="${n}"
	while [[ "${a}" == */* ]]; do
		a="${a%/*}"
		if V="$(fLocal "${a}" "${p}")"; then
			S="inherited from ${a}"
			[[ "${p}" == mountpoint && "${V}" != none && "${V}" != legacy ]]  &&  V="${V%/}${n#"${a}"}"
			return
		fi
	done
	if [[ "${p}" == mountpoint ]]; then V="/${n}"; S=default; else V="-"; S="-"; fi
}

fTarget(){ fProp "$1" mountpoint; case "${V}" in none|legacy|-) return 1 ;; esac; echo "${V}"; }

fMount(){
	local n="$1"  d=""  t=""
	d="$(fDir "${n}")"
	[[ -f "${d}/mounted" ]]  &&  fDie "mount '${n}': filesystem already mounted"
	fProp "${n}" keystatus; [[ "${V}" != unavailable ]]  ||  fDie "mount '${n}': encryption key not loaded"
	t="$(fTarget "${n}")"  ||  fDie "mount '${n}': legacy or no mountpoint"
	[[ -e "${t}" && ! -d "${t}" ]]  &&  fDie "mount '${n}': mountpoint '${t}' is not a directory"
	mkdir -p "${t}"
	mount --bind "${Z}/data/$(cat "${d}/guid")" "${t}"  ||  fDie "mount '${n}' on '${t}'"
	echo "${t}" > "${d}/mounted"
}

fUnmount(){
	local n="$1"  d=""
	d="$(fDir "${n}")"
	[[ -f "${d}/mounted" ]]  ||  fDie "unmount '${n}': not currently mounted"
	umount "$(cat "${d}/mounted")"  ||  fDie "unmount '${n}': pool or dataset is busy"
	rm -f "${d}/mounted"
}

## Unmounts the mounted part of a tree, runs "$@", then mounts the same names again, parent first.
## $1: tree root; $2: new root name if "$@" renames it, else "".
fAround(){
	local root="$1"  newRoot="$2"  n=""
	shift 2
	local -a was=()
	readarray -t was < <(fTree "${root}" | while read -r n; do [[ -f "$(fDir "${n}")/mounted" ]] && echo "${n}"; done)
	for ((i=${#was[@]}-1; i>=0; i--)); do fUnmount "${was[i]}"; done
	"$@"
	for n in "${was[@]}"; do
		[[ -n "${newRoot}" ]]  &&  n="${newRoot}${n#"${root}"}"
		fTarget "${n}" >/dev/null  &&  fMount "${n}"
	done
	return 0
}

fRenameState(){
	local from="$1"  to="$2"  n=""
	while read -r n; do
		mv -T "$(fDir "${n}")" "$(fDir "${to}${n#"${from}"}")"
	done < <(fTree "${from}" | tac)
}

fSetLocal(){ mkdir -p "$(fDir "$1")/p"; printf '%s' "$3" > "$(fDir "$1")/p/$2"; }
fClearLocal(){ rm -f "$(fDir "$1")/p/$2"; }

fCmdGet(){
	local cols="name,property,value,source"  sources=""  c=""  n=""  p=""
	while [[ "${1:-}" == -* ]]; do
		case "$1" in
			-H) ;;
			-o) cols="$2"; shift ;;
			-s) sources="$2"; shift ;;
			-t) shift ;;
		esac
		shift
	done
	local props="$1"; shift
	local -a names=("$@")
	((${#names[@]}))  ||  readarray -t names < <(fAll)
	for n in "${names[@]}"; do fNeed "${n}"; done
	local -a out=()  propList=()  colList=()
	IFS=, read -r -a propList <<<"${props}"
	IFS=, read -r -a colList <<<"${cols}"
	for n in "${names[@]}"; do
		for p in "${propList[@]}"; do
			fProp "${n}" "${p}"
			[[ -z "${sources}" || ",${sources}," == *",${S},"* ]]  ||  continue
			out=()
			for c in "${colList[@]}"; do
				case "${c}" in
					name) out+=("${n}") ;; property) out+=("${p}") ;; value) out+=("${V}") ;; source) out+=("${S}") ;;
				esac
			done
			(IFS=$'\t'; echo "${out[*]}")
		done
	done
}

fCmdList(){
	local cols="name,used,avail,refer,mountpoint"  recurse=0  c=""  n=""
	while [[ "${1:-}" == -* ]]; do
		case "$1" in
			-H) ;;
			-r) recurse=1 ;;
			-o) cols="$2"; shift ;;
			-t) shift ;;
		esac
		shift
	done
	local -a names=()
	if [[ -n "${1:-}" ]]; then
		fNeed "$1"
		if ((recurse)); then readarray -t names < <(fTree "$1"); else names=("$1"); fi
	else
		readarray -t names < <(fAll)
	fi
	local -a out=()  colList=()
	IFS=, read -r -a colList <<<"${cols}"
	for n in "${names[@]}"; do
		out=()
		for c in "${colList[@]}"; do
			case "${c}" in
				used|avail|refer) out+=("0") ;;
				*) fProp "${n}" "${c}"; out+=("${V}") ;;
			esac
		done
		(IFS=$'\t'; echo "${out[*]}")
	done
}

fCmdCreate(){
	local -a opts=()
	while [[ "${1:-}" == -* ]]; do
		[[ "$1" == "-o" ]]  &&  { opts+=("$2"); shift; }
		shift
	done
	local n="$1"  kv=""  isEnc=0  key=""  guid=""
	fExists "${n}"  &&  fDie "create '${n}': dataset already exists"
	[[ "${n}" != */* ]] || fExists "${n%/*}"  ||  fDie "create '${n}': parent does not exist"
	for kv in "${opts[@]}"; do [[ "${kv}" == keyformat=passphrase ]] && isEnc=1; done
	if ((isEnc)); then
		IFS= read -r key || true
		[[ ${#key} -ge 8 ]]  ||  fDie "create '${n}': passphrase too short"
	fi
	guid="${RANDOM}${RANDOM}${RANDOM}"
	mkdir -p "$(fDir "${n}")/p" "${Z}/data/${guid}"
	echo "${guid}" > "$(fDir "${n}")/guid"
	for kv in "${opts[@]}"; do fSetLocal "${n}" "${kv%%=*}" "${kv#*=}"; done
	if ((isEnc)); then printf '%s' "${key}" > "$(fDir "${n}")/key"; touch "$(fDir "${n}")/keyloaded"; fi
	fProp "${n}" canmount
	if [[ "${V}" == on ]] && fTarget "${n}" >/dev/null; then
		( fMount "${n}" )  ||  fDie "create '${n}': filesystem successfully created, but not mounted"
	fi
	return 0
}

fCmdDestroy(){
	local recurse=0  n=""
	[[ "$1" == "-r" ]]  &&  { recurse=1; shift; }
	fNeed "$1"
	[[ "$(fTree "$1" | wc -l)" -gt 1 && "${recurse}" == 0 ]]  &&  fDie "destroy '$1': filesystem has children"
	while read -r n; do
		[[ -f "$(fDir "${n}")/mounted" ]]  &&  fUnmount "${n}"
	done < <(fTree "$1" | tac)
	while read -r n; do
		rm -rf "${Z}/data/$(cat "$(fDir "${n}")/guid")" "$(fDir "${n}")"
	done < <(fTree "$1" | tac)
}

fCmdLoadKey(){
	local r=""  key=""
	fNeed "$1"
	r="$(fEncRoot "$1")"  ||  fDie "load key for '$1': encryption not enabled"
	[[ "${r}" == "$1" ]]  ||  fDie "load key for '$1': keys must be loaded for encryption root '${r}'"
	[[ -f "$(fDir "${r}")/keyloaded" ]]  &&  fDie "load key for '$1': key already loaded"
	IFS= read -r key || true
	if [[ "${key}" != "$(cat "$(fDir "${r}")/key")" ]]; then echo "Key load error: Incorrect key provided for '$1'." >&2; exit 255; fi
	touch "$(fDir "${r}")/keyloaded"
}

fCmdUnloadKey(){
	local r=""  n=""
	fNeed "$1"
	r="$(fEncRoot "$1")"  ||  fDie "unload key for '$1': encryption not enabled"
	while read -r n; do
		[[ "$(fEncRoot "${n}" || true)" == "${r}" && -f "$(fDir "${n}")/mounted" ]]  &&  fDie "unload key for '$1': '${n}' is busy"
	done < <(fTree "${r}")
	rm -f "$(fDir "${r}")/keyloaded"
}

fMain(){
	local cmd="${1:-}"  kv=""  n=""
	shift || true
	case "${cmd}" in
		get)    fCmdGet "$@" ;;
		list)   fCmdList "$@" ;;
		create) fCmdCreate "$@" ;;
		destroy) fCmdDestroy "$@" ;;
		mount)  fNeed "$1"; fMount "$1" ;;
		unmount|umount)
			## Like 'zfs unmount' on the b28l VM: mounted children go first, then the dataset.
			[[ "${1:-}" == "-f" ]]  &&  shift
			fNeed "$1"
			[[ -f "$(fDir "$1")/mounted" ]]  ||  fDie "unmount '$1': not currently mounted"
			while read -r n; do
				[[ -f "$(fDir "${n}")/mounted" ]]  &&  fUnmount "${n}"
			done < <(fTree "$1" | tac)
			true ;;
		rename)
			fNeed "$1"
			fExists "$2"  &&  fDie "rename to '$2': dataset already exists"
			fExists "${2%/*}"  ||  fDie "rename to '$2': parent does not exist"
			fAround "$1" "$2" fRenameState "$1" "$2" ;;
		set)
			n="${*: -1}"
			fNeed "${n}"
			for kv in "${@:1:$#-1}"; do
				if [[ "${kv%%=*}" == mountpoint ]]; then
					fAround "${n}" "" fSetLocal "${n}" mountpoint "${kv#*=}"
				else
					fSetLocal "${n}" "${kv%%=*}" "${kv#*=}"
				fi
			done ;;
		inherit)
			fNeed "$2"
			[[ "$1" == canmount ]]  &&  fDie "inherit canmount: 'canmount' property cannot be inherited"
			if [[ "$1" == mountpoint ]]; then fAround "$2" "" fClearLocal "$2" mountpoint; else fClearLocal "$2" "$1"; fi ;;
		load-key)   fCmdLoadKey "$@" ;;
		unload-key) fCmdUnloadKey "$@" ;;
		*) echo "fake zfs: unknown command '${cmd}'" >&2; exit 2 ;;
	esac
}

fMain "$@"


##	Copyright © 2026 t00mietum
##	Licensed under The MIT License.
##		https://spdx.org/licenses/MIT.html
##	SPDX-License-Identifier: MIT

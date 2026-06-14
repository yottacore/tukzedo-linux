#!/bin/env bash
#  shellcheck disable=2155  ## 'Declare and assign separately to avoid masking return values.' Cumbersome and unnecessary. For integers it's sometimes required to even come into existence for counters.
## shellcheck disable=2001  ## 'See if you can use ${variable//search/replace} instead.' Complains about good uses of sed.
## shellcheck disable=2002  ## 'Useless use of cat.'
## shellcheck disable=2016  ## 'Expressions don't expand in single quotes, use double quotes for that.' I know, and I often want an explicit '$'.
## shellcheck disable=2034  ## 'variable appears unused.' Complains about valid use of variable indirection (e.g. later use of local -n var=$1)
## shellcheck disable=2046  ## 'Quote to prevent word-splitting.' (OK for integers.)
## shellcheck disable=2086  ## 'Double quote to prevent globbing and word splitting.' (OK for integers.)
## shellcheck disable=2119  ## 'Use foo "$@" if function's $1 should mean script's $1.' Confusing and inapplicable.
## shellcheck disable=2120  ## 'Foo references arguments, but none are ever passed.' Valid function argument overloading.
## shellcheck disable=2128  ## 'Expanding an array without an index only gives the element in the index 0.' False hits on associative arrays.
## shellcheck disable=2143  ## 'Use grep -q instead of echo | grep'
## shellcheck disable=2162  ## 'read without -r will mangle backslashes.'
## shellcheck disable=2178  ## 'Variable was used as an array but is now assigned a string.' False hits on associative arrays with e.g. 'local -n assocArray=$1'.
## shellcheck disable=2181  ## 'Check exit code directly, not indirectly with $?.'
## shellcheck disable=2317  ## 'Can't reach.' (I.e. an 'exit' is used for debugging - and makes an unusable visual mess.)

##	Purpose:
##		- Installs tkz_* scripts from github to local machine.
##		- Warns first if any existing local files are newer.
##		- Install location: /usr/local/sbin
##	Notes:
##		- You don't have to run this installer. You can just copy the files from your closest matching
##		  distribution (e.g. `tukzedo-linux/github/*`) to `/usr/local/sbin`, and mark them executable.
##	History: At bottom of script. (Maintained separately from and/or in addition to, cloud-based version control.)

##	Copyright © 2026 Jim Collier (ID: 1cv◂‡Vᛦ)
##	Licensed under The GNU General Public License v2.0 or later.
##		https://spdx.org/licenses/GPL-2.0-or-later.html
##	SPDX-License-Identifier: GPL-2.0-or-later

set -euo pipefail

## Constants
declare SUDO_CMD="" ; [[ "${UID}" == "0" ]] || SUDO_CMD="sudo" ; readonly SUDO_CMD

## Repo
declare -r FRIENDLY_NAME='Tukzedo Linux'
declare -r TARGET_DIR="/usr/local/sbin"
declare -r GITHUB_URL_DOWNLOAD_PREFIX="https://raw.githubusercontent.com/t00mietum/tukzedo-linux/main/filesystem/debian_13/usr/local/sbin"
declare -r GITHUB_URL_API="https://api.github.com/repos/t00mietum/tukzedo-linux/contents/filesystem/debian_13/usr/local/sbin?ref=main"

## Query GitHub API for list of files to install
echo "[ Querying GitHub for file list... ]"
declare apiResponse=""
apiResponse="$(curl -fsSL "${GITHUB_URL_API}")" || { echo -e "\nERROR: Failed to query GitHub API.\n"; exit 1; }

## Populate array of file names to install
declare -a fileNames=()
while IFS= read -r nextItem; do fileNames+=("${nextItem}"); done < <(echo "${apiResponse}" | grep '"name"' | sed 's/.*"name": *"//;s/".*//' | grep '^tkz_')
[[ ${#fileNames[@]} -gt 0 ]] || { echo -e "\nERROR: No tkz_* files found at GitHub URL.\n"; exit 1; }
readonly fileNames

## Warn if existing files will be overwritten
declare warnExisting=""
[[ -n "$(find "${TARGET_DIR}" -maxdepth 1 -type f -iname 'tkz_*' 2>/dev/null || true)" ]]  &&  warnExisting="  ** WARNING: Existing '${TARGET_DIR}/tkz_*' files will be overwritten with latest dev versions on github."

## Prompt user to continue
userInput=""
echo -e "\nGoing to install runtime scripts for ${FRIENDLY_NAME}:\n"
echo "  - Source URL prefix ......: ${GITHUB_URL_DOWNLOAD_PREFIX}/"
echo "  - API URL ................: ${GITHUB_URL_API}"
echo "  - Install dir ............: ${TARGET_DIR}"
echo "  - Files to install .......: ${fileNames[*]}"
echo "  - Current \$USER ..........: ${USER}"
[[ -n "${SUDO_CMD}" ]]  &&  echo "  - Need to prompt for sudo : Yes"
[[ -z "${warnExisting}" ]]  ||  echo -e "\n${warnExisting}"
echo
read -r -p "Continue? (y|n): " userInput < /dev/tty
[[ "${userInput,,}" == "y" ]] || { echo -e "[ User aborted. ]\n"; exit 1; }

## Prompt for sudo password if needed
if [[ -n "${SUDO_CMD}" ]]; then
	echo -e "\n[ Getting sudo ... ]"
	${SUDO_CMD} echo "[ Sudo got. ]"
fi

## Make target dir
[[ -d "${TARGET_DIR}" ]]  ||  ${SUDO_CMD} mkdir -p "${TARGET_DIR}"

## Download and install
echo
for nextItem in "${fileNames[@]}"; do
	echo "[ Downloading: ${nextItem} ... ]"
	${SUDO_CMD} curl -fsSL -o "${TARGET_DIR}/${nextItem}"  "${GITHUB_URL_DOWNLOAD_PREFIX}/${nextItem}"
	${SUDO_CMD} chmod +x "${TARGET_DIR}/${nextItem}"
done

## Show installed files
echo -e "\nInstalled files:"
${SUDO_CMD} ls -lA --color=always "${TARGET_DIR}"/tkz_* 2>/dev/null || echo "  (No files found.)"

echo -e "\n[ Done. ]\n"




##•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
## History:
##		- 20260601 JC: Created.
##		- 20260714 JC: Get list of files to install from GitHub API, instead of hardcoding in script. Warn if existing files will be overwritten. Prompt user to continue.

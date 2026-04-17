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

##	Purpose: User-specific actions.
##	Copyright and license ...: Toward bottom of this file.
##	History .................: At bottom of this file.


fTest(){ :; }


#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
# Generic script settings and module-loading
#•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

## Error and exit settings
#set  -u  ## Require variable declaration. Stronger than mere linting. But can struggle if functions are in sourced files.
set   -e  #..........................................: Exit on errors. This is inconsistent (made a little better with settings below), so eventually may move to 'set +e' (which is more constant work and mental overhead).
set   -E  #..........................................: Propagate ERR trap settings into functions, command substitutions, and subshells.
set   -o pipefail  #.......: Make sure all stages of piped commands also fail the same.
shopt -s inherit_errexit  #: Propagate 'set -e' ........ into functions, command substitutions, and subshells. Will fail on Bash <4.4.
shopt -s dotglob  #........: Include usually-hidden 'dotfiles' in '*' glob operations - usually desired.
shopt -s globstar  #.......: ** matches more stuff including recursion.

#### Tell user it's harmless but useless to run this by itself, and also not sourced.
#### They 'key' arg1 isn't for security, it's just an unlikely value that signals, "I'm invoking you deliberately.'
declare -i module_loaded_do_init_userspecific=0
if    [[ "${BASH_SOURCE[0]}" == "$0" ]]             ; then echo -e "\nThis script should be invoked via 'source $(basename "${0}")'.\n"; exit 1
else
	module_loaded_do_init_userspecific=1

	## List functions exposed in this module:
	echo -e "\nFunctions in '$(basename "${BASH_SOURCE[0]}")':"
	grep -oP '^(function\s+)?\K[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()' "${BASH_SOURCE[0]}" 2>/dev/null | sort | tr $'\n' '    ' | fold -s -w 80 || true
	echo

	## Load core module
	loadFile="$(dirname "${BASH_SOURCE[0]}")/core.sh"
	if [[ ! -f "${loadFile}" ]]; then  echo -e "\nError in $(basename "${BASH_SOURCE[0]}"): 'core.sh' not found.\n"; return 1
	else                               source  "${loadFile}"  'script_caller_id_57mz3qsniu'
	fi

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

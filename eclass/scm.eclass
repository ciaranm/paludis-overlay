# Copyright 2008 David Leverton <dleverton@exherbo.org>
# Distributed under the terms of the GNU General Public License v2
# Based in part upon subversion.eclass, which is:
#    Copyright 1999-2008 Gentoo Foundation

scm_need_extglob() {
	[[ ${#} -eq 1 ]] || die "scm_need_extglob needs exactly one argument"
	[[ -n $(declare -F ${1}) ]] || die "${1} is not a function"
	eval "_scm_need_extglob_$(declare -f ${1})"
	eval "${1}() {
		local oldextglob=\$(shopt -p extglob)
		shopt -s extglob
		_scm_need_extglob_${1} \"\${@}\"
		local status=\${?}
		\${oldextglob}
		return \${status}
	}"
}

scm_usedeps() {
	[[ ${#} -ge 1 ]] || die "scm_usedeps needs at least one argument"
	local myeapi=$(echo ${EAPI/prefix})
	has ${myeapi:-0} 0 1 && return
	local IFS=,
	local deps="[${*}]"
	[[ ${myeapi:-0} == kdebuild-* ]] && deps=${deps//,/][}
	echo "${deps}"
}

scm_nonfatal() {
	SCM_NONFATAL=1 "${@}"
}

scm_die_unless_nonfatal() {
	[[ -z ${SCM_NONFATAL} ]] && die "${@}"
}

scm_for_each() {
	[[ ${#} -ge 1 ]] || die "scm_for_each needs at least one argument"

	[[ -z ${SCM_NO_PRIMARY_REPOSITORY} ]] && SCM_THIS= "${@}"

	local t active=true
	local -i level=0
	for t in ${SCM_SECONDARY_REPOSITORIES}; do
		if [[ ${t} == *\? ]]; then
			${active} && ! use ${t%\?} && active=false
		elif [[ ${t} == \( ]]; then
			${active} || (( level++ ))
		elif [[ ${t} == \) ]]; then
			if ! ${active}; then
				(( level-- ))
				[[ ${level} -eq 0 ]] && active=true
			fi
		else
			${active} && SCM_THIS=${t} "${@}"
		fi
	done
}

scm_var_name() {
	[[ ${#} -eq 1 ]] || die "scm_var_name needs exactly one argument"
	echo SCM${SCM_THIS:+_${SCM_THIS}}_${1}
}

scm_get_var() {
	[[ ${#} -eq 1 ]] || die "scm_get_var needs exactly one argument"
	local var=$(scm_var_name ${1})
	echo "${!var}"
}

scm_set_var() {
	[[ ${#} -eq 2 ]] || die "scm_set_var needs exactly two arguments"
	printf -v $(scm_var_name ${1}) %s "${2}"
}

scm_modify_var() {
	[[ ${#} -ge 2 ]] || die "scm_modify_var needs at least two arguments"
	local var=${1}
	shift
	scm_set_var ${var} "$("${@}" "$(scm_get_var ${var})")"
}

scm_get_array() {
	[[ ${#} -eq 2 ]] || die "scm_get_array needs exactly two arguments"
	eval "${2}=( \"\${$(scm_var_name ${1})[@]}\" )"
}

scm_set_array() {
	[[ ${#} -ge 1 ]] || die "scm_set_array needs at least one argument"
	local name=${1}
	shift
	eval "$(scm_var_name ${name})=( \"\${@}\" )"
}

scm_call() {
	[[ ${#} -ge 1 ]] || die "scm_call needs at least one argument"
	local func=${1} type=$(scm_get_var TYPE)
	shift
	if [[ -n $(declare -F scm-${type}_do_${func}) ]]; then
		scm-${type}_do_${func} "${@}"
	elif [[ -n $(declare -F scm_do_${func}) ]]; then
		scm_do_${func} "${@}"
	else
		die "bug in scm-${type}.eclass: scm-${type}_do_${func} not defined"
	fi
}

scm_access_checkout() {
	[[ ${#} -ge 1 ]] || die "scm_access_checkout needs at least one argument"
	local dir=$(scm_get_var CHECKOUT_TO)
	local lock=${dir%/*}/.lock-${dir##*/}

	local dir_base=${dir%/*}
	if [[ ! -d ${dir_base} ]]; then
		local dir_addwrite=${dir_base}
		local dir_search=${dir_addwrite%/*}
		while [[ ! -d ${dir_search} ]]; do
			dir_addwrite=${dir_search}
			dir_search=${dir_search%/*}
		done
		(
			addwrite "${dir_addwrite}"
			mkdir -p "${dir_base}"
		) || die "mkdir failed"
	fi

	local SANDBOX_WRITE=${SANDBOX_WRITE}
	addwrite "${dir}"
	addwrite "${lock}"

	local fd
	for fd in {3..9}; do
		[[ -e /dev/fd/${fd} ]] || break
	done
	[[ -e /dev/fd/${fd} ]] && die "can't find free file descriptor"

	eval "
		{
			flock -x \${fd} || die \"flock failed\"
			\"\${@}\"
			local status=\${?}
			:
		} ${fd}>\"\${lock}\" || die \"opening lock file failed\"
	"

	return ${status}
}

scm_do_resolve_externals() {
	:
}

scm_check_timestamp() {
	[[ -e ${1}/${2} && -n $(find "${1}" -maxdepth 1 -name "${2}" \
		-mmin -$((${SCM_MIN_UPDATE_DELAY} * 60)) -print) ]]
}

scm_perform_fetch() {
	local dir=$(scm_get_var CHECKOUT_TO)

	local whynot status
	if [[ -d ${dir} ]]; then
		whynot=$(scm_call appraise)
		status=${?}
		if [[ ${status} -eq 2 ]]; then
			einfo "Not fetching ${SCM_THIS:-primary repository} because the existing checkout is perfect"
			return
		fi
	else
		whynot="${dir} does not exist"
		status=1
	fi

	if [[ -n ${SCM_OFFLINE} ]]; then
		[[ ${status} -ne 0 ]] && die "can't use SCM_OFFLINE for ${SCM_THIS:-primary repository} because ${whynot}"
		einfo "Not fetching ${SCM_THIS:-primary repository} because SCM_OFFLINE is set"
		return
	fi

	if [[ -n ${SCM_MIN_UPDATE_DELAY} ]]; then
		[[ ${SCM_MIN_UPDATE_DELAY} == *[^0123456789]* || ${SCM_MIN_UPDATE_DELAY} -eq 0 ]] \
			&& die "SCM_MIN_UPDATE_DELAY must be a positive integer"
		local branch=$(scm_get_var BRANCH)
		if scm_check_timestamp "${dir}" .scm.eclass.timestamp ||
				{ [[ -n ${branch} ]] && scm_check_timestamp "${dir}" .scm.eclass.timestamp."${branch//\//--}"; }; then
			if [[ ${status} -eq 0 ]]; then
				einfo "Not fetching ${SCM_THIS:-primary repository} because SCM_MIN_UPDATE_DELAY (${SCM_MIN_UPDATE_DELAY}) hours have not passed"
				return
			else
				einfo "Ignoring SCM_MIN_UPDATE_DELAY for ${SCM_THIS:-primary repository} because ${whynot}"
			fi
		fi
	fi

	if [[ ${status} -eq 3 ]]; then
		echo rm -rf "${dir}"
		rm -rf "${dir}"
		[[ -d ${dir} ]] && die "rm failed"
	fi

	if [[ -d ${dir} ]]; then
		scm_call update
	else
		scm_call checkout
	fi

	if [[ -d ${dir} ]]; then
		whynot=$(scm_call appraise)
		[[ ${?} -eq 1 || ${?} -eq 3 ]] && die "${whynot}"
	else
		die "${dir} does not exist"
	fi

	local fetched
	scm_get_array FETCHED_BRANCHES fetched
	if [[ ${#fetched[@]} -gt 0 ]]; then
		fetched=( "${fetched[@]//\//--}" )
		touch "${fetched[@]/#/${dir}/.scm.eclass.timestamp.}" || die "touch failed"
	else
		touch "${dir}/.scm.eclass.timestamp" || die "touch failed"
	fi
}

scm_fetch_one() {
	scm_perform_fetch
	scm_call resolve_externals
}

scm_src_fetch_extra() {
	scm_{for_each,access_checkout,fetch_one}
}

scm_scmrevision_one() {
	local rev=$(scm_call revision)
	[[ -n ${rev} ]] || die "could not determine revision for ${SCM_THIS:-primary repository}"
	SCM_PKG_SCM_REVISION_RESULT+=,${SCM_THIS}=${rev}
}

scm_pkg_scm_revision() {
	local SCM_PKG_SCM_REVISION_RESULT=
	scm_{for_each,access_checkout,scmrevision_one}
	echo ${SCM_PKG_SCM_REVISION_RESULT#,=}
}

scm_do_unpack() {
	echo cp -pPR "$(scm_get_var CHECKOUT_TO)" "$(scm_get_var UNPACK_TO)"
	cp -pPR "$(scm_get_var CHECKOUT_TO)" "$(scm_get_var UNPACK_TO)" || die "cp failed"
}

scm_do_set_actual_vars() {
	local rev=$(scm_call revision)
	[[ -n ${rev} ]] || die "could not determine revision for ${SCM_THIS:-primary repository}"
	scm_set_var ACTUAL_REVISION "${rev}"
}

scm_unpack_one() {
	scm_call resolve_externals

	local whynot
	if [[ -d $(scm_get_var CHECKOUT_TO) ]]; then
		whynot=$(scm_call appraise)
		[[ ${?} -eq 1 || ${?} -eq 3 ]] && die "${whynot}"
	else
		die "$(scm_get_var CHECKOUT_TO) does not exist"
	fi

	local dir=$(scm_get_var UNPACK_TO)
	if [[ -d ${dir} ]]; then
		rmdir "${dir}" || die "rmdir failed"
	else
		mkdir -p "${dir%/*}" || die mkdir "failed"
	fi

	scm_call unpack
	rm -f "${dir}/.scm.eclass.timestamp"{,.*}
	scm_call set_actual_vars
}

scm_src_unpack() {
	scm_src_fetch_extra

	scm_{for_each,access_checkout,unpack_one}
	SCM_IS_BUILT=1
}

scm_do_info() {
	:
}

scm_pkg_info() {
	[[ -n ${SCM_IS_BUILT} ]] && scm_{for_each,call} info
}

scm_trim_slashes() {
	local scheme= leading= trailing=
	while [[ ${#} -gt 0 && ${1} == -* ]]; do
		case ${1} in
			-scheme)   scheme=1	  ;;
			-leading)  leading=1  ;;
			-trailing) trailing=1 ;;
			*) die "scm_trim_slashes: unrecognised switch ${1}"
		esac
		shift
	done

	[[ ${#} -eq 1 ]] || die "scm_trim_slashes needs exactly one argument besides switches"
	local value=${1}

	local myscheme=
	if [[ -n ${scheme} && ${value} == *://* ]]; then
		myscheme=${value%%://*}://
		value=${value#*://}
	fi

	value=${value//+(\/)/\/}
	[[ -n ${leading}  ]] && value=${value#/}
	[[ -n ${trailing} ]] && value=${value%/}

	echo "${myscheme}${value}"
}
scm_need_extglob scm_trim_slashes

scm_do_check_vars() {
	:
}

scm_global_stuff() {
	if [[ -z $(scm_get_var TYPE) ]]; then
		if [[ -n ${SCM_THIS} ]]; then
			scm_set_var TYPE ${SCM_TYPE}
		else
			die "$(scm_var_name TYPE) must be set"
		fi
	fi
	inherit scm-$(scm_get_var TYPE)

	[[ -z $(scm_get_var REPOSITORY) ]] \
		&& die "$(scm_var_name REPOSITORY) must be set"

	local checkout_to=$(scm_get_var CHECKOUT_TO)
	[[ -z ${checkout_to} ]] && checkout_to=${SCM_THIS:-${PN}}
	[[ ${checkout_to} == /* ]] || checkout_to=${SCM_HOME}/${checkout_to}
	scm_set_var CHECKOUT_TO "$(scm_trim_slashes -trailing "${checkout_to}")"

	local unpack_to=$(scm_get_var UNPACK_TO)
	[[ -z ${unpack_to} ]] && unpack_to=${WORKDIR}/${SCM_THIS:-${P}}
	scm_set_var UNPACK_TO "$(scm_trim_slashes -trailing "${unpack_to}")"

	scm_call check_vars

	DEPEND+=" $(scm_call dependencies)"
}

SCM_HOME=${PORTAGE_ACTUAL_DISTDIR-${DISTDIR}}/scm
scm_finalise() {
	DEPEND+=" >=sys-apps/util-linux-2.13_pre2"

	[[ -z ${SCM_NO_PRIMARY_REPOSITORY} ]] && SCM_THIS= scm_global_stuff

	local t
	for t in ${SCM_SECONDARY_REPOSITORIES}; do
		if [[ ${t} == *\? || ${t} == \( || ${t} == \) ]]; then
			DEPEND+=" ${t}"
		else
			SCM_THIS=${t} scm_global_stuff
		fi
	done
}
[[ -z ${SCM_NO_AUTOMATIC_FINALISE} ]] && scm_finalise

#EXPORT_FUNCTIONS src_fetch_extra pkg_scm_revision src_unpack pkg_info
EXPORT_FUNCTIONS src_unpack pkg_info


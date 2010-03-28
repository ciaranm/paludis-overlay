# Copyright 2008 David Leverton <dleverton@exherbo.org>
# Distributed under the terms of the GNU General Public License v2
# Based in part upon git.exlib, which is:
#    Copyright 2008 Fernando J. Pereda
#    Based upon 'git.eclass' which is:
#       Copyright 1999-2007 Gentoo Foundation

if [[ -z ${SCM_TYPE} ]]; then
	SCM_TYPE=git
	inherit scm
fi

scm-git_do_dependencies() {
	local git='>=dev-vcs/git-1.6.0'
	if [[ $(scm_get_var REPOSITORY) == https://* ]]; then
		echo "${git}$(scm_usedeps curl) net-misc/curl$(scm_usedeps ssl)"
	elif [[ $(scm_get_var REPOSITORY) == http://* || $(scm_get_var REPOSITORY) == ftp://* ]]; then
		echo "${git}$(scm_usedeps curl)"
	elif [[ $(scm_get_var REPOSITORY) == rsync://* ]]; then
		echo "${git} net-misc/rsync"
	elif [[ $(scm_get_var REPOSITORY) == ssh://* ]] ||
			[[ $(scm_get_var REPOSITORY) != *://* && $(scm_get_var REPOSITORY) == *:* ]]; then
		echo "${git} net-misc/openssh"
	else
		echo "${git}"
	fi

	if [[ -n $(scm_get_var TAG) ]]; then
		local keys
		scm_get_array GIT_TAG_SIGNING_KEYS keys
		[[ ${#keys[@]} -gt 0 ]] && echo app-crypt/gnupg
	fi
}

scm-git_do_check_vars() {
	[[ -n $(scm_get_var TAG) && -n $(scm_get_var REVISION) ]] \
		&& die "for git, $(scm_var_name TAG) must not be set at the same time as $(scm_var_name REVISION)"
	[[ -z $(scm_get_var BRANCH) && -z $(scm_get_var REVISION) &&
			-z $(scm_get_var TAG) ]] && scm_set_var BRANCH master
	local rev=$(scm_get_var REVISION)
	[[ -n ${rev} ]] && [[ ${rev} == *[^0123456789abcdef]* || ${#rev} -ne 40 ]] \
		&& die "for git, $(scm_var_name REVISION) must be a 40-character lowercase hexadecimal SHA-1 sum"
	[[ -n $(scm_get_var SUBPATH) ]] && die "for git, $(scm_var_name SUBPATH) must not be set"

	scm_modify_var REPOSITORY scm_trim_slashes -scheme -trailing
}

scm-git_git() {
	local echo=echo
	if [[ ${1} == -q ]]; then
		shift
		echo=:
	fi

	local need_git_dir=yes global=( )
	while [[ ${#} -gt 0 && ${1} == -* ]]; do
		global+=( "${1}" )
		[[ ${1} == --git-dir=* ]] && need_git_dir=
		shift
	done
	[[ ${1} != clone && -n ${need_git_dir} ]] && global+=( --git-dir="$(scm_get_var CHECKOUT_TO)" )

	${echo} git "${global[@]}" "${@}"
	GIT_PAGER=cat git "${global[@]}" "${@}" || scm_die_unless_nonfatal "git ${1} failed"
}

scm-git_do_appraise() {
	local dir=$(scm_get_var CHECKOUT_TO)

	if ! scm_nonfatal scm-git_git -q rev-parse 2>/dev/null; then
		echo "${dir} is not a git checkout"
		return 3
	fi

	if [[ -n $(scm_get_var REVISION) ]]; then
		if [[ -z $(scm_nonfatal scm-git_git -q cat-file -t $(scm_get_var REVISION) 2>/dev/null) ]]; then
			echo "$(scm_get_var REVISION) is not present in ${dir}"
			return 1
		elif [[ $(scm-git_git -q cat-file -t $(scm_get_var REVISION)) == commit ]]; then
			if [[ -n $(scm_get_var BRANCH) ]] && ! scm-git_git -q rev-list "refs/heads/$(scm_get_var BRANCH)" \
					| grep -Fx $(scm_get_var REVISION) >/dev/null; then
				echo "revision $(scm_get_var REVISION) is not part of branch $(scm_get_var BRANCH) of ${dir}"
				return 1
			fi
			return 2
		else
			die "$(scm_get_var REVISION) is not a commit in ${dir}"
		fi
	fi

	local origin=$(scm-git_git -q config remote.origin.url)
	[[ -n ${origin} ]] || die "could not determine origin URL for ${dir}"
	if [[ ${origin} != $(scm_get_var REPOSITORY) ]]; then
		echo "${dir} is a clone of ${origin}, but wanted $(scm_get_var REPOSITORY)"
		return 1
	fi

	if [[ -n $(scm_get_var TAG) ]]; then
		if [[ -n $(scm-git_git -q for-each-ref "refs/tags/$(scm_get_var TAG)") ]]; then
			if [[ -n $(scm_get_var BRANCH) ]] && ! scm-git_git -q rev-list "refs/heads/$(scm_get_var BRANCH)" \
					| grep -Fx $(scm-git_git -q rev-parse "refs/tags/$(scm_get_var TAG)") >/dev/null; then
				echo "tag $(scm_get_var TAG) is not part of branch $(scm_get_var BRANCH) of ${dir}"
				return 1
			fi

			local keys
			scm_get_array GIT_TAG_SIGNING_KEYS keys
			if [[ ${#keys[@]} -gt 0 ]]; then
				local gpghome=$(mktemp -d -p "${T}" gpg-XXXXXX)
				[[ -n ${gpghome} ]] || die "mktemp failed"

				cat >"${gpghome}/gpg" <<-EOF
					#! /usr/bin/env bash
					$(HOME=${gpghome} declare -p HOME)
					$(gpg=$(type -P gpg); declare -p gpg)
					errors=\$("\${gpg}" --keyserver-options no-auto-key-retrieve "\${@}" 2>&1 >/dev/null) && exit
					status=\${?}
					echo "\${errors}" >&2
					exit \${status}
				EOF
				[[ ${?} -eq 0 ]] || die "create gpg wrapper failed"
				chmod +x "${gpghome}/gpg" || die "chmod +x gpg wrapper failed"

				PATH=${gpghome}:${PATH} gpg --import "${keys[@]}" || die "gpg --import ${keys[*]} failed"
				PATH=${gpghome}:${PATH} scm-git_git -q verify-tag "$(scm_get_var TAG)" >/dev/null
			fi

			return 2
		else
			echo "${dir} does not contain the tag $(scm_get_var TAG)"
			return 1
		fi
	fi

	if [[ -n $(scm_get_var BRANCH) && -z $(scm-git_git -q for-each-ref "refs/heads/$(scm_get_var BRANCH)") ]]; then
		echo "${dir} does not contain the branch $(scm_get_var BRANCH)"
		return 1
	fi

	return 0
}

scm-git_do_checkout() {
	scm-git_git clone --bare "$(scm_get_var REPOSITORY)" "$(scm_get_var CHECKOUT_TO)"
	scm-git_git config remote.origin.url "$(scm_get_var REPOSITORY)"
	scm-git_git gc --auto
}

scm-git_do_update() {
	local old_origin=$(scm-git_git -q config remote.origin.url)
	[[ -n ${old_origin} ]] || die "could not determine origin URL for $(scm_get_var CHECKOUT_TO)"
	if [[ ${old_origin} != $(scm_get_var REPOSITORY) ]]; then
		scm-git_git config remote.origin.url "$(scm_get_var REPOSITORY)"
		eval "$(scm-git_git -q for-each-ref --shell --format "scm-git_git update-ref -d %(refname)" refs/{heads,tags}/\*)"
	fi

	local branch=$(scm_get_var BRANCH)
	scm-git_git fetch -f -u origin "refs/heads/${branch:-*}:refs/heads/${branch:-*}"
	scm-git_git gc --auto
	[[ -n ${branch} ]] && scm_set_array FETCHED_BRANCHES "${branch}"
}

scm-git_do_revision() {
	scm-git_git -q rev-parse $(
		if [[ -n $(scm_get_var TAG) ]]; then
			echo refs/tags/$(scm_get_var TAG)
		elif [[ -n $(scm_get_var REVISION) ]]; then
			scm_get_var REVISION
		else
			echo refs/heads/$(scm_get_var BRANCH)
		fi)
}

scm-git_do_unpack() {
	scm-git_git clone -s -n "$(scm_get_var CHECKOUT_TO)" "$(scm_get_var UNPACK_TO)"
	scm-git_git --git-dir="$(scm_get_var UNPACK_TO)"/.git --work-tree="$(scm_get_var UNPACK_TO)" checkout -f $(
		if [[ -n $(scm_get_var TAG) ]]; then
			echo refs/tags/$(scm_get_var TAG)
		elif [[ -n $(scm_get_var REVISION) ]]; then
			scm_get_var REVISION
		else
			[[ -n $(scm-git_git -q --git-dir="$(scm_get_var UNPACK_TO)"/.git for-each-ref "refs/heads/$(scm_get_var BRANCH)") ]] \
				|| echo -b $(scm_get_var BRANCH) refs/remotes/origin/$(scm_get_var BRANCH)
		fi) --
}


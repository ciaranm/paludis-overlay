# Copyright 1999-2007 Ciaran McCreesh
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="paludis-1"

inherit bash-completion-r1 user

DESCRIPTION="paludis, the other package mangler"
HOMEPAGE="http://paludis.exherbo.org/"
SRC_URI="http://paludis.exherbo.org/download/${P}.tar.bz2"

RUBY_VERSIONS=( 1.9:ruby19 2.0:ruby20 2.1:ruby21 2.2:ruby22 )

IUSE="doc portage pink python-bindings ruby-bindings search-index vim-syntax xml zsh-completion pbins ${RUBY_VERSIONS[*]/#*:/ruby_targets_}"
LICENSE="GPL-2 vim-syntax? ( vim )"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~hppa ~ppc ~sparc ~x86"

COMMON_DEPEND="
	>=app-admin/eselect-1.2.13
	>=app-shells/bash-3.2
	dev-libs/libpcre[cxx]
	ruby-bindings? ( $(
		for ruby in ${RUBY_VERSIONS[@]}; do
			echo "ruby_targets_${ruby#*:}? ( dev-lang/ruby:${ruby%:*} )"
		done
	) )
	python-bindings? ( >=dev-lang/python-2.6:= >=dev-libs/boost-1.41.0[python] )
	xml? ( >=dev-libs/libxml2-2.6 )
	search-index? ( dev-db/sqlite:3 )
	pbins? ( >=app-arch/libarchive-3.1.2[-xattr] )
	sys-apps/file"

DEPEND="${COMMON_DEPEND}
	>=app-text/asciidoc-8.6.3
	app-text/xmlto
	app-text/htmltidy
	doc? (
		|| ( >=app-doc/doxygen-1.5.3 <=app-doc/doxygen-1.5.1 )
		media-gfx/imagemagick
		python-bindings? ( dev-python/sphinx )
		ruby-bindings? ( dev-ruby/syntax$(
			for ruby in ${RUBY_VERSIONS[@]}; do
				echo -n "[ruby_targets_${ruby#*:}?]"
			done
		) )
	)
	virtual/pkgconfig
	>=dev-cpp/gtest-1.6.0-r1"

RDEPEND="${COMMON_DEPEND}
	sys-apps/sandbox"

# Keep syntax as a PDEPEND. It avoids issues when Paludis is used as the
# default virtual/portage provider.
PDEPEND="
	vim-syntax? ( >=app-editors/vim-core-7 )
	app-eselect/eselect-package-manager"

check_ruby_targets() {
	if useq ruby-bindings; then
		local nruby=0 ruby
		for ruby in ${RUBY_VERSIONS[@]}; do
			useq ruby_targets_${ruby#*:} && (( ++nruby ))
		done
		[[ ${nruby} -eq 1 ]] || die "exactly one RUBY_TARGETS flag must be set if USE=ruby-bindings"
	fi
}

create-paludis-user() {
	enewgroup "paludisbuild"
	enewuser "paludisbuild" -1 -1 "/var/tmp/paludis" "paludisbuild,tty"
}

pkg_pretend() {
	if id paludisbuild >/dev/null 2>/dev/null ; then
		if ! groups paludisbuild | grep --quiet '\<tty\>' ; then
			ewarn "The 'paludisbuild' user is now expected to be a member of the"
			ewarn "'tty' group. You should add the user to this group before"
			ewarn "upgrading Paludis."
		fi
	fi
	check_ruby_targets
}

pkg_setup() {
	check_ruby_targets
	create-paludis-user

	# 'paludis' tries to exec() itself after an upgrade
	if [[ "${PKGMANAGER}" == paludis-0.[012345]* ]] && [[ -z "${CAVE}" ]] ; then
		eerror "The 'paludis' client has been removed in Paludis 0.60. You must use"
		eerror "'cave' to upgrade."
		die "Can't use 'paludis' to upgrade Paludis"
	fi
}

src_compile() {
	local repositories=`echo default unavailable unpackaged | tr -s \  ,`
	local environments=`echo default $(usev portage ) | tr -s \  ,`
	econf \
		$(use_enable doc doxygen ) \
		$(use_enable pink ) \
		$(use_enable ruby-bindings ruby ) \
		$(useq ruby-bindings && for ruby in ${RUBY_VERSIONS[@]}; do
			useq ruby_targets_${ruby#*:} && echo --with-ruby-version=${ruby%:*}
		done ) \
		$(useq ruby-bindings && useq doc && echo --enable-ruby-doc ) \
		$(use_enable python-bindings python ) \
		$(useq python-bindings && useq doc && echo --enable-python-doc ) \
		$(use_enable vim-syntax vim ) \
		$(use_enable xml ) \
		$(use_enable search-index ) \
		$(use_enable pbins ) \
		--with-vim-install-dir=/usr/share/vim/vimfiles \
		--with-repositories=${repositories} \
		--with-environments=${environments} \
		|| die "econf failed"

	emake || die "emake failed"
}

src_install() {
	emake DESTDIR="${D}" install || die "install failed"
	dodoc AUTHORS README NEWS

	dobashcomp bash-completion/cave || die "dobashcomp failed"

	if use zsh-completion ; then
		insinto /usr/share/zsh/site-functions
		doins zsh-completion/_cave
	fi
}

src_test() {
	# Work around Portage bugs
	export PALUDIS_DO_NOTHING_SANDBOXY="portage sucks"
	export BASH_ENV=/dev/null

	if [[ `id -u` == 0 ]] ; then
		# hate
		export PALUDIS_REDUCED_UID=0
		export PALUDIS_REDUCED_GID=0
	fi

	if ! emake check ; then
		eerror "Tests failed. Looking for files for you to add to your bug report..."
		find "${S}" -type f -name '*.epicfail' -or -name '*.log' | while read a ; do
			eerror "    $a"
		done
		die "Make check failed"
	fi
}

pkg_postinst() {
	pm_is_paludis=false
	if [[ -f ${ROOT}/etc/env.d/50package-manager ]] ; then
		pm_is_paludis=$( source ${ROOT}/etc/env.d/50package-manager ; [[ ${PACKAGE_MANAGER} == paludis ]] && echo true || echo false )
	fi

	if ! $pm_is_paludis ; then
		elog "If you are using paludis or cave as your primary package manager,"
		elog "you should consider running:"
		elog "    eselect package-manager set paludis"
	fi
}

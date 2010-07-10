# Copyright 1999-2007 Ciaran McCreesh
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="paludis-1"

inherit bash-completion eutils

DESCRIPTION="paludis, the other package mangler"
HOMEPAGE="http://paludis.pioto.org/"
SRC_URI="http://paludis.pioto.org/download/${P}.tar.bz2"

IUSE="doc portage pink python-bindings ruby-bindings vim-syntax visibility xml zsh-completion"
LICENSE="GPL-2 vim-syntax? ( vim )"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~hppa ~ppc ~sparc ~x86"

COMMON_DEPEND="
	>=app-admin/eselect-1.2_rc1
	>=app-shells/bash-3.2
	dev-libs/libpcre[cxx]
	ruby-bindings? ( >=dev-lang/ruby-1.8 )
	python-bindings? ( >=dev-lang/python-2.6:= >=dev-libs/boost-1.41.0[python] )
	xml? ( >=dev-libs/libxml2-2.6 )"

DEPEND="${COMMON_DEPEND}
	doc? (
		|| ( >=app-doc/doxygen-1.5.3 <=app-doc/doxygen-1.5.1 )
		media-gfx/imagemagick
		python-bindings? ( dev-python/epydoc dev-python/pygments )
		ruby-bindings? ( dev-ruby/syntax dev-ruby/allison )
	)
	dev-util/pkgconfig"

RDEPEND="${COMMON_DEPEND}
	sys-apps/sandbox"

# Keep syntax as a PDEPEND. It avoids issues when Paludis is used as the
# default virtual/portage provider.
PDEPEND="
	vim-syntax? ( >=app-editors/vim-core-7 )"

PROVIDE="virtual/portage"

create-paludis-user() {
	enewgroup "paludisbuild"
	enewuser "paludisbuild" -1 -1 "/var/tmp/paludis" "paludisbuild"
}

pkg_setup() {
	create-paludis-user
}

src_compile() {
	local repositories=`echo default unavailable unpackaged $(usev cran ) $(usev gems ) | tr -s \  ,`
	local clients=`echo default accerso adjutrix appareo cave importare inquisitio instruo paludis reconcilio | tr -s \  ,`
	local environments=`echo default $(usev portage ) | tr -s \  ,`
	econf \
		$(use_enable doc doxygen ) \
		$(use_enable pink ) \
		$(use_enable ruby-bindings ruby ) \
		$(useq ruby-bindings && useq doc && echo --enable-ruby-doc ) \
		$(use_enable python-bindings python ) \
		$(useq python-bindings && useq doc && echo --enable-python-doc ) \
		$(use_enable vim-syntax vim ) \
		$(use_enable visibility ) \
		$(use_enable xml ) \
		--with-vim-install-dir=/usr/share/vim/vimfiles \
		--with-repositories=${repositories} \
		--with-clients=${clients} \
		--with-environments=${environments} \
		|| die "econf failed"

	emake || die "emake failed"
}

src_install() {
	emake DESTDIR="${D}" install || die "install failed"
	dodoc AUTHORS README ChangeLog NEWS

	BASHCOMPLETION_NAME="adjutrix" dobashcompletion bash-completion/adjutrix
	BASHCOMPLETION_NAME="paludis" dobashcompletion bash-completion/paludis
	BASHCOMPLETION_NAME="accerso" dobashcompletion bash-completion/accerso
	BASHCOMPLETION_NAME="importare" dobashcompletion bash-completion/importare
	BASHCOMPLETION_NAME="instruo" dobashcompletion bash-completion/instruo
	BASHCOMPLETION_NAME="reconcilio" dobashcompletion bash-completion/reconcilio
	BASHCOMPLETION_NAME="inquisitio" dobashcompletion bash-completion/inquisitio
	BASHCOMPLETION_NAME="cave" dobashcompletion bash-completion/cave

	if use zsh-completion ; then
		insinto /usr/share/zsh/site-functions
		doins zsh-completion/_paludis
		doins zsh-completion/_adjutrix
		doins zsh-completion/_importare
		doins zsh-completion/_reconcilio
		doins zsh-completion/_inquisitio
		doins zsh-completion/_paludis_packages
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


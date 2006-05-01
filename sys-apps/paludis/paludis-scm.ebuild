# Copyright 1999-2006 Ciaran McCreesh
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit subversion

DESCRIPTION="paludis, the other package mangler"
HOMEPAGE="http://paludis.berlios.de/"
SRC_URI=""

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~mips ~x86"
IUSE="doc"

DEPEND="
	dev-cpp/libebt
	>=app-shells/bash-3
	=sys-devel/autoconf-2.59*
	=sys-devel/automake-1.9*
	doc? ( app-doc/doxygen )"

RDEPEND="
	>=app-admin/eselect-1.0.2
	>=app-shells/bash-3
	net-misc/wget
	net-misc/rsync
	!mips? ( sys-apps/sandbox )"

PROVIDE="virtual/portage"

ESVN_REPO_URI="svn://svn.berlios.de/paludis/trunk"
ESVN_BOOTSTRAP="./autogen.bash"

src_compile() {
	econf --disable-qa \
		$(use_enable doc doxygen ) \
		$(use_enable !mips sandbox ) \
		|| die "econf failed"

	emake || die "emake failed"
	if use doc ; then
		make doxygen || die "make doxygen failed"
	fi
}

src_install() {
	make DESTDIR="${D}" install || die "install failed"
	dodoc AUTHORS README ChangeLog

	if use doc ; then
		dohtml -r doc/html/
	fi
}

src_test() {
	emake check || die "Make check failed"
}


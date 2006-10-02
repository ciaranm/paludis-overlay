# Copyright 1999-2006 Ciaran McCreesh
# Distributed under the terms of the GNU General Public License v2
# $Header: $

DESCRIPTION="paludis, the other package mangler"
HOMEPAGE="http://paludis.berlios.de/"
SRC_URI="http://download.berlios.de/paludis/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~hppa ~mips ~ppc ~sparc ~x86"
IUSE="doc pink selinux qa"

DEPEND="
	dev-cpp/libebt
	dev-cpp/libwrapiter
	>=app-shells/bash-3
	>=sys-devel/autoconf-2.59
	=sys-devel/automake-1.9*
	doc? ( app-doc/doxygen )
	selinux? ( sys-libs/libselinux )
	qa? ( dev-libs/pcre++ >=dev-libs/libxml2-2.6  app-crypt/gnupg )
	dev-util/pkgconfig"

RDEPEND="
	>=app-admin/eselect-1.0.2
	>=app-shells/bash-3
	net-misc/wget
	net-misc/rsync
	qa? ( dev-libs/pcre++ >=dev-libs/libxml2-2.6 app-crypt/gnupg )
	!mips? ( sys-apps/sandbox )
	selinux? ( sys-libs/libselinux )"

PROVIDE="virtual/portage"

src_compile() {
	econf \
		$(use_enable doc doxygen ) \
		$(use_enable !mips sandbox ) \
		$(use_enable pink) \
		$(use_enable selinux) \
		$(use_enable qa) \
		|| die "econf failed"

	emake || die "emake failed"
	if use doc ; then
		make doxygen || die "make doxygen failed"
	fi
}

src_install() {
	make DESTDIR="${D}" install || die "install failed"
	dodoc AUTHORS README ChangeLog NEWS

	if use doc ; then
		dohtml -r -V doc/html/
	fi
}

src_test() {
	# Work around Portage bug
	addwrite /var/cache
	emake check || die "Make check failed"
}

pkg_postinst() {
	echo
	einfo "Before using Paludis and before reporting issues, you should read:"
	einfo "    http://paludis.berlios.de/KnownIssues.html"
	echo
}


# Copyright 1999-2006 Ciaran McCreesh
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="paludis-1"

DESCRIPTION="C++ template library for avoiding exposing privates via iterators"
HOMEPAGE="http://libwrapiter.pioto.org/"
SRC_URI="http://libwrapiter.pioto.org/download/${P}.tar.bz2"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~sparc ~x86"
IUSE="doc"

DEPEND="
	sys-devel/autoconf:2.5
	sys-devel/automake:1.10
	doc? ( app-doc/doxygen )"

RDEPEND=""

src_compile() {
	econf \
		$(use_enable doc doxygen ) \
		|| die "econf failed"

	emake || die "emake failed"
}

src_install() {
	make DESTDIR="${D}" install || die "install failed"
	dodoc AUTHORS README ChangeLog NEWS
}

src_test() {
	emake check || die "Make check failed"
}


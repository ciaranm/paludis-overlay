# Copyright 2009, 2010, 2011, 2012, 2013 Ali Polatel <alip@exherbo.org>
# Copyright 2009, 2014 David Leverton <levertond@googlemail.com>
# Distributed under the terms of the GNU General Public License v2

EAPI=paludis-1

WANT_AUTOCONF=2.5
WANT_AUTOMAKE=1.13
inherit eutils linux-info autotools

DESCRIPTION="Sydbox the other sandbox"
HOMEPAGE="http://git.exherbo.org/sydbox-1.git"
SRC_URI="http://dev.exherbo.org/distfiles/${PN}/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="doc ipv6 seccomp"

DEPEND="dev-libs/libxslt
	virtual/pkgconfig
	doc? ( app-doc/doxygen )
	seccomp? ( >=sys-kernel/linux-headers-3.5 )"
RDEPEND=""

AT_M4DIR="m4"

pkg_pretend() {
	if kernel_is 2 6 && kernel_is lt 2 6 29; then
		ewarn "sydbox works slow on kernels <2.6.29 due to a ptrace bug!"
		ewarn "See http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commit;h=53da1d9456fe7f87a920a78fdbdcf1225d197cb7 for the fix!"
	fi
}

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${FILESDIR}"/0001-disable-utimensat-for-now.patch
	eautoreconf
}

src_compile() {
	econf \
		--docdir=/usr/share/doc/${PF} \
		$(use_enable doc doxygen) \
		$(use_enable ipv6) \
		$(use_enable seccomp)
	emake || die "emake failed"
}

src_test() {
	if [[ -n ${SANDBOX_ACTIVE} ]]; then
		ewarn "Tests fail under sandbox, skipping..."
	else
		emake check || die "emake check failed"
	fi
}

src_install() {
	emake DESTDIR="${D}" install || die "emake install failed"
}


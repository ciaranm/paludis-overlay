# Copyright 2009 Ali Polatel <polatel@gmail.com>
# Copyright 2009 David Leverton <levertond@googlemail.com>
# Distributed under the terms of the GNU General Public License v2

EAPI=paludis-1

inherit linux-info

DESCRIPTION="Sydbox the other sandbox"
HOMEPAGE="http://projects.0x90.dk/wiki/sydbox"
SRC_URI="http://dev.exherbo.org/~alip/${PN}/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=">=dev-libs/glib-2.18:2"
DEPEND="${RDEPEND}
	>=dev-util/pkgconfig-0.20.0"
#	>=dev-libs/check-0.9.4

RESTRICT="test" # needs newer Perl

pkg_pretend() {
	if kernel_is 2 6 && kernel_is lt 2 6 29; then
		ewarn "sydbox works slow on kernels <2.6.29 due to a ptrace bug!"
		ewarn "See http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commit;h=53da1d9456fe7f87a920a78fdbdcf1225d197cb7 for the fix!"
	fi
}

src_test() {
	if [[ -n ${SANDBOX_ACTIVE} ]]; then
		ewarn "Tests fail under sandbox, skipping..."
	else
		emake -j1 check || die "emake check failed"
	fi
}

src_install() {
	emake DESTDIR="${D}" install || die "emake install failed"
	dodoc README.mkd NEWS.mkd TODO.mkd AUTHORS.mkd || die "dodoc failed"
	doman data/sydbox.1 || die "doman failed"
}


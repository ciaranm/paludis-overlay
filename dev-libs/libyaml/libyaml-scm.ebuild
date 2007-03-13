# Copyright 1999-2006 Ciaran McCreesh
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit subversion

EAPI="paludis-1"

DESCRIPTION="LibYAML, a YAML 1.1 Parser and Emitter in C"
HOMEPAGE="http://pyyaml.org/wiki/LibYAML"
SRC_URI=""

LICENSE="MIT"
SLOT="0"
KEYWORDS="~x86"
IUSE="doc"

DEPEND="
	sys-devel/automake:1.9
	sys-devel/autoconf:2.5
	doc? ( app-doc/doxygen )"

RDEPEND=""

ESVN_REPO_URI="http://svn.pyyaml.org/libyaml/trunk"
ESVN_BOOTSTRAP="./bootstrap"

src_compile() {
	econf || die "econf failed"
	emake || die "emake failed"

	if use doc ; then
		sed -i \
			-e 's,\$(top_\(build\|src\)dir),.,g' \
			-e 's,\$(PACKAGE),yaml,g' \
			doc/doxygen.cfg

		doxygen doc/doxygen.cfg
	fi
}

src_install() {
	emake DESTDIR="${D}" install || die "install failed"
	dodoc README announcement.msg

	if use doc ; then
		dohtml -r doc/html/
	fi
}


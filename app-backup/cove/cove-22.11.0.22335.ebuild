# Copyright 2023 Mike Gelfand
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs unpacker

MY_REV="c03d64bda8-7773"
MY_PN="mxb"
MY_PV="${PV}-${MY_REV}"
MY_P="${MY_PN}-${MY_PV}"

MY_PV_DIR="$(ver_cut 1-3)/$(ver_cut 4)-${MY_REV}"
MY_SRC_URI_BASE="https://www.iaso.com/download/release/${MY_PV_DIR}/${MY_PN}-${PV}"

DESCRIPTION="Backup and recovery software focused on helping keep businesses running"
HOMEPAGE="https://www.n-able.com/products/cove-data-protection"
SRC_URI="
	x86? ( ${MY_SRC_URI_BASE}-linux-i686.run -> ${MY_P}-linux-i686.run )
	amd64? ( ${MY_SRC_URI_BASE}-linux-x86_64.run -> ${MY_P}-linux-x86_64.run )
	"

LICENSE=""
SLOT="0"
KEYWORDS="amd64 amd64-linux x86 x86-linux"
IUSE="mysql system-state"
RESTRICT="bindist mirror splitdebug"

RDEPEND="
	sys-apps/dmidecode
	sys-libs/glibc
	mysql? (
		virtual/mysql
		amd64? (
			dev-libs/libgcrypt:0/20
			|| ( dev-libs/openssl:0/1.0 dev-libs/openssl-compat:1.0.0 )
			dev-libs/protobuf:0/31
		)
	)
	system-state? ( sys-apps/util-linux )
	"

QA_PREBUILT="*"

S="${WORKDIR}/MXB"

MY_INSTALL_DIR="/opt/${PN}"

src_compile() {
	if ! use system-state; then
		local each
		for each in libvixDiskLib.so.5 libvixMntapi.so.1; do
			$(tc-getBUILD_CC) -shared -x c /dev/null -o ${each} || die
			$(tc-getBUILD_STRIP) ${each}
		done
	fi
}

src_install() {
	into "${MY_INSTALL_DIR}"
	dobin bin/{BackupFP,BRMigrationTool,ClientTool,ProcessController}

	dosym /usr/sbin/dmidecode "${MY_INSTALL_DIR}"/bin/dmidecode

	cp sbin/configure-fp.sh "${T}"/
	sed \
		-e "s|/etc/init.d/ProcessController|/etc/init.d/${PN}|g" \
		-e "s|/etc/rc.d/ProcessController|/etc/rc.d/${PN}|g" \
		-e "s|/opt/MXB|${MY_INSTALL_DIR}|g" \
		-i "${T}"/configure-fp.sh || die
	dosbin "${T}"/configure-fp.sh

	if use mysql; then
		dobin bin/xtrabackup_{2.0,2.0_51,2.0_55,2.4,8.0.22}

		if use amd64; then
			dobin bin/xtrabackup_8.0.28
			# Packaged binary not stripped :-\
			$(tc-getBUILD_STRIP) "${MY_INSTALL_DIR}"/bin/xtrabackup_8.0.28

			dosym /usr/$(get_libdir)/libprotobuf-lite.so "${MY_INSTALL_DIR}"/bin/libprotobuf-lite.so.3.11.4
		fi

		exeinto "${MY_INSTALL_DIR}"/bin/tools
		doexe bin/tools/mysql-{5.6,8.0}
	fi

	insinto "${MY_INSTALL_DIR}"/etc
	doins etc/Backup.Branding.config

	cp etc/ProcessController.config "${T}"/
	sed \
		-e "s|/opt/MXB|${MY_INSTALL_DIR}|g" \
		-i "${T}"/ProcessController.config || die
	doins "${T}"/ProcessController.config

	insinto "${MY_INSTALL_DIR}"/share/bm
	doins share/bm/web.zip{,.hash}

	insinto "${MY_INSTALL_DIR}"/lib

	if use system-state; then
		local each
		for each in libcrypto.so.0.9.8 libdiskLibPlugin.so libexpat.so.0 libfuse.so.2 libssl.so.0.9.8 libtypes.so libvixDiskLib.so.5 libvixMntapi.so.1 libvmacore.so libvmomi.so; do
			doins lib/${each}
			fperms a+x "${MY_INSTALL_DIR}"/lib/${each}
		done
	else
		doins libvixDiskLib.so.5 libvixMntapi.so.1
	fi

	dosym "${MY_INSTALL_DIR}"/bin/ClientTool /opt/bin/ClientTool

	newinitd "${FILESDIR}/${PN}.rc" "${PN}"
}

pkg_postinst() {
	elog "For initial configuration run:"
	elog "  ${MY_INSTALL_DIR}/sbin/configure-fp.sh"
	elog ""
	elog "For additional configuration refer to:"
	elog "  ClientTool help"
}

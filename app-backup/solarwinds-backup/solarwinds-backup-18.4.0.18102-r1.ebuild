# Copyright 2017-2018 Mike Gelfand
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit eutils toolchain-funcs unpacker versionator

MY_REV="714a90c586-8186"
MY_PN="mxb"
MY_PV="${PV}-${MY_REV}"
MY_P="${MY_PN}-${MY_PV}"

MY_PV_DIR="$(get_version_component_range 1-3)/$(get_version_component_range 4)-${MY_REV}"
MY_SRC_URI_BASE="https://www.iaso.com/download/release/${MY_PV_DIR}/${MY_PN}-${PV}"

DESCRIPTION="Backup and recovery software focused on helping keep businesses running"
HOMEPAGE="https://www.solarwindsmsp.com/products/backup"
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
	mysql? ( virtual/mysql )
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
		dobin bin/xtrabackup{,_51,_55}

		exeinto "${MY_INSTALL_DIR}"/bin/tools
		doexe bin/tools/mysql
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

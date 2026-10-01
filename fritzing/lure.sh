name='fritzing'
version='1.0.8'
release='1'
desc='PCB layout prototyping application'
homepage='https://fritzing.org'
maintainer='Foad S. Farimani <f.s.farimani@gmail.com>'
architectures=('amd64' 'arm64')
license=('GPL-3.0-only' 'CC-BY-SA-3.0' 'BSL-1.0')
provides=('fritzing')
conflicts=('fritzing')

# Derived from the AUR package https://aur.archlinux.org/packages/fritzing
# (maintained by Michael Lass, https://github.com/michaellass/AUR).
#
# The upstream version string has a trailing "b" that is dropped, as in the AUR.
# Upstream tags are not usable for releases, so the application commit that
# corresponds to the release is pinned. The same goes for fritzing-parts, which
# has been unversioned since 2016.
_gitrev='5aa56a510183c23084990a6b4481708cad24c15b'
_partsrev='27535f2fd02097be9bed229b75aa8e9be282a4a0'

# The Debian/Ubuntu and Fedora lists name the -dev/-devel packages in deps as
# well: LURE does not generate shared-library dependencies, and the library
# package names there carry soname or t64 suffixes that differ between releases.
deps_arch=('glibc' 'libgcc' 'libgit2' 'libstdc++' 'qt6-base' 'qt6-serialport' 'qt6-svg' 'quazip-qt6' 'ngspice' 'zlib')
build_deps_arch=('boost' 'git' 'patchelf' 'qt6-tools' 'gcc' 'make' 'glibc' 'libgit2' 'qt6-base' 'qt6-serialport' 'qt6-svg' 'quazip-qt6' 'ngspice' 'zlib')

deps_debian=('libgit2-dev' 'libpolyclipping-dev' 'libngspice0-dev' 'libquazip1-qt6-dev' 'qt6-base-dev' 'qt6-svg-dev' 'qt6-serialport-dev' 'libqt6sql6-sqlite' 'zlib1g-dev')
build_deps_debian=('g++' 'make' 'git' 'patchelf' 'pkg-config' 'libboost-dev' 'libgit2-dev' 'libpolyclipping-dev' 'libngspice0-dev' 'libquazip1-qt6-dev' 'qt6-base-dev' 'qt6-base-dev-tools' 'qt6-svg-dev' 'qt6-serialport-dev' 'qt6-tools-dev' 'qt6-l10n-tools' 'qt6-5compat-dev' 'libqt6sql6-sqlite' 'libgl-dev' 'zlib1g-dev')

deps_fedora=('libgit2-devel' 'polyclipping-devel' 'ngspice' 'ngspice-codemodel' 'quazip-qt6-devel' 'qt6-qtbase-devel' 'qt6-qtsvg-devel' 'qt6-qtserialport-devel' 'zlib-devel')
build_deps_fedora=('gcc-c++' 'make' 'git' 'patchelf' 'pkgconf' 'boost-devel' 'libgit2-devel' 'polyclipping-devel' 'ngspice' 'ngspice-codemodel' 'quazip-qt6-devel' 'qt6-qtbase-devel' 'qt6-qtsvg-devel' 'qt6-qtserialport-devel' 'qt6-qttools-devel' 'qt6-qt5compat-devel' 'mesa-libGL-devel' 'zlib-devel')

sources=(
	"git+https://github.com/fritzing/fritzing-app.git?~rev=${_gitrev}"
	"git+https://github.com/fritzing/fritzing-parts.git?~rev=${_partsrev}"
	'https://github.com/svgpp/svgpp/archive/refs/tags/v1.3.1.tar.gz'
	'https://github.com/skyrpex/clipper/archive/b1f1e1672745c1e1d73dd0437d1643f9633e7508.tar.gz'
)
checksums=('SKIP' 'SKIP' 'be8a89df72d01cf062cc9815dd64c9576b4d20910d6d7aee7f0ea26484dc5e76' '05e2cb91ac928400bb38179242f445dc35962b1903004a4b50aacc9890111089')

prepare() {
	cd "${srcdir}/fritzing-app"

	# The AUR carries four hand-written patches that hard-code Arch's
	# /usr/include layout (and a quazip version number). The same changes are
	# made here by looking the locations up, so that they work on other distros.

	# Compile against the system libraries instead of the sibling directories
	# phoenix.pro normally expects.
	quazip_inc=$(find /usr/include -maxdepth 1 -type d -name 'QuaZip-Qt6-*' | sort -V | tail -n 1)
	if [ -z "${quazip_inc}" ]; then
		echo "QuaZip-Qt6 headers not found under /usr/include" >&2
		return 1
	fi
	cat >pri/quazipdetect.pri <<-EOF
		message("including the system quazip library")
		SOURCES += src/zlibdummy.c
		INCLUDEPATH += ${quazip_inc}
		LIBS += -lquazip1-qt6
	EOF

	ngspice_inc=$(dirname "$(dirname "$(find /usr/include -name sharedspice.h | head -n 1)")")
	if [ ! -f "${ngspice_inc}/ngspice/sharedspice.h" ]; then
		echo "ngspice headers (sharedspice.h) not found under /usr/include" >&2
		return 1
	fi
	cat >pri/spicedetect.pri <<-EOF
		message("including the system ngspice headers")
		INCLUDEPATH += ${ngspice_inc}
	EOF

	# polyclipping is not in Arch's official repositories (AUR only), so the
	# library is compiled into the application from a pinned source tree when
	# the system does not provide it.
	if [ -f /usr/include/polyclipping/clipper.hpp ]; then
		cat >pri/clipper1detect.pri <<-EOF
			message("including the system polyclipping library")
			INCLUDEPATH += /usr/include/polyclipping
			LIBS += -lpolyclipping
		EOF
	else
		clipper_cpp=$(find "${srcdir}" -path '*/clipper-*/cpp/clipper.cpp' | head -n 1)
		if [ -z "${clipper_cpp}" ]; then
			echo "Clipper1 sources not found under ${srcdir}" >&2
			return 1
		fi
		cat >pri/clipper1detect.pri <<-EOF
			message("compiling the bundled Clipper1 sources")
			INCLUDEPATH += $(dirname "${clipper_cpp}")
			SOURCES += ${clipper_cpp}
		EOF
	fi

	# quazip's headers pull in Qt5Compat, and this lifts the Qt version window
	# (the AUR does both through patches 0001 and 0004).
	sed -i 's/openglwidgets$/openglwidgets core5compat/' phoenix.pro
	sed -i '/^QT_LEAST=/d;/^QT_MOST=/d;/versionAtLeast(QT_VERSION/d;/versionAtMost(QT_VERSION/d' phoenix.pro

	# svgpp is header-only; wherever the archive was unpacked, find its include root
	svgpp_hpp=$(find "${srcdir}" -path '*/include/svgpp/svgpp.hpp' | head -n 1)
	if [ -z "${svgpp_hpp}" ]; then
		echo "svgpp headers not found under ${srcdir}" >&2
		return 1
	fi
	cat >pri/svgppdetect.pri <<-EOF
		message("including svgpp from ${svgpp_hpp}")
		INCLUDEPATH += $(dirname "$(dirname "${svgpp_hpp}")")
	EOF

	# Disable broken font scaling (https://github.com/fritzing/fritzing-app/issues/3221)
	sed -i 's/Exec=Fritzing/Exec=env QT_AUTO_SCREEN_SCALE_FACTOR=0 Fritzing/' org.fritzing.Fritzing.desktop
}

build() {
	cd "${srcdir}/fritzing-app"

	# Where the Qt translation compiler lives differs between distros
	for lrel in lrelease-pro6 lrelease-pro /usr/lib/qt6/bin/lrelease-pro /usr/lib64/qt6/bin/lrelease-pro lrelease6 lrelease; do
		if command -v "${lrel}" >/dev/null 2>&1; then
			"${lrel}" phoenix.pro
			break
		fi
	done

	mkdir build
	cd build
	qmake6 ..
	make -j"${NCPU}"
}

package() {
	cd "${srcdir}/fritzing-app/build"
	make INSTALL_ROOT="${pkgdir}" install

	# Remove the RUNPATH that points into the build directory
	patchelf --remove-rpath "${pkgdir}/usr/bin/Fritzing"

	# System-wide installation of the parts library. Derived from
	# tools/linux_release_script/release.sh; the .git folder is dropped
	# afterwards because it is not needed at runtime.
	cp -dr "${srcdir}/fritzing-parts" "${pkgdir}/usr/share/fritzing/"
	"${pkgdir}/usr/bin/Fritzing" \
		-db "${pkgdir}/usr/share/fritzing/fritzing-parts/parts.db" \
		-pp "${pkgdir}/usr/share/fritzing/fritzing-parts" \
		-f "${pkgdir}/usr/share/fritzing" \
		-platform offscreen
	rm -rf "${pkgdir}"/usr/share/fritzing/fritzing-parts/.git{,ignore}

	# Fritzing loads the simulator from <prefix>/lib/libngspice.so and then
	# looks for the XSPICE code models in <prefix>/lib/ngspice. That is where
	# Arch keeps them; elsewhere (Debian's multiarch directory, Fedora's lib64)
	# they are linked into /usr/lib.
	ngspice_so=$(find /usr/lib /usr/lib64 -name libngspice.so 2>/dev/null | head -n 1)
	if [ -n "${ngspice_so}" ] && [ "$(dirname "${ngspice_so}")" != /usr/lib ]; then
		mkdir -p "${pkgdir}/usr/lib"
		ln -s "${ngspice_so}" "${pkgdir}/usr/lib/libngspice.so"
		if [ -d "$(dirname "${ngspice_so}")/ngspice" ]; then
			ln -s "$(dirname "${ngspice_so}")/ngspice" "${pkgdir}/usr/lib/ngspice"
		fi
	fi
}

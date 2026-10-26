name="retdec-git"
version="0"
release="1"
desc="A retargetable machine-code decompiler based on LLVM"
homepage="https://github.com/avast/retdec"
maintainer="Foad <f.s.farimani@gmail.com>"
architectures=("amd64")
license=("MIT" "Zlib")
provides=("retdec")
conflicts=("retdec")

# git is needed at configure time: CMake embeds the commit and tag in the binaries
build_deps=("build-essential" "cmake" "git" "openssl" "libssl-dev" "python3" "autoconf" "automake" "libtool" "pkg-config" "m4" "zlib1g-dev")

deps=("libc6" "libgcc-s1" "libstdc++6" "libssl3" "zlib1g" "python3")

opt_deps=(
	"upx-ucl: unpack UPX-packed binaries before decompilation"
	"graphviz: render the call and control-flow graphs"
)

sources=("git+https://github.com/avast/retdec.git")
checksums=("SKIP")

version() {
	cd "$srcdir/retdec"
	git-version
}

prepare() {
	# GCC >= 15 no longer pulls in <cstdint> transitively
	cd "$srcdir/retdec/include/retdec/demangler"
	grep -q '<cstdint>' borland_ast_parser.h || sed -i 's|^#include <llvm/Demangle/StringView.h>|#include <cstdint>\n&|' borland_ast_parser.h
}

build() {
	# CMake >= 4 rejects the cmake_minimum_required() of the bundled LLVM, YARA and yaramod
	export CMAKE_POLICY_VERSION_MINIMUM=3.5

	# The install rules run scripts with absolute paths fixed at configure time,
	# so DESTDIR is not honoured and the prefix has to point into $pkgdir.
	# Binaries find their data relative to themselves (../share/retdec).
	cmake -S "$srcdir/retdec" -B "$srcdir/retdec/build" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="$pkgdir/usr"
	cmake --build "$srcdir/retdec/build" --parallel "$NCPU"
}

package() {
	# Also downloads the retdec-support signature package and compiles the YARA rules
	cmake --install "$srcdir/retdec/build"

	install-license "$srcdir/retdec/LICENSE" retdec-git/LICENSE
	install-license "$srcdir/retdec/LICENSE-PELIB" retdec-git/LICENSE-PELIB
	install-license "$srcdir/retdec/LICENSE-THIRD-PARTY" retdec-git/LICENSE-THIRD-PARTY
}

name="vc4c-git"
version="0.0.0"
release="1"
desc="Compiler for the VC4CL OpenCL implementation (VideoCore IV)"
homepage="https://github.com/doe300/VC4C"
maintainer="Foad Sojoodi Farimani <f.s.farimani@gmail.com>"
architectures=("arm64" "arm")
license=("MIT")
provides=("vc4c")

# Runtime dependencies
deps=("vc4c-stdlib")

# Build dependencies
build_deps=(
    "git"
    "cmake"
    "build-essential"
    "clang"
    "llvm"
    "llvm-dev"
    "libclang-dev"
    "llvm-spirv-14"
    "spirv-tools"
    "pkg-config"
    "vc4c-stdlib"
)
sources=("git+https://github.com/doe300/VC4C.git")
checksums=("SKIP")

version() {
    cd "$srcdir/VC4C"
    # Debian requires version to start with a digit
    printf "0.0.0.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
    cd "$srcdir/VC4C"
    mkdir -p build
    cd build
    
    # VC4C has multiple frontends - try to enable what's available
    # Disable stdlib precompilation during build - it tries to write to /usr/include
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DVC4CL_STDLIB_DIR=/usr/include/vc4cl-stdlib \
        -DVC4CL_STDLIB_PRECOMPILE=OFF
    
    make -j1
}

package() {
    cd "$srcdir/VC4C/build"
    make DESTDIR="$pkgdir" install
}

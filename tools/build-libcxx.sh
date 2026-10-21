#!/bin/sh
# Static libc++ and libc++abi for armv7 iOS 4-7 into ~/.cache/legacyfox/libcxx-armv7.
#
# iOS 4 has no libc++ and iOS 5-6 have one far too old for the C++20 Gecko is
# written in, so a current one is linked into the app. Compiled with the
# system clang (the theos clang 13 is too old for libc++ 21), archived with the
# theos cctools. Needs cmake and ninja (LEGACYFOX_CMAKE, default the copy in
# the cache).
set -e
CACHE=${LEGACYFOX_CACHE:-$HOME/.cache/legacyfox}
LLVM_TAG=${LEGACYFOX_LLVM_TAG:-llvmorg-21.1.8}
THEOS=${THEOS:-$HOME/theos}
TC=${LEGACYFOX_TC:-$THEOS/toolchain/linux/iphone/bin}
SDK=${LEGACYFOX_SDK:-$THEOS/sdks/iPhoneOS6.1.sdk}
CMAKE=${LEGACYFOX_CMAKE:-$CACHE/cmake/bin/cmake}
NINJA=${LEGACYFOX_NINJA:-$CACHE/cmake/bin/ninja}
COMPAT=$(cd "$(dirname "$0")/../compat" && pwd)

if [ ! -d "$CACHE/llvm-src" ]; then
    git clone --depth 1 --branch "$LLVM_TAG" --filter=blob:none --sparse \
        https://github.com/llvm/llvm-project "$CACHE/llvm-src"
    git -C "$CACHE/llvm-src" sparse-checkout set runtimes libcxx libcxxabi libunwind cmake \
        llvm/cmake llvm/utils/llvm-lit llvm/utils/lit third-party \
        libc/shared libc/src/__support libc/hdr libc/include/llvm-libc-macros \
        libc/include/llvm-libc-types
fi

"$CMAKE" -G Ninja -S "$CACHE/llvm-src/runtimes" -B "$CACHE/libcxx-build" \
    -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=armv7 \
    -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_OSX_DEPLOYMENT_TARGET=4.0 \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER_TARGET=armv7-apple-ios4.0 -DCMAKE_CXX_COMPILER_TARGET=armv7-apple-ios4.0 \
    -DCMAKE_AR="$TC/ar" -DCMAKE_RANLIB="$TC/ranlib" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_INSTALL_PREFIX="$CACHE/libcxx-armv7" \
    -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXXABI_ENABLE_SHARED=OFF \
    -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DLIBCXX_CXX_ABI=libcxxabi \
    -DLIBCXX_INCLUDE_TESTS=OFF -DLIBCXX_INCLUDE_BENCHMARKS=OFF -DLIBCXXABI_INCLUDE_TESTS=OFF \
    -DLIBCXX_HAS_PTHREAD_API=ON -DLIBCXXABI_USE_LLVM_UNWINDER=OFF \
    -DLIBCXX_ENABLE_TIME_ZONE_DATABASE=OFF \
    -DLIBCXX_HERMETIC_STATIC_LIBRARY=ON -DLIBCXXABI_HERMETIC_STATIC_LIBRARY=ON \
    -DCMAKE_C_FLAGS="-femulated-tls" \
    -DCMAKE_CXX_FLAGS="-femulated-tls -include $COMPAT/legacyfox_compat.h"
"$NINJA" -C "$CACHE/libcxx-build" install-cxx install-cxxabi

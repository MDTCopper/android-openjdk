#!/bin/bash
set -e
. setdevkitpath.sh

if [[ "$BUILD_IOS" != "1" ]]; then

unset AR AS CC CXX LD OBJCOPY RANLIB STRIP CPPFLAGS LDFLAGS
git clone https://github.com/termux/termux-elf-cleaner || true
cd termux-elf-cleaner
mkdir build
cd build
export CFLAGS=-D__ANDROID_API__=${API}
cmake ..
make -j4
unset CFLAGS
cd ../..

findexec() { find $1 -type f -name "*" -not -name "*.o" -exec sh -c '
    case "$(head -n 1 "$1")" in
      ?ELF*) exit 0;;
      MZ*) exit 0;;
      #!*/ocamlrun*)exit0;;
    esac
exit 1
' sh {} \; -print
}

# --api-level is essential: without it termux-elf-cleaner assumes API 21 and
# strips DT_GNU_HASH (and VERSYM/VERNEED/VERDEF/RUNPATH), which leaves the
# libraries without any hash table and bionic then fails with
# "empty/missing DT_HASH/DT_GNU_HASH ... (new hash type from the future?)".
findexec jreout | xargs -- ./termux-elf-cleaner/build/termux-elf-cleaner --api-level ${API}
findexec jdkout | xargs -- ./termux-elf-cleaner/build/termux-elf-cleaner --api-level ${API}

fi

cp -rv jre_override/lib/* jreout/lib/ || true

cd jreout

# Strip in place all .so files thanks to the ndk
find ./ -name '*.so' -execdir ${TOOLCHAIN}/bin/llvm-strip {} \;


tar cJf ../jre${TARGET_VERSION}-${TARGET_SHORT}-`date +%Y%m%d`-${JDK_DEBUG_LEVEL}.tar.xz .

cd ../jdkout
tar cJf ../jdk${TARGET_VERSION}-${TARGET_SHORT}-`date +%Y%m%d`-${JDK_DEBUG_LEVEL}.tar.xz .

# Remove jreout and jdkout
cd ..
rm -rf jreout jdkout


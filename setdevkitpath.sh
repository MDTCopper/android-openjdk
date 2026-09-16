# Description: Set the environment variables for the build scripts.
# NDK release name, used for the standalone download (android-ndk-<release>-linux.zip)
export NDK_VERSION=r29
# Full NDK package revision, used for Android SDK style installs (<sdk>/ndk/<revision>)
export NDK_REVISION=29.0.14206865

# Target version is either 17, 21 or 25
if [[ -z "$TARGET_VERSION" ]]
then
  export TARGET_VERSION=25
fi


# Set custom java version as the defautl jdk depending on the target version
# Local build with docker only
if [[ -z "$CI" ]]
then
  update-java-alternatives -s java-1.${TARGET_VERSION}*
fi

if [[ -z "$BUILD_FREETYPE_VERSION" ]]
then
  export BUILD_FREETYPE_VERSION="2.10.0"
fi

if [[ -z "$JDK_DEBUG_LEVEL" ]]
then
  export JDK_DEBUG_LEVEL=release
fi

if [[ "$TARGET_JDK" == "aarch64" ]]
then
  export TARGET_SHORT=arm64
else
  export TARGET_SHORT=$TARGET_JDK
fi

if [[ -z "$JVM_VARIANTS" ]]
then
  export JVM_VARIANTS=server
fi

if [[ "$BUILD_IOS" == "1" ]]; then
  export JVM_PLATFORM=macosx

  export thecc=$(xcrun -find -sdk iphoneos clang)
  export thecxx=$(xcrun -find -sdk iphoneos clang++)
  export thesysroot=$(xcrun --sdk iphoneos --show-sdk-path)
  export themacsysroot=$(xcrun --sdk macosx --show-sdk-path)

  export thehostcxx=$PWD/macos-host-cc
  export CC=$PWD/ios-arm64-clang
  export CXX=$PWD/ios-arm64-clang++
  export CXXCPP="$CXX -E"
  export LD=$(xcrun -find -sdk iphoneos ld)

  export HOTSPOT_DISABLE_DTRACE_PROBES=1

  export ANDROID_INCLUDE=$PWD/ios-missing-include
else

export JVM_PLATFORM=linux

# Android 11 is the oldest supported release (API level 30)
export API=30

# Pick the NDK to build against. An explicitly configured ANDROID_NDK_HOME is
# honoured, but a preinstalled NDK of another revision (the GitHub runners ship
# one) is rejected so that the build always uses $NDK_REVISION.
ndk_revision_matches() {
  local root="$1"
  [[ -n "$root" && -d "$root/toolchains/llvm/prebuilt/linux-x86_64" ]] || return 1
  # Both the standalone and the SDK install ship a source.properties
  if [[ -f "$root/source.properties" ]]; then
    grep -q "^Pkg.Revision = ${NDK_REVISION}$" "$root/source.properties" || return 1
  fi
  return 0
}

if [[ -n "$ANDROID_NDK_HOME" && "$SKIP_NDK_VERSION_CHECK" != "1" ]] && ! ndk_revision_matches "$ANDROID_NDK_HOME"; then
  echo "NOTE: ignoring ANDROID_NDK_HOME=$ANDROID_NDK_HOME, it is not NDK $NDK_REVISION"
  echo "      (set SKIP_NDK_VERSION_CHECK=1 to use it anyway)"
  unset ANDROID_NDK_HOME
fi

if [[ -z "$ANDROID_NDK_HOME" ]]
then
  # An Android SDK install, e.g. ./android-sdk/ndk/29.0.14206865
  for ndk_candidate in \
      "$ANDROID_SDK_ROOT/ndk/$NDK_REVISION" \
      "$ANDROID_HOME/ndk/$NDK_REVISION" \
      "$PWD/../android-sdk/ndk/$NDK_REVISION"; do
    if ndk_revision_matches "$ndk_candidate"; then
      export ANDROID_NDK_HOME="$ndk_candidate"
      break
    fi
  done
  # ...otherwise use the standalone NDK that 2_ci_build_global.sh downloads
  if [[ -z "$ANDROID_NDK_HOME" ]]; then
    export ANDROID_NDK_HOME=$PWD/android-ndk-$NDK_VERSION
  fi
fi

export TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64

export ANDROID_INCLUDE=$TOOLCHAIN/sysroot/usr/include


# If I'm right it should only need the dummy libs
export CPPFLAGS="-I$ANDROID_INCLUDE -I$ANDROID_INCLUDE/$TARGET" # -I/usr/include -I/usr/lib
export CPPFLAGS=""
export LDFLAGS=""

# Underlying compiler called by the wrappers
export thecc=$TOOLCHAIN/bin/${TARGET}${API}-clang
export thecxx=$TOOLCHAIN/bin/${TARGET}${API}-clang++

# Configure and build.
export AR=$TOOLCHAIN/bin/llvm-ar
export AS=$TOOLCHAIN/bin/llvm-as
export CC=$PWD/android-wrapped-clang
export CXX=$PWD/android-wrapped-clang++
export LD=$TOOLCHAIN/bin/ld
export OBJCOPY=$TOOLCHAIN/bin/llvm-objcopy
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip
fi

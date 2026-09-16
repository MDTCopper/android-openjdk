#!/bin/bash
set -e
. setdevkitpath.sh

export JDK_DEBUG_LEVEL=release

if [[ "$BUILD_IOS" != "1" ]]; then
  # setdevkitpath.sh only screens the candidates it can find *before* the
  # download, so the revision is re-checked here. Without this, an existing
  # android-ndk-<release> directory (stale, half-unpacked, or simply the wrong
  # build) was accepted on the strength of "the directory exists", and the build
  # failed much later with an error that did not point at the real cause.
  ndk_ok=0
  if [[ -d "$ANDROID_NDK_HOME" && "${SKIP_NDK_VERSION_CHECK:-0}" == "1" ]]; then
    echo "NOTE: using $ANDROID_NDK_HOME without a revision check (SKIP_NDK_VERSION_CHECK=1)"
    ndk_ok=1
  elif ndk_revision_matches "$ANDROID_NDK_HOME"; then
    echo "NDK already present: $ANDROID_NDK_HOME"
    ndk_ok=1
  fi

  if [[ "$ndk_ok" != "1" ]]; then
    echo "Downloading NDK $NDK_VERSION ($NDK_REVISION)"
    # Never unpack on top of a leftover tree: unzip merges, which would mix a
    # partial previous download into the result. Only ever remove the path this
    # script itself manages.
    if [[ -n "$ANDROID_NDK_HOME" && "$ANDROID_NDK_HOME" == "$PWD/android-ndk-$NDK_VERSION" ]]; then
      rm -rf "$ANDROID_NDK_HOME"
    fi
    # -nc is deliberately not used: it is incompatible with -O and can leave a
    # truncated archive behind that a later run would happily reuse.
    wget -nv -O android-ndk-$NDK_VERSION-linux-x86_64.zip "https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip"
    unzip -q android-ndk-$NDK_VERSION-linux-x86_64.zip

    [[ -d "$ANDROID_NDK_HOME" ]] || {
      echo "ERROR: extracting android-ndk-$NDK_VERSION-linux.zip did not produce $ANDROID_NDK_HOME" >&2
      exit 1
    }
    ndk_revision_matches "$ANDROID_NDK_HOME" || {
      echo "ERROR: $ANDROID_NDK_HOME is not NDK $NDK_REVISION after extraction" >&2
      exit 1
    }
  fi

  [[ -d "$TOOLCHAIN" ]] || {
    echo "ERROR: NDK toolchain not found: $TOOLCHAIN" >&2
    exit 1
  }
  cp devkit.info.${TARGET_SHORT} ${TOOLCHAIN}
else
  chmod +x ios-arm64-clang
  chmod +x ios-arm64-clang++
  chmod +x macos-host-cc
fi

# Some modifies to NDK to fix

# Only build the sources if they are not already present
if [ ! -d "cups-2.2.4" ]; then
  ./3_getlibs.sh
  ./4_buildlibs.sh
fi
./5_clonejdk.sh
./6_buildjdk.sh
./7_removejdkdebuginfo.sh
./8_tarjdk.sh

#!/bin/bash
set -e

# JDK 25 dropped 32-bit x86 support upstream (openjdk/jdk25u deleted it),
# exactly like Termux had to drop its i686 package.
TARGET_VERSION=${TARGET_VERSION:-25}
if [[ "$TARGET_VERSION" == "25" ]]; then
  echo "ERROR: JDK ${TARGET_VERSION} does not support 32-bit x86 (i686)." >&2
  echo "       Use 1_ci_build_arch_{aarch32,aarch64,x86_64}.sh for TARGET_VERSION=25," >&2
  echo "       or TARGET_VERSION=21 for x86." >&2
  exit 1
fi

export TARGET=i686-linux-android
export TARGET_JDK=x86

bash 2_ci_build_global.sh

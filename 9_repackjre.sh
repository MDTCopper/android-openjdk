#!/bin/bash
set -e

## Usage:
## ./repackjre.sh [path_to_normal_jre_tarballs] [output_path]

# set args
export in="$1"
export out="$2"

# set working dirs
work="$in/work"
work1="$in/work1"

# make sure paths exist
mkdir -p $work
mkdir -p $work1
mkdir -p "$out"

copyjvmlib() {
  if [[ -d lib/$1 ]]; then
    echo "Moving $1 VM for $2"
    mv lib/$1 "$work1"/lib/;
  fi
}

# here comes a not-so-complicated functions to easily make desired arch
## Usage: makearch [jre_libs_dir_name] [name_in_tarball]
makearch () {
  echo "Making $2...";
  cd "$work";
  # JDK 25 has no 32-bit x86 build, so not every architecture has to exist
  local tarball=$(find "$in" -name jre${TARGET_VERSION}-$2-*release.tar.xz | head -n1)
  if [[ -z "$tarball" ]]; then
    echo "Skipping $2: no jre${TARGET_VERSION}-$2 tarball found";
    return 0
  fi
  tar xf "$tarball" > /dev/null 2>&1;
  mv bin "$work1"/;
  mkdir -p "$work1"/lib;
  
  #mv lib/$1 "$work1"/lib/;
  mv lib/jexec "$work1"/lib/ 2>/dev/null || true;
  mv lib/jvm.cfg "$work1"/lib/ 2>/dev/null || true;
  
  # server contains the libjvm.so
  copyjvmlib server $2
  copyjvmlib client $2
  
  
  # All the other .so files are at the root of the lib folder
  find ./ -name '*.so' -execdir mv {} "$work1"/lib/{} \;
  
  mv release "$work1"/release
  
  XZ_OPT="-6 --threads=0" tar cJf bin-$2.tar.xz -C "$work1" . > /dev/null;
  mv bin-$2.tar.xz "$out"/;
  rm -rf "$work"/*;
  rm -rf "$work1"/*;
 }

# this one's static
makeuni () {
  echo "Making universal...";
  cd "$work";
  # the universal part only needs one build; prefer arm64, else any architecture
  local uni_tarball=$(find "$in" -name jre${TARGET_VERSION}-arm64-*release.tar.xz | head -n1)
  if [[ -z "$uni_tarball" ]]; then
    uni_tarball=$(find "$in" -name jre${TARGET_VERSION}-*release.tar.xz | head -n1)
  fi
  if [[ -z "$uni_tarball" ]]; then
    echo "No jre${TARGET_VERSION} tarball found in $in" >&2
    return 1
  fi
  tar xf "$uni_tarball" > /dev/null 2>&1;

  rm -rf bin;
  rm -rf lib/server;
  # jexec/jvm.cfg/release are launcher details and not present in every image
  rm -f lib/jexec lib/jvm.cfg release
  find ./ -name '*.so' -execdir rm {} \; # Remove arch specific shared objects
  
  XZ_OPT="-6 --threads=0" tar cJf universal.tar.xz * > /dev/null;
  mv universal.tar.xz "$out"/;
  rm -rf "$work"/*;
 }

# now time to use them!
makeuni
makearch aarch32 arm
makearch aarch64 arm64
makearch i386 x86
makearch amd64 x86_64

# The version marker is read back by launchers (oxygen-launcher's
# JreManager.isLatest does version.toLong()), so it has to stay numeric and
# WITHOUT a trailing newline: Long.parseLong rejects whitespace. printf is used
# instead of echo for exactly that reason.
# JRE_VERSION wins, then the CI run number, then the date.
if [[ -n "$JRE_VERSION" ]]
then
printf '%s' "$JRE_VERSION">"$out"/version
elif [[ -n "$GITHUB_RUN_NUMBER" ]]
then
printf '%s' "$GITHUB_RUN_NUMBER">"$out"/version
elif [[ -n "$GITHUB_SHA" ]]
then
printf '%s' "$GITHUB_SHA">"$out"/version
else
printf '%s' "$(date +%Y%m%d)">"$out"/version
fi

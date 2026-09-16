# Porting notes: `jdk25u_android.diff`

This patch set is a port of `patches/jre_21/android/*` to JDK 25, with a few
fixes taken from Termux's `packages/openjdk-25` where JDK 25 changed behaviour.

Base: `https://github.com/openjdk/jdk25u` tag **`jdk-25.0.4.1-ga`** (branch
`jdk25.0.4.1`, commit `7b65d74`). `5_clonejdk.sh` clones exactly that tag, and the
patch is applied by `6_buildjdk.sh` with
`git apply --reject --whitespace=fix`, so **every hunk has to apply cleanly**.

How it was produced: blobless + sparse checkout of `jdk25u`, apply the jre_21
patch with `--reject`, rework each rejected hunk against the JDK 25 sources, then
`git diff` the resulting tree. Re-verify locally with the same command the build
uses (`git apply --reject --whitespace=fix` must report zero rejects).

## Hunks that carried over unchanged (96 of 138)

Most of the jre_21 set still applies: the `make/autoconf` android checks, the
`posix_spawn` compatibility implementation, the AOSP `getifaddrs`/`getloadavg`
replacements in `os_perf_linux.cpp` / `os_linux.cpp`, the `fpu_control.h` copies,
the libjli `SetExecname` fix, `ResolverConfigurationImpl`, `EncodingSupport_md.c`
and `utf_util.c` (the `nl_langinfo(CODESET)` workaround), `elfFile.hpp`,
`globalDefinitions_gcc.hpp`, and the arm32 sources.

## Reworked hunks (42)

| JDK 25 change | Rework |
|---|---|
| `make/hotspot/lib/JvmMapfile.gmk` was merged into `CompileJvm.gmk` | hunk dropped, the remaining `isTargetOs(..., linux)` logic already matches |
| `Awt2dLibraries.gmk` split into `AwtLibraries.gmk` + `ClientLibraries.gmk` | libfontmanager now gets `LIBS_unix := -lawt_headless $(LIBM)` in `ClientLibraries.gmk`; splashscreen target removed from `ClientLibraries.gmk`, jsound from `java.desktop/Lib.gmk` |
| `BUILD_LIBSA` renamed to `BUILD_LIBSAPROC` | `TARGETS += $(BUILD_LIBSAPROC)` is commented out in `jdk.hotspot.agent/Lib.gmk` |
| `JavaThread::aarch64_get_thread_helper` is gone (the header now returns `Thread::current()`) | the assembly implementation in `threadLS_linux_aarch64.S` is wrapped in `#ifndef __ANDROID__` |
| `SYS_gettid` block simplified to i386/amd64 | arm (224) and aarch64 (178) cases added back |
| SHM based large page support was removed from hotspot | the six `shm_*`/`reserve_memory_special_shm` hunks dropped |
| arm32 assembly still uses pre-UAL aliases, which clang 21 rejects | 17 mnemonics rewritten (`addlts`→`addslt`, `ldrgeh`→`ldrhge`, `strgeh`→`strhge`, …) |
| `futimesat`/`lutimes` remapping was replaced by `utimensat` in `UnixNativeDispatcher.c` | all six futimesat hunks dropped |
| bionic provides `getgrgid_r`/`getgrnam_r` (API 24+), `utimensat`, `dlvsym` (libdl) | the corresponding compatibility shims were dropped |
| `CFLAGS_OS_DEF_JDK` uses `_FILE_OFFSET_BITS=64` instead of `_LARGEFILE64_SOURCE` | `-D__USE_BSD` appended to the new value |
| JDK 25 removed the `libtinyiconv` build target and routes iconv through `ICONV_CFLAGS/LDFLAGS/LIBS` | TinyCD (`iconv.cpp`) and its three wiring hunks dropped; bionic's libc iconv is used (see limitations) |
| `make/modules/jdk.net/Lib.gmk` no longer guards `libextnet` by OS | hunk dropped |
| `FindSrcDirsForLib` no longer exists (`FindSrcDirsForComponent` covers linux) | hunk dropped |

The i686 specific hunk in `JvmOverrideFiles.gmk` was dropped as well: JDK 25
removed 32-bit x86, and `isTargetCpu, x86` is false for `x86_64`.

`26_skip_proc_net6_check.diff` from jre_21 was folded into this patch (the
`/proc/net/if_inet6` check is skipped on Android).

## Android fixes added on top (from Termux's `packages/openjdk-25`)

- `-DARM` is missing in the clang branch of `flags-cflags.m4` (`ad_arm.cpp` errors
  with "ARM must be defined").
- `make/data/hotspot-symbols/version-script-{clang,gcc}.txt`: drop the `local:`
  block (`_fini`, `_init`, …), lld 21 fails the link otherwise.
- `UnixNativeDispatcher.c`: do not `dlsym` `statx` on Android (crashes on some
  devices) and skip the `__uint32_t`/`__uint16_t` typedefs on bionic.
- `os_posix.cpp`: the utmpx based uptime lookup is unusable on Android.

## Limitations

- **iconv**: since JDK 25 has no `libtinyiconv` anymore, the JRE uses bionic's
  iconv (API 28+, so fine at API 30). Bionic only supports a handful of
  encodings, so charset conversion in `libinstrument`/`libjdwp`/`libjava` is
  limited compared to the TinyCD implementation the JDK 21 build carries. If that
  ever matters, TinyCD can be reintroduced through the `ICONV_*` variables.
- **Signals in the compiler wrapper**: because the build pretends to be gcc
  (`android-wrapped-clang`), `android-wrapped-clang(++)` has to strip gcc-only
  flags (`-fno-lifetime-dse`, …) and silence the clang warnings that the JDK only
  disables in clang mode (`-w`); both lists are overridable through
  `CLANG_WRAPPER_STRIP_FLAGS` / `CLANG_WRAPPER_WARN_FLAGS`.

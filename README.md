# mobile-openjdk8-build-multiarch 

Based on http://openjdk.java.net/projects/mobile/android.html

## Supported builds

| Target version | Architectures | Minimum API level | NDK |
|----------------|---------------|-------------------|-----|
| 17 | aarch32, aarch64, x86, x86_64 | 30 (Android 11) | r29 (29.0.14206865) |
| 21 | aarch32, aarch64, x86, x86_64 | 30 (Android 11) | r29 (29.0.14206865) |
| 25 | aarch32, aarch64, x86_64 | 30 (Android 11) | r29 (29.0.14206865) |

JDK 25 does **not** support 32-bit x86: `openjdk/jdk25u` removed that port upstream,
so `1_ci_build_arch_x86.sh` refuses to run with `TARGET_VERSION=25`.
On 32-bit ARM, g1gc is disabled for JDK 25 (it dies with SIGILL since JDK 24).

## Building 

### Setup
#### Android
- Download Android NDK r29 (29.0.14206865) from https://developer.android.com/ndk/downloads and place it in this directory (Can't automatically download because of EULA)
  - It is also found with `ANDROID_NDK_HOME` or `<android-sdk>/ndk/29.0.14206865` if the NDK was installed through the Android SDK manager.
  - The CI workflow downloads the standalone NDK r29 zip automatically.
- A boot JDK matching the target version (17, 21 or 25) must be the active JDK.

#### iOS
- You should get latest Xcode (tested with Xcode 12).

### Platform and architecture specific environment variables
<table>
      <thead>
        <tr>
          <th></th>
          <th align="center" colspan="7">Environment variables</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <th>Platform - Architecture</th>
          <th align="center">TARGET</th>
          <th align="center">TARGET_JDK</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Android - armv8/aarch64</td>
          <td align="center">aarch64-linux-android</td>
          <td align="center">aarch64</td>
        </tr>
        <tr>
          <td>Android - armv7/aarch32</td>
          <td align="center">arm-linux-androideabi</td>
          <td align="center">arm</td>
        </tr>
        <tr>
          <td>Android - x86/i686 (17/21 only)</td>
          <td align="center">i686-linux-android</td>
          <td align="center">x86</td>
        </tr>
        <tr>
          <td>Android - x86_64/amd64</td>
          <td align="center">x86_64-linux-android</td>
          <td align="center">x86_64</td>
        </tr>
        <tr>
          <td>iOS/iPadOS - armv8/aarch64</td>
          <td align="center">aarch64-macos-ios</td>
          <td align="center">aarch64</td>
        </tr>
      </tbody>
	</table>

### Run in this directory:
```
export TARGET_VERSION=[17/21/25] # default: 25
export BUILD_IOS=1 # only when targeting iOS, default is 0 (target Android)

export BUILD_FREETYPE_VERSION=[2.6.2/.../2.10.4] # default: 2.10.0
export JDK_DEBUG_LEVEL=[release/fastdebug/debug] # default: release
export JVM_VARIANTS=[client/server] # default: client (aarch32), server (other architectures)

# Get CUPS, Freetype and build Freetype
./3_getlibs.sh
./4_buildlibs.sh

# Clone JDK, run once
./5_clonejdk.sh

# Configure JDK and build, if no configuration is changed, run makejdkwithoutconfigure.sh instead
./6_buildjdk.sh

# Pack the built JDK
./7_removejdkdebuginfo.sh
./8_tarjdk.sh
```

The arch-specific CI entry points wrap all of that for a single architecture, e.g.
`export TARGET_VERSION=25 && bash 1_ci_build_arch_aarch64.sh`.

### Patches

`patches/jre_<version>/android` holds the Android patch set for each supported JDK
(`jre_17`, `jre_21`, `jre_25`). It is applied with `git apply --reject --whitespace=fix`,
so every hunk has to apply cleanly.

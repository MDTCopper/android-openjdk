FROM ubuntu:24.04

RUN apt-get update

# Install dependencies

# Raw tools
RUN apt-get install -y \
    autoconf \
    python3 \
    python-is-python3 \
    unzip \
    zip \
    systemtap-sdt-dev \
    libxtst-dev \
    libasound2-dev \
    libelf-dev \
    libfontconfig1-dev \
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxrender-dev \
    libxt-dev \
    wget \
    gcc \
    g++ \
    clang \
    git \
    file \
    make \
    cmake \
    xz-utils

# Boot JDKs
RUN apt-get install -y openjdk-17-jdk
RUN apt-get install -y openjdk-21-jdk
# Ubuntu 24.04 has no openjdk-25-jdk package, so install Temurin 25 as boot JDK
RUN apt-get install -y wget apt-transport-https gnupg \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y temurin-25-jdk

WORKDIR /home


# NDK install (r29 == 29.0.14206865)
ENV NDK_VERSION r29
ENV NDK_REVISION 29.0.14206865
ENV ANDROID_NDK_HOME /home/android-ndk-$NDK_VERSION
# -nc is deliberately not used: it is incompatible with -O and can leave a
# truncated archive behind. The revision is verified so the image can never
# silently carry an NDK other than the one the build pins (setdevkitpath.sh
# re-checks it at build time as well).
RUN \
    wget -nv -O android-ndk-$NDK_VERSION-linux-x86_64.zip "https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip" \
    && unzip -q android-ndk-$NDK_VERSION-linux-x86_64.zip \
    && rm android-ndk-$NDK_VERSION-linux-x86_64.zip \
    && grep -qxF "Pkg.Revision = $NDK_REVISION" "$ANDROID_NDK_HOME/source.properties"


COPY . .

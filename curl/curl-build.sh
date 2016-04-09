#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS libcurl libraries with Bitcode enabled

# Credits:
#
# Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
#   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
# Bochun Bai
#   https://github.com/sinofool/build-libcurl-ios
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
# Preston Jennings
#   https://github.com/prestonj/Build-OpenSSL-cURL

set -e

# cURL for iOS requires linking with libz (libz.tbd, Xcode 7.3, is know to work)

usage ()
{
    echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)]"
    exit 127
}

if [ "$1" == "-h" ]; then
    usage
fi

if [ -z $1 ]; then
    IOS_SDK_VERSION="" #"9.1"
    IOS_MIN_SDK_VERSION="8.0"

    TVOS_SDK_VERSION="" #"9.0"
    TVOS_MIN_SDK_VERSION="9.0"
else
    IOS_SDK_VERSION=$1
    TVOS_SDK_VERSION=$2
fi

CURL_VERSION="curl-7.48.0"
OPENSSL="${PWD}/../openssl"
DEVELOPER=`xcode-select -print-path`
IPHONEOS_DEPLOYMENT_TARGET="8.0"

buildIOS()
{
    ARCH=$1

    LOG_FILE=$(pwd)/${CURL_VERSION}-ios-${ARCH}.log
    if [ -e ${LOG_FILE} ]; then
        > ${LOG_FILE}
    fi

    pushd ${CURL_VERSION} > /dev/null

    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
        PLATFORM="iPhoneSimulator"
    else
        PLATFORM="iPhoneOS"
    fi

    export $PLATFORM
    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"
    export CC="$(which clang)"
    BITCODE_FLAG="-fembed-bitcode"
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${BITCODE_FLAG}"
    export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${OPENSSL}/ios/lib"

    printf "\e[1;36m[*] BUILDING cURL (VERSION ${CURL_VERSION}) FOR ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}\e[0m\n"

    if [[ "${ARCH}" == "arm64" ]]; then
        HOST="arm-apple-darwin"
    else
        HOST="${ARCH}-apple-darwin"
    fi

    ./configure \
        -prefix="/tmp/${CURL_VERSION}-ios-${ARCH}" \
        --disable-dependency-tracking --without-random \
        --disable-manual --disable-shared --enable-ipv6 \
        --disable-ftp    --disable-file   --disable-ldap \
        --disable-ldap   --disable-ldaps  --disable-rtsp \
        --disable-dict   --disable-telnet --disable-tftp \
        --disable-pop3   --disable-imap   --disable-smtp \
        --enable-static \
        --with-ssl=${OPENSSL}/ios \
        --host=${HOST} &> ${LOG_FILE}

    NUM_JOBS=$(sysctl -n hw.activecpu)
    make -j${NUM_JOBS} >> ${LOG_FILE} 2>&1
    make install >> ${LOG_FILE} 2>&1
    make clean >> ${LOG_FILE} 2>&1
    popd > /dev/null
}

clean_log() {
    rm -rf "*.log"
}

printf "\e[1;36m[*] CLEANING UP\e[0m\n"
rm -rf include/ lib-ios/

clean_log

mkdir -p lib-ios
mkdir -p include/

rm -rf "/tmp/${CURL_VERSION}-*"
rm -rf ${CURL_VERSION}-*.log

rm -rf "${CURL_VERSION}"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
    printf "\e[1;31m[X] cURL Version ${CURL_VERSION} is missing.\e[0m\n"
    exit 1
else
    printf "\e[1;36m[*] USING cURL ${CURL_VERSION}.tar.gz\e[0m\n"
fi


printf "\e[1;36m[*] UNPACKING cURL\e[0m\n"
tar xfz "${CURL_VERSION}.tar.gz"

printf "\e[1;36m[*] BUILDING IOS LIBRARIES (no bitcode)\e[0m\n"
buildIOS "armv7"
buildIOS "armv7s"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"


printf "\e[1;36m[*] COPYING HEADERS\e[0m\n"
cp -rf "/tmp/${CURL_VERSION}-ios-x86_64/include/curl" "include/"

printf "\e[1;36m[*] PACKING FAT BINARY FOR iOS (armv7, armv7s, arm64, i386, x86_64)\e[0m\n"
lipo \
    "/tmp/${CURL_VERSION}-ios-armv7/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-ios-armv7s/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-ios-i386/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-ios-arm64/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-ios-x86_64/lib/libcurl.a" \
    -create -output lib-ios/libcurl.a

printf "\e[1;36m[*] CLEANING UP\e[0m\n"
rm -rf /tmp/${CURL_VERSION}-*
rm -rf ${CURL_VERSION}
clean_log

printf "\e[1;32m[*]FINISHED BUILDING cURL\e[0m\n"

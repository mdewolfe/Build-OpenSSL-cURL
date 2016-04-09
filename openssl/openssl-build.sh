#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS openSSL libraries with Bitcode enabled

# Credits:
#
# Stefan Arentz
#   https://github.com/st3fan/ios-openssl
# Felix Schulze
#   https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# James Moore
#   https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
#   https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL

set -e

usage() {
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

OPENSSL_VERSION="openssl-1.0.2g"
DEVELOPER=`xcode-select -print-path`

buildMac() {
	ARCH=$1

	TARGET="darwin-i386-cc"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
	fi

	export CC="${BUILD_TOOLS}/usr/bin/clang -fembed-bitcode"

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	printf "\e[1;36m[*] BUILDING OpenSSL (version ${OPENSSL_VERSION}) FOR Mac OSX ${ARCH}\e[0m\n"

	./Configure \
		no-asm ${TARGET} \
		--openssldir="/tmp/${OPENSSL_VERSION}-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-${ARCH}.log"
	make >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	make install_sw >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	make clean >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1

	LOG_FILE=$(pwd)/iOS/${OPENSSL_VERSION}-iOS-${ARCH}.log
	touch ${LOG_FILE}

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="$(which clang) -arch ${ARCH}"

	printf "\e[1;36m[*] BUILDING ${OPENSSL_VERSION} FOR ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}\e[0m\n"

	#no-asm threads zlib-dynamic no-shared no-hw no-idea enable-rc5 enable-mdc2 enable-seed

	if [[ "${ARCH}" == "x86_64" ]]; then
		./Configure \
			no-asm \
			darwin64-x86_64-cc \
			--openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> ${LOG_FILE}
	else
		./Configure \
			iphoneos-cross \
			--openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> ${LOG_FILE}
	fi
	# add -isysroot to CC=
	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"

	NUM_JOBS=$(sysctl -n hw.activecpu)
	make -j ${NUM_JOBS} >> ${LOG_FILE} 2>&1
	make install_sw >> ${LOG_FILE} 2>&1
	make clean >> ${LOG_FILE} 2>&1
	popd > /dev/null
}

clean_log() {
	rm -rf "*.log" > /dev/null
}

printf "\e[1;36m[*] CLEANING UP\e[0m\n"
rm -rf iOS

clean_log

mkdir -p iOS/lib
mkdir -p iOS/include/

rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf $(pwd)/*/${OPENSSL_VERSION}-*.log

rm -rf "${OPENSSL_VERSION}"


if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	printf "\e[1;31m[X] OpenSSL Version ${OPENSSL_VERSION} is missing.\e[0m\n"
	exit 1
else
	printf "\e[1;36m[*] USING ${OPENSSL_VERSION}.tar.gz\e[0m\n"
fi

printf "\e[1;36m[*] UNPACKING OPENSSL\e[0m\n"
tar xfz "${OPENSSL_VERSION}.tar.gz"

printf "\e[1;36m[*] BUILDING OPENSSL iOS LIBRAIRES\e[0m\n"
buildIOS "armv7"
buildIOS "armv7s"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

cp -rf "/tmp/${OPENSSL_VERSION}-iOS-x86_64/include/openssl" "iOS/include/"

lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-armv7s/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
	-create -output iOS/lib/libcrypto.a

lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-armv7s/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
	-create -output iOS/lib/libssl.a

printf "\e[1;36m[*] CLEANING UP\e[0m\n"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}
clean_log

printf "\e[1;32m[*]FINISHED BUILDING OPENSSL\e[0m\n"

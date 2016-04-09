#!/bin/bash

set -e

# make sure we are in the proper working directory
pushd "$(dirname "$0")" > /dev/null

./clean.sh

echo
echo

printf "\e[1;32m[*] BUILDING OpenSSL\e[0m\n"
cd openssl
./openssl-build.sh
cd ..

echo
printf "\e[1;32m[*] BUILDING cURL\e[0m\n"
cd curl
./curl-build.sh
cd ..

echo
printf "\e[1;32m[*] CHECKING LIBRARIES\e[0m\n"
printf "\e[1;32m$(xcrun -sdk iphoneos lipo -info openssl/*/lib/*.a)\e[0m\n"
printf "\e[1;32m$(xcrun -sdk iphoneos lipo -info curl/lib*/*.a)\e[0m\n"

popd > /dev/null

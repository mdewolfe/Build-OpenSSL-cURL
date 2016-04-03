#!/bin/bash

set -e

./clean.sh

echo
echo

printf "\e[1;32m[*] BUILDING OPENSSL\e[0m\n"
cd openssl
./openssl-build.sh
cd ..

echo
printf "\e[1;32m[*] BUILDING CURL\e[0m\n"
cd curl
./libcurl-build.sh
cd ..

echo
printf "\e[1;32m[*] CHECKING LIBRARIES\e[0m\n"
printf "\e[1;32m$(xcrun -sdk iphoneos lipo -info openssl/*/lib/*.a)\e[0m\n"
printf "\e[1;32m$(xcrun -sdk iphoneos lipo -info curl/lib/*.a)\e[0m\n"

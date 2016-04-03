#!/bin/bash

printf "\e[1;36m*** CLEANING OpenSSL & cURL BUILDS ***\e[0m\n"
rm -fr \
	curl/curl-*.log \
	curl/include \
	curl/lib \
	openssl/iOS

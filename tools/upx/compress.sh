 #!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}
# check run user
if [[ ! `id -u` -eq 0 ]]; then
     echo "Please run this shell by root user!"
     exit 1;
 fi

export PATH=$PATH:$basepath/upx

#
# go build -ldflags "-s -w" 
# go get -u github.com/cloudflare/cfssl/cmd/...
# git clone https://github.com/upx/upx.git
# git clone https://github.com/stedolan/jq.git
# 
# compress file with upx
echo "Do You Want Compress Now? [Y]/n"
read confirm
if [[ ! "${confirm}" =~ ^[nN]$ ]]; then
    upx -9 -k $basepath/cfssl
    upx -9 -k $basepath/cfssljson
    upx -9 -k $basepath/jq
    rm -rf $basepath/*.~
fi
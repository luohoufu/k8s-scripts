 #!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}
# check run user
if [[ ! `id -u` -eq 0 ]]; then
     echo "Please run this shell by root user!"
     exit 1;
 fi
# add execute permission
 for f in $basepath/tools/*;do
    if test -f $f; then
        chmod +x $f
    fi
 done
# add execute permission for shell
find . -name '*.sh' -exec chmod +x {} \;
# dowload tool
if ! command_exists wget; then
    yum -y install wget > /dev/null 2>&1
fi
# net tool
if ! command_exists ifconfig; then
    yum -y install net-tools > /dev/null 2>&1
fi
# ntp tool
if ! command_exists ntpd; then
    yum -y install ntp > /dev/null 2>&1
fi
# ssh folder
if [ -d /root/.ssh ]; then
    mkdir -p /root/.ssh
fi
# ssl folder
if [ -d /ssl ]; then
    mkdir -p /ssl
fi

# shell runtime env
export PATH=$PATH:$basepath/tools

hostname=`cat $basepath/config.json |jq '.master'`
hostip=`cat $basepath/config.json |jq '.masterip'`

#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

if [ -f "/root/.vimrc" ]; then
    exit 0
fi
echo "setting vim,please wait......"
if [ -d /root/.vim_runtime ]; then
    rm -rf /root/.vim_runtime
fi
git clone git://github.com/amix/vimrc.git /root/.vim_runtime > /dev/null 2>&1
sh /root/.vim_runtime/install_basic_vimrc.sh > /dev/null 2>&1
if ! grep -q "vim" /root/.bashrc ; then
    sed -i "/alias mv/a\alias vi='vim'" /root/.bashrc
fi
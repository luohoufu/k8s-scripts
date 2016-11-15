#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# check run user
if [[ ! `id -u` -eq 0 ]]; then
    echo "Please run this shell by root user!"
    exit 1;
fi

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
ver=`jq -r '.proxy.ver' $json`
dest=`jq -r '.proxy.dest' $json`
cfg=$dest/nginx/conf/nginx.conf

# Create etcd.conf, etcd.service
user=nginx
name=nginx
data=/data/www
exefile=/usr/bin/nginx
service=/usr/lib/systemd/system/nginx.service

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "$name user" -d $data -M -r -s /sbin/nologin $user
fi

# check env
if ! command_exists patch; then
    yum -y install patch > /dev/null 2>&1
fi

if ! command_exists perl; then
    yum -y install perl > /dev/null 2>&1
fi

if ! command_exists ${exefile##*/}; then
    yum -y install readline-devel pcre-devel openssl-devel gcc > /dev/null 2>&1
fi

# check workdir
if [ ! -d "$data" ]; then
    mkdir -p $data
    for p in $data $dest; do
        chown -R $user:$user $p
    done
fi

echo "openresty install start......"
tmpdir=$(mktemp -d -t openresty.XXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"
curl -L -O https://openresty.org/download/openresty-$ver.tar.gz > /dev/null 2>&1
tar xzf openresty-$ver.tar.gz > /dev/null 2>&1
cd openresty-$ver

# for security i remove the openresty head tag
sed -i "s/${ver%.*}\"/2.0.0\"/" bundle/nginx-no_pool.patch
sed -i "s/openresty/ApiServer/" bundle/nginx-no_pool.patch
sed -i 's#"openresty/" NGINX_VERSION ".1"#"ApiServer/2.0.0"#' bundle/nginx-${ver%.*}/src/core/nginx.h
sed -i "s/openresty/ApiServer/" bundle/nginx-${ver%.*}/src/http/ngx_http_header_filter_module.c
sed -i "s/>nginx</>ApiServer</" bundle/nginx-${ver%.*}/src/http/ngx_http_special_response.c

# complie and install
./configure --prefix=$dest --with-luajit --with-http_stub_status_module > /dev/null 2>&1
gmake > /dev/null 2>&1
gmake install > /dev/null 2>&1

# setting path
if [ ! -d /usr/local/nginx ]; then
    ln -s $dest/nginx /usr/local/nginx
fi
fi [ ! -f /usr/bin/nginx ]; then
    ln -s /usr/local/nginx/sbin/nginx /usr/bin/nginx
fi

echo "openresty install complete......"

$name -v > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo "$name install success!"
else
    echo "$name install error!"
fi

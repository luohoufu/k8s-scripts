#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`; pwd)

# check run user
if [[ ! `id -u` -eq 0 ]]; then
    echo "Please run this shell by root user!"
    exit 1;
fi

if ! grep -q "master" /etc/hostname ; then
    echo "ERROR: This shell must run on master node!"
    exit 1
fi

export PATH=$PATH:$basepath/tools

data_dir=`cat $basepath/config/k8s.json |jq '.docker.registry.data'|sed 's/\"//g'`
cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

name=registry
data=$data_dir
exefile=/usr/bin/registry
cert=$cert_dir/client.pem
certkey=$cert_dir/client-key.pem
conf=/etc/docker/registry.yml
service=/usr/lib/systemd/system/registry.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check confdir
if [ ! -d "${conf%/*}" ]; then
     mkdir -p ${conf%/*}
fi

# check workdir
if [ ! -d "$data" ]; then
    mkdir -p $data
fi

# config file
cat <<EOF >$conf
version: 0.1
log:
  fields:
  service: registry
storage:
  cache:
    layerinfo: inmemory
  filesystem:
    rootdirectory: ${data%/*}
http:
  addr: :8443
  tls: 
    certificate: ${cert}
    key: ${certkey}
EOF

cat <<EOF >$service
[Unit]
Description=Docker Application Registry
Documentation=https://docs.docker.com
After=network.target

[Service]
ExecStart=/usr/bin/registry serve ${conf}
ExecReload=/bin/kill -s HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $name > /dev/null 2>&1
systemctl stop $name > /dev/null 2>&1
systemctl start $name > /dev/null 2>&1

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo "$name install success!"
else
    echo "$name install error!"
fi
#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

if [ -f /ssl/synced ]; then
    exit 0
fi

echo "gernerate ssl files and copy to all nodes,please wait......"
if [ ! -d /ssl ]; then
    mkdir -p /ssl
fi

export PATH=$PATH:$basepath/tools

#ssl with all nodes
if [ ! -f /ssl/ca.pem ]; then
    cfssl gencert -initca $basepath/config/ca-csr.json | cfssljson -bare /ssl/ca
fi

if [ ! -f /ssl/etcd.pem ]; then
    cfssl gencert -ca /ssl/ca.pem -ca-key certs/ca-key.pem -config $basepath/config/ca-k8s.json $basepath/config/req-csr.json | cfssljson -bare /ssl/etcd
fi

if [ ! -f /ssl/flanneld.pem ]; then
    cfssl gencert -ca /ssl/ca.pem -ca-key certs/ca-key.pem -config $basepath/config/ca-k8s.json $basepath/config/req-csr.json | cfssljson -bare /ssl/flanneld
fi

if [ ! -f /ssl/apiserver.pem ]; then
    cfssl gencert -ca /ssl/ca.pem -ca-key certs/ca-key.pem -config $basepath/config/ca-k8s.json $basepath/config/req-csr.json | cfssljson -bare /ssl/apiserver
fi

k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        continue
    fi
    expect $basepath/os/expect/expect_scp.sh $k8s_node_hostname $k8s_node_username $k8s_node_passwd > /dev/null 2>&1
    touch /ssl/synced
done

echo "......done"
#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
cert_dir=`jq -r '.cert.dir' $json`
ca_csr=`jq '.cert.cacsr' $json`
ca_cfg=`jq '.cert.cacfg' $json`
req_csr=`jq '.cert.reqcsr' $json`

k8s_node_username=`jq -r '.host.uname' $json`
k8s_node_passwd=`jq -r '.host.passwd' $json`
k8s_node_names=(`jq -r '.k8s.nodes[]| select(.type == "node")|.ip' $json`)

workdir=/tmp
trusted=/etc/pki/ca-trust/source/anchors/
check_path=$cert_dir/sync

if [ -f $check_path ]; then
    echo "Do you want run $0 again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

echo "gernerate etcd ssl files and copy to all nodes,please wait......"
if [ ! -d $cert_dir ]; then
    mkdir -p $cert_dir
fi

echo $ca_csr > $workdir/ca-csr.json
echo $ca_cfg > $workdir/ca-config.json
echo $req_csr > $workdir/req-csr.json

# ssl with all nodes
if [ ! -f $cert_dir/ca.pem ]; then
    ca=`cfssl gencert -loglevel 4 -initca "$workdir/ca-csr.json"`
    echo -ne `echo $ca|jq ".cert"|sed 's/\"//g'` > $cert_dir/ca.pem
    echo -ne `echo $ca|jq ".key"|sed 's/\"//g'` > $cert_dir/ca-key.pem
    echo -ne `echo $ca|jq ".csr"|sed 's/\"//g'` > $cert_dir/ca.csr
    #CA trusted 
    scp -r $cert_dir/ca.pem $trusted    
fi

for f in etcd flanneld server client; do
    if [ ! -f $cert_dir/$f.pem ]; then
        cert=`cfssl gencert -loglevel 4 -ca $cert_dir/ca.pem -ca-key $cert_dir/ca-key.pem -config "$workdir/ca-config.json" "$workdir/req-csr.json"`
        echo -ne `echo $cert|jq ".cert"|sed 's/\"//g'` > $cert_dir/$f.pem
        echo -ne `echo $cert|jq ".key"|sed 's/\"//g'` > $cert_dir/$f-key.pem
        echo -ne `echo $cert|jq ".csr"|sed 's/\"//g'` > $cert_dir/$f.csr
    fi
done

# sync ssl file to nodes
for ((i=0;i<${#k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    #CA trusted 
    scp -r $cert_dir/ca.pem $k8s_node_username@$k8s_node_hostname:$trusted > /dev/null 2>&1    
    scp -r $cert_dir $k8s_node_username@$k8s_node_hostname:/ > /dev/null 2>&1
done

# gernerate check_path
if [ ! -f $check_path ]; then
    touch $check_path
fi

echo "......done"
#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

export PATH=$PATH:$basepath/tools

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`
ca_csr=`cat $basepath/config/k8s.json |jq '.cert.cacsr'`
ca_cfg=`cat $basepath/config/k8s.json |jq '.cert.cacfg'`
req_csr=`cat $basepath/config/k8s.json |jq '.cert.reqcsr'`

workdir=/tmp
check_path=$cert_dir/sync

if [ -f $check_path ]; then
    echo "Do you want run $0 again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

echo "gernerate ssl files and copy to all nodes,please wait......"
if [ ! -d $cert_dir ]; then
    mkdir -p $cert_dir
fi

master_ip=`hostname -i`
bash $basepath/kubernetes/certs/make-ca-certs.sh "$master_ip" "IP:$master_ip,IP:172.16.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.dev"

echo $ca_csr > $workdir/ca-csr.json
echo $ca_cfg > $workdir/ca-config.json
echo $req_csr > $workdir/req-csr.json

# ssl with all nodes
if [ ! -f $cert_dir/etcdca.pem ]; then
    ca=`cfssl gencert -loglevel 4 -initca "$workdir/ca-csr.json"`
    echo -ne `echo $ca|jq ".cert"|sed 's/\"//g'` > $cert_dir/etcdca.pem
    echo -ne `echo $ca|jq ".key"|sed 's/\"//g'` > $cert_dir/etcdca-key.pem
    echo -ne `echo $ca|jq ".csr"|sed 's/\"//g'` > $cert_dir/etcdca.csr
fi

for f in etcd flanneld server client; do
    if [ ! -f $cert_dir/$f.pem ]; then
        cert=`cfssl gencert -loglevel 4 -ca $cert_dir/ca.pem -ca-key $cert_dir/ca-key.pem -config "$workdir/ca-config.json" "$workdir/req-csr.json"`
        echo -ne `echo $cert|jq ".cert"|sed 's/\"//g'` > $cert_dir/$f.pem
        echo -ne `echo $cert|jq ".key"|sed 's/\"//g'` > $cert_dir/$f-key.pem
        echo -ne `echo $cert|jq ".csr"|sed 's/\"//g'` > $cert_dir/$f.csr
    fi
done

k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        continue
    fi
    scp -r $cert_dir $k8s_node_username@$k8s_node_hostname:/ > /dev/null 2>&1
done

# gernerate check_path
if [ ! -f $check_path ]; then
    touch $check_path
fi

echo "......done"
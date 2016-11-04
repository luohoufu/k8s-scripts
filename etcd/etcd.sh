#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
etcd_node_names=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].name'|sed 's/\"//g'`
etcd_node_ips=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].ip'|sed 's/\"//g'`

arr_etcd_node_names=($(echo $etcd_node_names))
arr_etcd_node_ips=($(echo $etcd_node_ips))
for ((i=0;i<${#arr_etcd_node_ips[@]};i++));do
    if ip a |grep -q ${arr_etcd_node_ips[$i]}; then
        etcd_name=${arr_etcd_node_names[$i]}
        etcd_ip=${arr_etcd_node_ips[$i]}
    fi
done
etcd_cluster=`echo $etcd_node_names $etcd_node_ips|awk '{for (i = 1; i < NF/2; i++) printf("%s=https://%s:2380,",$i,$(i+NF/2));printf("%s=https://%s:2380",$i,$(i+NF/2))}'`
etcd_endpoints=`echo $etcd_node_names $etcd_node_ips|awk '{for (i = 1; i < NF-1; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$i)}'`
# Create etcd.conf, etcd.service
user=etcd
data=/var/lib/etcd
exefile=/usr/bin/etcd
cert=/ssl/etcd.pem
certkey=/ssl/etcd-key.pem
conf=/etc/etcd/etcd.conf
service=/usr/lib/systemd/system/etcd.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "Etcd User" -d $data -M -r -s /sbin/nologin $user
else
    rm -rf $data
fi

# check confdir
if [ ! -d "${conf%/*}" ]; then
     mkdir -p ${conf%/*}
fi

# check workdir
if [ ! -d "$data" ]; then
    mkdir -p $data
    for p in $data $exefile $cert $certkey ${conf%/*}; do
        chown -R $user:$user $p
    done
fi

# config file
cat <<EOF >$conf
# [member]
ETCD_NAME=${etcd_name}
ETCD_DATA_DIR="${data}/${etcd_name}"
#ETCD_SNAPSHOT_COUNTER="10000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
ETCD_LISTEN_PEER_URLS="https://${etcd_ip}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${etcd_ip}:2379,https://127.0.0.1:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${etcd_ip}:2380"
# if you use different ETCD_NAME (e.g. test), 
# set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="${etcd_cluster}"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="k8s-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://${etcd_ip}:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_SRV=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
#
#[proxy]
#ETCD_PROXY="off"
#
#[security]
ETCD_CA_FILE="/ssl/ca.pem"
ETCD_CERT_FILE="/ssl/etcd.pem"
ETCD_KEY_FILE="/ssl/etcd-key.pem"
ETCD_PEER_CA_FILE="/ssl/ca.pem"
ETCD_PEER_CERT_FILE="/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/ssl/etcd-key.pem"
EOF

cat <<EOF >$service
[Unit]
Description=Etcd Server
After=network.target

[Service]
Type=notify
User=etcd
WorkingDirectory=${data}
EnvironmentFile=-${conf}
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=\$(nproc) /usr/bin/etcd"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd

etcd --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi

#setting alias
if ! grep -q "etcdctl" /root/.bashrc ; then
    sed -i "/alias vi/a\alias etcdctl='etcdctl --ca-file=/ssl/ca.pem --cert-file=/ssl/etcd.pem --key-file=/ssl/etcd-key.pem --endpoints=$etcd_endpoints'" /root/.bashrc
fi
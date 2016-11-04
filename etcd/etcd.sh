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

 
arr_etcd_node_names=($(echo $k8s_node_names))
arr_etcd_node_ips=($(echo $k8s_node_ips))
for ((i=0;i<${#arr_k8s_node_ips[@]};i++));do
    if ip a |grep -q ${arr_k8s_node_ips[$i]}; then
        hostnamectl set-hostname ${arr_k8s_node_names[$i]}
    fi
done
etcd_endpoints=`echo $etcd_node_names $etcd_node_ips|awk  '{for (i = 1; i < NF/2; i++) printf("%s=https://%s:2380,",$i,$(i+NF/2));printf("%s=https://%s:2380",$i,$(i+NF/2))}'`
echo $etcd_name
echo $etcd_endpoints
exit 1

# Create etcd.conf, etcd.service
user=etcd
data=/var/lib/etcd
exefile=/usr/bin/etcd
conf=/etc/etcd/etcd.conf
service=/usr/lib/systemd/system/etcd.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check user
if id -u $user >/dev/null 2>&1; then
    userdel $user
    rm -rf $data
else
    useradd -c "Etcd User" -d $data -M -r -s /sbin/nologin $user
fi

# check workdir
if [ ! -d "$data" ]; then
    mkdir -p $data
    chown $user:$user $data
    chown $user:$user $exefile
fi

# config file
cat <<EOF >/etc/etcd/etcd.conf
# [member]
ETCD_NAME=default
ETCD_DATA_DIR="${etcd_data_dir}/default.etcd"
#ETCD_SNAPSHOT_COUNTER="10000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
#ETCD_LISTEN_PEER_URLS="http://localhost:2380,http://localhost:7001"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#
#[cluster]
#ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380,http://localhost:7001"
# if you use different ETCD_NAME (e.g. test), 
# set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
#ETCD_INITIAL_CLUSTER="default=http://localhost:2380,default=http://localhost:7001"
#ETCD_INITIAL_CLUSTER_STATE="new"
#ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_SRV=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
#
#[proxy]
#ETCD_PROXY="off"
#
#[security]
#ETCD_CA_FILE=""
#ETCD_CERT_FILE=""
#ETCD_KEY_FILE=""
#ETCD_PEER_CA_FILE=""
#ETCD_PEER_CERT_FILE=""
#ETCD_PEER_KEY_FILE=""   
EOF

cat <<EOF >//usr/lib/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${etcd_data_dir}
EnvironmentFile=-/opt/kubernetes/cfg/etcd.conf
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=\$(nproc) /opt/kubernetes/bin/etcd"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start etcd

etcd --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi

if ! grep -q "etcdctl" /root/.bashrc ; then
    sed -i "/alias vi/a\alias  etcdctl='etcdctl --ca-file=/ssl/ca.pem --cert-file=/ssl/etcd.pem --key-file=/ssl/etcd-key.pem --endpoints=$etcd_endpoints'" /root/.bashrc
fi
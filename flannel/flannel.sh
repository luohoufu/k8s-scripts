#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

flannel_key=`cat $basepath/config/k8s.json |jq '.flannel.key'|sed 's/\"//g'`
flannel_value=`cat $basepath/config/k8s.json |jq '.flannel.value'`

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

etcd_endpoints=`echo $etcd_node_ips|awk '{for (i = 1; i < NF; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$NF)}'`

# Create etcd.conf, etcd.service
user=flanneld
data=/var/log/flanneld
exefile=/usr/bin/flanneld
ca=/ssl/ca.pem
cert=/ssl/flanneld.pem
certkey=/ssl/flanneld-key.pem
conf=/etc/etcd/flanneld.conf
service=/usr/lib/systemd/system/flanneld.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "Flanneld User" -d $data -M -r -s /sbin/nologin $user
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

# check etcd flannel config
if [ $(etcdctl ls "$flannel_key"|grep "network"|wc -l) -eq 0 ]; then
     etcdctl set $flannel_key $flannel_value
fi

# config file
cat <<EOF >$conf
# etcd url location.  Point this to the server where etcd runs
FLANNEL_ETCD="-etcd-endpoints=${etcd_endpoints}"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNEL_ETCD_KEY="-etcd-prefix=${flannel_key}"

# etcd secure
FLANNEL_ETCD_SECURE="-etcd-cafile=${ca} -etcd-certfile=${cert} -etcd-keyfile=${certkey}"

# Any additional options that you want to pas
FLANNEL_OPTIONS="--iface=eth0 --logtostderr=false --log_dir=${data}/"
EOF

cat <<EOF >$service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
Before=docker.service

[Service]
Type=notify
User=${user}
EnvironmentFile=-${conf}
ExecStart=/usr/bin/bin/flanneld --ip-masq \${FLANNEL_ETCD} \${FLANNEL_ETCD_KEY} \${FLANNEL_ETCD_SECURE} \${FLANNEL_OPTIONS}
ExecStartPost=/usr/bin/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF
EOF

systemctl daemon-reload
systemctl enable etcd

flanneld --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi

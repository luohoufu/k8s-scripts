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

etcd_node_ips=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].ip'|sed 's/\"//g'`

etcd_endpoints=`echo $etcd_node_ips|awk '{for (i = 1; i < NF; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$NF)}'`

# Create etcd.conf, etcd.service
user=flanneld
name=flanneld
data=/var/log/flanneld
exefile=/usr/bin/flanneld
ca=/ssl/ca.pem
cert=/ssl/flanneld.pem
certkey=/ssl/flanneld-key.pem
conf=/etc/flanneld/flanneld.conf
service=/usr/lib/systemd/system/flanneld.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "$name user"  -d $data -M -r -s /sbin/nologin $user
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
if [ $(etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints ls "$flannel_key"|grep "network"|wc -l) -eq 0 ]; then
     etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints set $flannel_key $flannel_value
fi

# config file
cat <<EOF >$conf
# etcd url location.  Point this to the server where etcd runs
FLANNELD_ETCD_ENDPOINTS="${etcd_endpoints}"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNELD_ETCD_PREFIX="${flannel_key%/*}"

# etcd secure
FLANNELD_ETCD_CAFILE="${ca}"
FLANNELD_ETCD_CERTFILE="${cert}"
FLANNELD_ETCD_KEYFILE="${certkey}"

# Any additional options that you want to pas
FLANNELD_OPTIONS="--ip-masq=true --iface=eth0"
EOF

cat <<EOF >$service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=etcd.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=-${conf}
ExecStart=/usr/bin/flanneld -etcd-endpoints=\${FLANNELD_ETCD_ENDPOINTS} -etcd-prefix=\${FLANNELD_ETCD_PREFIX} -etcd-cafile=\${FLANNELD_ETCD_CAFILE} -etcd-certfile=\${FLANNELD_ETCD_CERTFILE} -etcd-keyfile=\${FLANNELD_ETCD_KEYFILE} \$FLANNELD_OPTIONS
ExecStartPost=/usr/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

systemctl daemon-reload
systemctl enable $name

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi

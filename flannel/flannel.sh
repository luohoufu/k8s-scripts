#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
cert_dir=`jq -r '.cert.dir' $json`
flannel_iface=`jq -r '.flannel.iface' $json`
flannel_key=`jq -r '.flannel.key' $json`
flannel_value=`jq -r '.flannel.value' $json`
etcd_node=`jq -r '.etcd.nodes[0].ip' $json`
etcd_node_ips=`jq -r '.etcd.nodes[].ip' $json`
etcd_endpoints=`echo $etcd_node_ips|awk '{for (i = 1; i < NF; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$NF)}'`

# Create flanneld.conf, flanneld.service
name=flanneld
exefile=/usr/bin/flanneld
data=/var/log/flanneld/
ca=$cert_dir/ca.pem
cert=$cert_dir/flanneld.pem
certkey=$cert_dir/flanneld-key.pem
certcsr=$cert_dir/flanneld.csr
conf=/etc/flanneld/flanneld.conf
service=/usr/lib/systemd/system/flanneld.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check confdir
if [ ! -d "${conf%/*}" ]; then
     mkdir -p ${conf%/*}
fi

# check datadir
if [ ! -d $data ]; then
     mkdir -p $data
fi

# check iface
if [ $(ip a |grep "flannel.1"|wc -l) -gt 0 ]; then
    ip link del "flannel.1"
fi

# check etcd flannel config
#if [ $(etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints ls "$flannel_key"|grep "network"|wc -l) -eq 0 ]; then
#     etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints set $flannel_key $flannel_value
#fi
res=`curl -s --cacert $ca --cert $cert --key $certkey -X GET https://$etcd_node:2379/v2/keys$flannel_key`
if [ $(echo $res |grep "errorCode"|wc -l) -eq 1 ]; then
    etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints set "$flannel_key" "$flannel_value" > /dev/null 2>&1
fi

# config file
cat <<EOF >$conf
# etcd url location.  Point this to the server where etcd runs
FLANNELD_ETCD_ENDPOINTS="--etcd-endpoints=${etcd_endpoints}"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNELD_ETCD_PREFIX="--etcd-prefix=${flannel_key%/*}"

# etcd secure
FLANNELD_ETCD_SECURE="--etcd-cafile=${ca} --etcd-certfile=${cert} --etcd-keyfile=${certkey}"

# Any additional options that you want to pas
FLANNELD_OPTIONS="--iface=${flannel_iface} --logtostderr=false --log_dir=/var/log/flanneld/"
EOF

FLANNELD_OPTS="  \\
                 \${FLANNELD_ETCD_ENDPOINTS} \\
                 \${FLANNELD_ETCD_PREFIX}    \\
                 \$FLANNELD_ETCD_SECURE      \\
                 \$FLANNELD_OPTIONS"

cat <<EOF >$service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
EnvironmentFile=-${conf}
ExecStart=/usr/bin/flanneld ${FLANNELD_OPTS}                         
ExecStartPost=/usr/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
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

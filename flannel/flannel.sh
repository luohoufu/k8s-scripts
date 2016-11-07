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

etcd_node=`cat $basepath/config/k8s.json |jq '.etcd.nodes[0].ip'|sed 's/\"//g'`

etcd_node_ips=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].ip'|sed 's/\"//g'`

etcd_endpoints=`echo $etcd_node_ips|awk '{for (i = 1; i < NF; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$NF)}'`

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

# Create flanneld.conf, flanneld.service
name=flanneld
exefile=/usr/bin/flanneld
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

# check etcd flannel config
#if [ $(etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints ls "$flannel_key"|grep "network"|wc -l) -eq 0 ]; then
if [ $(curl --cacert $ca --cert $cert --key $certkey-X GET https://$etcd_node:2379/v2/keys/$flannel_key |grep "network"|wc -l) -eq 0 ]; then
     etcdctl --ca-file=$ca --cert-file=$cert --key-file=$certkey --endpoints=$etcd_endpoints set $flannel_key $flannel_value
fi

# config file
cat <<EOF >$conf
# etcd url location.  Point this to the server where etcd runs
FLANNELD_ETCD_ENDPOINTS="-etcd-endpoints=${etcd_endpoints}"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNELD_ETCD_PREFIX="-etcd-prefix=${flannel_key%/*}"

# etcd secure
FLANNELD_ETCD_CAFILE="-etcd-cafile=${ca}"
FLANNELD_ETCD_CERTFILE="-etcd-certfile=${cert}"
FLANNELD_ETCD_KEYFILE="-etcd-keyfile=${certkey}"

# other setting
FLANNELD_IP_MASQ="--ip-masq=true"
FLANNELD_IFACE="--iface=eth0--iface=eth0"

# All options that you want to pas
FLANNELD_OPTS=" \${FLANNELD_ETCD_ENDPOINTS} \\
                \${FLANNELD_ETCD_PREFIX}    \\
                \${FLANNELD_ETCD_CAFILE}    \\
                \${FLANNELD_ETCD_CERTFILE}  \\
                \${FLANNELD_ETCD_KEYFILE}   \\
                \${FLANNELD_IP_MASQ}        \\
                \${FLANNELD_IFACE}"

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
ExecStart=/usr/bin/flanneld ${FLANNELD_OPTIONS}
ExecStartPost=/usr/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

systemctl daemon-reload
systemctl enable $name > /dev/null 2>&1

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi

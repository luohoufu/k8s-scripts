#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
domain=`jq -r '.k8s.domain' $json`
cfg=`jq -r '.k8s.cfg' $json`

# Create kube-dns.conf, kube-dns.service
user=kube
name=kube-dns
exefile=/usr/bin/kube-dns
data=/var/log/k8s/dns/
conf=/etc/kubernetes/dns.conf
service=/usr/lib/systemd/system/kube-dns.service

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
# --logtostderr=true: log to standard error instead of files
KUBE_LOGTOSTDERR="--logtostderr=false"

# --log_dir= save log info by file
KUBE_LOGDIR="--log_dir=${data}"

# --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"

# --dns-port=: port on which to serve DNS requests. (default 53)
KUBE_DNS_PORT="--dns-port=53"

# --domain="": domain under which to create names (default "cluster.local.")
KUBE_DOMAIN="--domain=${domain}"

# --kubeconfig="": Location of kubecfg file for access to kubernetes master service; 
# --kube-master-url overrides the URL part of this; if neither this nor --kube-master-url are provided, 
# defaults to service account tokens
KUBE_CONFIG="--kubecfg-file=${cfg}"
EOF

KUBE_DNS_OPTS="     \\
                    \${KUBE_LOGTOSTDERR}  \\
                    \${KUBE_LOGDIR}       \\
                    \${KUBE_LOG_LEVEL}    \\
                    \${KUBE_DNS_PORT}     \\
                    \${KUBE_DOMAIN}       \\
                    \${KUBE_CONFIG}"


cat <<EOF >$service
[Unit]
Description=Kubernetes DNS Server
Documentation=https://github.com/kubernetes/kubernetes
After=network.target
After=kube-apiserver.service

[Service]
EnvironmentFile=-${conf}
ExecStart=/usr/bin/kube-dns ${KUBE_DNS_OPTS}
Restart=on-failure

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

#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
cert_dir=`jq -r '.cert.dir' $json`
cfg=`jq -r '.k8s.cfg' $json`

node_ip=`hostname -i`

# Create kube-proxy.conf, kube-proxy.service
name=kube-proxy
exefile=/usr/bin/kube-proxy
data=/var/log/k8s/proxy/
ca=$cert_dir/ca.pem
cert=$cert_dir/client.pem
certkey=$cert_dir/client-key.pem
conf=/etc/kubernetes/proxy.conf
service=/usr/lib/systemd/system/kube-proxy.service

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
###
# kubernetes proxy config

# --logtostderr=true: log to standard error instead of files
KUBE_LOGTOSTDERR="--logtostderr=false"

# --log_dir= save log info by file
KUBE_LOGDIR="--log_dir=${data}"

# --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"

# --hostname-override="": If non-empty, will use this string as identification instead of the actual hostname.
NODE_HOSTNAME="--hostname-override=${node_ip}"

# --kubeconfig="": Path to a kubeconfig file, specifying how to connect to the API server. 
# --api-servers will be used for the location unless --require-kubeconfig is set. (default "/var/lib/kubelet/kubeconfig")
KUBE_CONFIG="--kubeconfig=${cfg}"

#--proxy-mode="": Which proxy mode to use: 'userspace' (older) or 'iptables' (faster).
KUBE_PROXY_MODE="--proxy-mode=iptables"
EOF

KUBE_PROXY_OPTS="   \\
                    \${KUBE_LOGTOSTDERR}       \\
                    \${KUBE_LOGDIR}            \\
                    \${KUBE_LOG_LEVEL}         \\
                    \${NODE_HOSTNAME}          \\
                    \${KUBE_CONFIG}            \\
                    \${KUBE_PROXY_MODE}"
cat <<EOF >$service
[Unit]
Description=Kubernetes Proxy
Documentation=https://github.com/kubernetes/kubernetes
After=network.target
After=docker.service

[Service]
EnvironmentFile=-${conf}
ExecStart=/usr/bin/kube-proxy ${KUBE_PROXY_OPTS}
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
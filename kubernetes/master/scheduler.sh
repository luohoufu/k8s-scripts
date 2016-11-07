#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        k8s_master=${arr_k8s_node_ips[$i]}
    fi
done

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

# Create kube-scheduler.conf, kube-scheduler.service
user=kube
name=kube-scheduler
exefile=/usr/bin/kube-scheduler
data=/var/log/k8s/scheduler
ca=$cert_dir/ca.pem
cert=$cert_dir/server.pem
certkey=$cert_dir/server-key.pem
certcsr=$cert_dir/server.csr
conf=/etc/kubernetes/scheduler.conf
service=/usr/lib/systemd/system/kube-scheduler.service

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
    for p in $data $exefile $cert $certkey $certcsr ${conf%/*}; do
        chown -R $user:$user $p
    done
fi

# config file
cat <<EOF >$conf
###
# kubernetes scheduler config

# --logtostderr=true: log to standard error instead of files
KUBE_LOGTOSTDERR="--logtostderr=true"

# --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"

KUBE_MASTER="--master=${k8s_master}:8080"

# Add your own!
KUBE_SCHEDULER_ARGS=""

EOF

KUBE_SCHEDULER_OPTS="   \${KUBE_LOGTOSTDERR}     \\
                        \${KUBE_LOG_LEVEL}       \\
                        \${KUBE_MASTER}          \\
                        \${KUBE_SCHEDULER_ARGS}"

cat <<EOF >$service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
After=network.target
After=kube-apiserver.service

[Service]
EnvironmentFile=-${conf}
ExecStart=/usr/bin/kube-scheduler ${KUBE_SCHEDULER_OPTS}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $name

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi
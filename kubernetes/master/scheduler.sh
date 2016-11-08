#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

# Create kube-scheduler.conf, kube-scheduler.service
user=kube
name=kube-scheduler
exefile=/usr/bin/kube-scheduler
data=/var/log/k8s/scheduler/
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
KUBE_LOGTOSTDERR="--logtostderr=false"

# --log_dir= save log info by file
KUBE_LOGDIR="--log_dir=${data}"

# --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"

KUBE_MASTER="--master=127.0.0.1:8080"

# Add your own!
KUBE_SCHEDULER_ARGS=""
EOF

KUBE_SCHEDULER_OPTS="   \${KUBE_LOGTOSTDERR}     \\
                        \${KUBE_LOGDIR}          \\
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
systemctl enable $name > /dev/null 2>&1
systemctl stop $name > /dev/null 2>&1
systemctl start $name > /dev/null 2>&1

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo "$name install success!"
else
    echo "$name install error!"
fi
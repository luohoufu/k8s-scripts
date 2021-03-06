#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
data=`jq -r '.docker.registry.data' $json`
fs_driver=`jq -r '.docker.registry.fsdriver' $json`

# Create docker.conf, docker.service
user=docker
name=docker
exefile=/usr/bin/docker
conf=/etc/docker/docker
net_conf=/run/flannel/docker
service=/usr/lib/systemd/system/docker.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "$name user" -d $data -M -r -s /sbin/nologin $user
fi

# check confdir
if [ ! -d "${conf%/*}" ]; then
     mkdir -p ${conf%/*}
fi

# check workdir
if [ ! -d "$data" ]; then
    mkdir -p $data
    for p in $data $exefile ${conf%/*}; do
        chown -R $user:$user $p
    done
fi

# config file
cat <<EOF >$conf
# /etc/docker/docker
# Modify these options if you want to change the way the docker daemon runs
OPTIONS="--storage-driver=${fs_driver} --graph=${data} --selinux-enabled=false"
DOCKER_CERT_PATH="/etc/docker"
EOF

cat <<EOF >$service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target
After=flanneld.service

[Service]
Type=notify
EnvironmentFile=-${conf}
EnvironmentFile=-${net_conf}
ExecStart=/usr/bin/dockerd \$OPTIONS \$DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process

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

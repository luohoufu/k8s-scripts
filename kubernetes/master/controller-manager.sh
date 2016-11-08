#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`
service_cluster_ip_range=`cat $basepath/config/k8s.json |jq '.k8s.svciprange'|sed 's/\"//g'`

# Create kube-controller-manager.conf, kube-controller-manager.service
user=kube
name=kube-controller-manager
exefile=/usr/bin/kube-controller-manager
data=/var/log/k8s/controller-manager/
ca=$cert_dir/ca.pem
cert=$cert_dir/server.pem
certkey=$cert_dir/server-key.pem
certcsr=$cert_dir/server.csr
conf=/etc/kubernetes/controller-manager.conf
service=/usr/lib/systemd/system/kube-controller-manager.service

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
KUBE_LOGTOSTDERR="--logtostderr=false"
KUBE_LOGDIR="--log_dir=${data}"
KUBE_LOG_LEVEL="--v=4"
KUBE_MASTER="--master=127.0.0.1:8080"
KUBE_NODE_CIDRS="--allocate-node-cidrs=true"
KUBE_CLUSTER_CIDR="--cluster-cidr==${service_cluster_ip_range}"

# --root-ca-file="": If set, this root certificate authority will be included in
# service account's token secret. This must be a valid PEM-encoded CA bundle.
KUBE_CONTROLLER_MANAGER_ROOT_CA_FILE="--root-ca-file=${ca}"

# --service-account-private-key-file="": Filename containing a PEM-encoded private
# RSA key used to sign service account tokens.
KUBE_CONTROLLER_MANAGER_SERVICE_ACCOUNT_PRIVATE_KEY_FILE="--service-account-private-key-file=${certkey}"
EOF

KUBE_CONTROLLER_MANAGER_OPTS="  \${KUBE_LOGTOSTDERR}  \\
                                \${KUBE_LOGDIR}       \\
                                \${KUBE_LOG_LEVEL}    \\
                                \${KUBE_MASTER}       \\
                                \${KUBE_NODE_CIDRS}   \\
                                \${KUBE_CLUSTER_CIDR} \\
                                \${KUBE_CONTROLLER_MANAGER_ROOT_CA_FILE} \\
                                \${KUBE_CONTROLLER_MANAGER_SERVICE_ACCOUNT_PRIVATE_KEY_FILE}"

cat <<EOF >$service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
After=network.target
After=kube-apiserver.service

[Service]
EnvironmentFile=-${conf}
ExecStart=/usr/bin/kube-controller-manager ${KUBE_CONTROLLER_MANAGER_OPTS}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $name > /dev/null 2>&1
systemctl start $name > /dev/null 2>&1

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo "$name install success!"
else
    echo "$name install error!"
fi

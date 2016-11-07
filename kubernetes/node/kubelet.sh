#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`
node_ip=`hostname -i`

# Create kubelet.conf, kubelet.service
name=kubelet
exefile=/usr/bin/kubelet
data=/var/log/k8s/kubelet/
ca=$cert_dir/ca.pem
cert=$cert_dir/client.pem
certkey=$cert_dir/client-key.pem
certcsr=$cert_dir/client.csr
cfg=/etc/kubernetes/kubecfg
conf=/etc/kubernetes/kubelet.conf
service=/usr/lib/systemd/system/kubelet.service

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
    for p in $data $exefile $cert $certkey $certcsr ${conf%/*}; do
        chown -R $user:$user $p
    done
fi

# config file
cat <<EOF >$conf
###
# kubernetes kubelet config

# --logtostderr=true: log to standard error instead of files
KUBE_LOGTOSTDERR="--logtostderr=false"

# --log_dir= save log info by file
KUBE_LOGDIR="--log_dir=${data}"

# --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"

# --address=0.0.0.0: The IP address for the Kubelet to serve on (set to 0.0.0.0 for all interfaces)
NODE_ADDRESS="--address=${node_ip}"

# --port=10250: The port for the Kubelet to serve on. Note that "kubectl logs" will not work if you set this flag.
NODE_PORT="--port=10250"

# --hostname-override="": If non-empty, will use this string as identification instead of the actual hostname.
NODE_HOSTNAME="--hostname-override=${node_ip}"

# --kubeconfig="": Path to a kubeconfig file, specifying how to connect to the API server. 
# --api-servers will be used for the location unless --require-kubeconfig is set. (default "/var/lib/kubelet/kubeconfig")
KUBE_CONFIG="--kubeconfig=${cfg}"

# --require-kubeconfig="": If true the Kubelet will exit if there are configuration errors, 
# and will ignore the value of --api-servers in favor of the server defined in the kubeconfig file.
KUBE_REQUIRE_CONFIG="--require-kubeconfig=true"

# --allow-privileged=false: If true, allow containers to request privileged mode. [default=false]
KUBE_ALLOW_PRIV="--allow-privileged=false"

# --pod-infra-container-image: The image whose network/ipc namespaces containers in each pod will use.
KUBE_POD_INFRA="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"

# Add your own!
KUBELET_ARGS=""
EOF

KUBELET_OPTS="   \${KUBE_LOGTOSTDERR}     \\
                    \${KUBE_LOG_LEVEL}       \\
                    \${NODE_ADDRESS}         \\
                    \${NODE_PORT}            \\
                    \${NODE_HOSTNAME}        \\
                    \${KUBELET_API_SERVER}   \\
                    \${KUBE_ALLOW_PRIV}      \\
                    \${KUBELET_ARGS}"

cat <<EOF >$service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=network.target
After=docker.service

[Service]
EnvironmentFile=-${conf}
ExecStart=/usr/bin/kubelet ${KUBELET_OPTS}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $name > /dev/null 2>&1

$name --version > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo 'install success!'
else
    echo 'install error!'
fi
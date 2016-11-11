#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

service_cluster_ip_range=`cat $basepath/config/k8s.json |jq '.k8s.iprange'|sed 's/\"//g'`
k8s_node_username=`cat $basepath/config/k8s.json |jq '.host.passwd'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.host.passwd'|sed 's/\"//g'`

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

etcd_node_ips=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].ip'|sed 's/\"//g'`
etcd_endpoints=`echo $etcd_node_ips|awk '{for (i = 1; i < NF; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$NF)}'`

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

# Create kube-apiserver.conf, kube-apiserver.service
user=kube
name=kube-apiserver
exefile=/usr/bin/kube-apiserver
data=/var/log/k8s/apiserver/

ca=$cert_dir/ca.pem
etcdcert=$cert_dir/etcd.pem
etcdcertkey=$cert_dir/etcd-key.pem

ca=$cert_dir/ca.pem
cert=$cert_dir/server.pem
certkey=$cert_dir/server-key.pem

conf=/etc/kubernetes/apiserver.conf
service=/usr/lib/systemd/system/kube-apiserver.service

# check excute 
if ! command_exists ${exefile##*/}; then
     echo "Please Copy `basename $exefile` to $exefile"
     exit 1;
fi

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "${name:0:4} user"  -d ${adata%/*/*} -M -r -s /sbin/nologin $user
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

# config file
cat <<EOF >$conf
# --logtostderr=true: log to standard error instead of files
KUBE_LOGTOSTDERR="--logtostderr=false"

# --log_dir= save log info by file
KUBE_LOGDIR="--log_dir=${data}"

# --v=0: log level for V logs
KUBE_LOG_LEVEL="--v=4"

# --etcd-servers=[]: List of etcd servers to watch (http://ip:port), 
# comma separated. Mutually exclusive with -etcd-config
KUBE_ETCD_SERVERS="--etcd-servers=${etcd_endpoints}"
KUBE_ETCD_CAFILE="--etcd-cafile=${ca}"
KUBE_ETCD_CERTFILE="--etcd-certfile=${etcdcert}"
KUBE_ETCD_KEYFILE="--etcd-keyfile=${etcdcertkey}"

# --insecure-bind-address=127.0.0.1: The IP address on which to serve the --insecure-port.
KUBE_API_ADDRESS="--bind-address=${k8s_master}"

# --insecure-port=8080: The port on which to serve unsecured, unauthenticated access.
KUBE_API_PORT="--secure-port=6443"

# --advertise-address=<nil>: The IP address on which to advertise 
# the apiserver to members of the cluster.
KUBE_ADVERTISE_ADDR="--advertise-address=${k8s_master}"

# --allow-privileged=false: If true, allow privileged containers.
KUBE_ALLOW_PRIV="--allow-privileged=false"

# --service-cluster-ip-range=<nil>: A CIDR notation IP range from which to assign service cluster IPs. 
# This must not overlap with any IP ranges assigned to nodes for pods.
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=${service_cluster_ip_range}"

# --admission-control="AlwaysAdmit": Ordered list of plug-ins 
# to do admission control of resources into cluster. 
# Comma-delimited list of: 
#   LimitRanger, AlwaysDeny, SecurityContextDeny, NamespaceExists, 
#   NamespaceLifecycle, NamespaceAutoProvision,
#   AlwaysAdmit, ServiceAccount, ResourceQuota, DefaultStorageClass
KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota"

# --client-ca-file="": If set, any request presenting a client certificate signed
# by one of the authorities in the client-ca-file is authenticated with an identity
# corresponding to the CommonName of the client certificate.
KUBE_API_CLIENT_CA_FILE="--client-ca-file=${ca}"

# --tls-cert-file="": File containing x509 Certificate for HTTPS.  (CA cert, if any,
# concatenated after server cert). If HTTPS serving is enabled, and --tls-cert-file
# and --tls-private-key-file are not provided, a self-signed certificate and key are
# generated for the public address and saved to /var/run/kubernetes.
KUBE_API_TLS_CERT_FILE="--tls-cert-file=${cert}"

# --tls-private-key-file="": File containing x509 private key matching --tls-cert-file.
KUBE_API_TLS_PRIVATE_KEY_FILE="--tls-private-key-file=${certkey}"

# --service-account-key-file="": File containing PEM-encoded x509 RSA private or public key, used to verify ServiceAccount tokens. 
# If unspecified, --tls-private-key-file is used.
KUBE_API_SERVICE_ACCOUNT_KEY_FILE="--service-account-key-file==${certkey}"
EOF

KUBE_APISERVER_OPTS="   \${KUBE_LOGTOSTDERR}         \\
                        \${KUBE_LOGDIR}              \\
                        \${KUBE_LOG_LEVEL}           \\
                        \${KUBE_ETCD_SERVERS}        \\
                        \${KUBE_ETCD_CAFILE}         \\
                        \${KUBE_ETCD_CERTFILE}       \\
                        \${KUBE_ETCD_KEYFILE}        \\
                        \${KUBE_API_ADDRESS}         \\
                        \${KUBE_API_PORT}            \\
                        \${KUBE_ADVERTISE_ADDR}      \\
                        \${KUBE_ALLOW_PRIV}          \\
                        \${KUBE_SERVICE_ADDRESSES}   \\
                        \${KUBE_ADMISSION_CONTROL}   \\
                        \${KUBE_API_CLIENT_CA_FILE}  \\
                        \${KUBE_API_TLS_CERT_FILE}   \\
                        \${KUBE_API_TLS_PRIVATE_KEY_FILE} \\
                        \${KUBE_API_SERVICE_ACCOUNT_KEY_FILE}"


cat <<EOF >$service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=network.target
After=etcd.service

[Service]
EnvironmentFile=-${conf}
ExecStart=/usr/bin/kube-apiserver ${KUBE_APISERVER_OPTS}
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

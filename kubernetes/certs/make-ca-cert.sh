#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# check run user
if [[ ! `id -u` -eq 0 ]]; then
    echo "Please run this shell by root user!"
    exit 1;
fi

DEBUG="${DEBUG:-false}"

if [ "${DEBUG}" == "true" ]; then
	set -x
fi

#
# ./make-ca-cert.sh <master_ip> IP:<master_ip>,IP:172.16.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.dev
#
cert_ip=$1
extra_sans=${2:-}
cert_group=${CERT_GROUP:-kube}

export PATH=$PATH:$basepath/tools

cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`


# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "$name user"  -d $data -M -r -s /sbin/nologin $user
fi

if [ ! -d $cert_dir ]; then
    mkdir -p $cert_dir
fi

sans="IP:${cert_ip}"
if [[ -n "${extra_sans}" ]]; then
  sans="${sans},${extra_sans}"
fi

tmpdir=$(mktemp -d -t kubernetes_cacert.XXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"

tar xzf easy-rsa.tar.gz > /dev/null 2>&1
cd easy-rsa-master/easyrsa3
./easyrsa init-pki > /dev/null 2>&1
./easyrsa --batch "--req-cn=$cert_ip@`date +%s`" build-ca nopass > /dev/null 2>&1
if [ $use_cn = "true" ]; then
    ./easyrsa build-server-full $cert_ip nopass > /dev/null 2>&1
    cp -p pki/issued/$cert_ip.crt "${cert_dir}/server.cert" > /dev/null 2>&1
    cp -p pki/private/$cert_ip.key "${cert_dir}/server.key" > /dev/null 2>&1
else
    ./easyrsa --subject-alt-name="${sans}" build-server-full kubernetes-master nopass > /dev/null 2>&1
    cp -p pki/issued/kubernetes-master.crt "${cert_dir}/server.cert" > /dev/null 2>&1
    cp -p pki/private/kubernetes-master.key "${cert_dir}/server.key" > /dev/null 2>&1
fi
./easyrsa build-client-full kubecfg nopass > /dev/null 2>&1
cp -p pki/ca.crt "${cert_dir}/ca.crt"
cp -p pki/issued/kubecfg.crt "${cert_dir}/kubecfg.crt"
cp -p pki/private/kubecfg.key "${cert_dir}/kubecfg.key"
# Make server certs accessible to apiserver.
chgrp $cert_group "${cert_dir}/server.key" "${cert_dir}/server.cert" "${cert_dir}/ca.crt"
chmod 660 "${cert_dir}/server.key" "${cert_dir}/server.cert" "${cert_dir}/ca.crt"
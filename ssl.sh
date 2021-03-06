 #!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}
# check run user
if [[ ! `id -u` -eq 0 ]]; then
     echo "Please run this shell by root user!"
     exit 1;
 fi

if ! grep -q "master" /etc/hostname ; then
    echo "ERROR: This shell must run on master node!"
    exit 1
fi

# check config
bash $basepath/os/check.sh

# execute shell file and check os information
for s in ssh ssl os; do
    bash $basepath/os/$s.sh
done

# rebooting system
echo "You must reboot system,Do You Want Reboot System Now? [Y]/n"
read confirm
if [[ ! "${confirm}" =~ ^[nN]$ ]]; then
    echo "Rebooting Now......"
    shutdown -r now
fi
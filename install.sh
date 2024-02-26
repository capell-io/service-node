#!/bin/bash

PACKAGE_VERSION=v0.0.1
PACKAGE_MD5=50e4711fddbc3aa453c568d8b386b86c

quitWithError() {
    echo -e "\033[31m$1\033[0m"
    exit 1
}

set -e

OS=`uname`
ARCH=`uname -m`

if [ x"$OS" != x"Linux" ]; then
    quitWithError "only supports linux system"
fi

if [ x"$ARCH" != x"x86_64" ]; then
    quitWithError "only supports x86_64"
fi

VMFLAG=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $VMFLAG -eq 0 ]; then
    quitWithError "virtualization not supported"
fi

TARGET_DIR=./service-node
if [ -d "$TARGET_DIR" ]; then
    quitWithError "directory already exists: $TARGET_DIR"
fi

if [ x"$BIND" == x"" ]; then
    quitWithError "missing BIND environment variable"
fi

echo "initialize the operating environment ..."

source /etc/os-release
case $ID in
    debian|ubuntu)
        #apt update
        apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
        ;;
    centos|fedora|rhel)
        #yum update
        yum install -y qemu-kvm libvirt bridge-utils
        ;;
    *)
        quitWithError "$ID is not supported"
        ;;
esac

echo 1 > /proc/sys/net/ipv4/ip_forward

set +e
systemctl stop firewalld > /dev/null 2>&1
systemctl disable firewalld > /dev/null 2>&1
set -e

systemctl enable libvirtd
systemctl start libvirtd


WORKER_PACKAGE_NAME=service_node_$PACKAGE_VERSION.tar.gz
WORKER_PACKAGE_PATH=/tmp/$WORKER_PACKAGE_NAME

downloadPackage() {
    echo "download package: $WORKER_PACKAGE_NAME"
    curl -# -L -o $WORKER_PACKAGE_PATH "https://github.com/capell-io/service-node/releases/download/$PACKAGE_VERSION/$WORKER_PACKAGE_NAME"

    CHECKSUM=`md5sum "$WORKER_PACKAGE_PATH"|cut -d" " -f1`
    if [ $CHECKSUM != $PACKAGE_MD5 ]; then
        rm -f $WORKER_PACKAGE_PATH
        quitWithError "md5 unmatch: $CHECKSUM,$PACKAGE_MD5"
    fi
}

if [ -f $WORKER_PACKAGE_PATH ]; then
    CHECKSUM=`md5sum "$WORKER_PACKAGE_PATH"|cut -d" " -f1`
    if [ $CHECKSUM == $PACKAGE_MD5 ]; then
        echo "found local package, skip download"
    else
        rm -f $WORKER_PACKAGE_PATH
        downloadPackage
    fi
else
    downloadPackage
fi


echo "install ..."

mkdir "$TARGET_DIR"
tar -C "$TARGET_DIR" -xzf $WORKER_PACKAGE_PATH

cd "$TARGET_DIR"
./service-node init --bind $BIND

SERVICE_CONF=/usr/lib/systemd/system/capell.service

if [ -f $SERVICE_CONF ]; then
    echo -e "\033[33mwarnning: service already exists\033[0m"
fi

echo "[Unit]
Description=Capell node
After=libvirtd.service

[Service]
Type=simple
User=root
Group=root
ExecStart=`pwd`/service-node

[Install]
WantedBy=multi-user.target" > $SERVICE_CONF

systemctl enable capell.service
systemctl restart capell.service

echo -e "\033[32minstallation is completed\033[0m"

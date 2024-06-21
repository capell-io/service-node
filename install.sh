#!/bin/bash

OS=`uname`
ARCH=`uname -m`

PACKAGE_VERSION=v0.0.2
PACKAGE_MD5=2dce6ae45a994166dae742e8427bc940

CAPELL_PACKAGE_NAME=capell_edge_server_linux_x86_64_${PACKAGE_VERSION}.zip
CAPELL_PACKAGE_PATH=/tmp/$CAPELL_PACKAGE_NAME

function quitWithError() {
    echo -e "\033[31m$1\033[0m"
    exit 1
}

function downloadPackage() {
    echo "download package: $CAPELL_PACKAGE_NAME"
    curl -#L -o $CAPELL_PACKAGE_PATH "https://github.com/capell-io/service-node/releases/download/$PACKAGE_VERSION/$CAPELL_PACKAGE_NAME"

    CHECKSUM=`md5sum "$CAPELL_PACKAGE_PATH"|cut -d" " -f1`
    if [ $CHECKSUM != $PACKAGE_MD5 ]; then
        rm -f $CAPELL_PACKAGE_PATH
        quitWithError "md5 unmatch: $CHECKSUM,$PACKAGE_MD5"
    fi
}

if [ x"$OS" != x"Linux" ]; then
    quitWithError "only supports linux system"
fi
if [ x"$ARCH" != x"x86_64" ]; then
    quitWithError "only supports x86_64"
fi
if [ x"$UID" != x"0" ]; then
   quitWithError "must run as root"
fi
if [ x"$BIND" == x"" ]; then
    quitWithError "missing BIND environment variable"
fi

if [ -f $CAPELL_PACKAGE_PATH ]; then
    CHECKSUM=`md5sum "$CAPELL_PACKAGE_PATH"|cut -d" " -f1`
    if [ $CHECKSUM == $PACKAGE_MD5 ]; then
        echo "found local package, skip download"
    else
        rm -f $CAPELL_PACKAGE_PATH
        downloadPackage
    fi
else
    downloadPackage
fi

if ! unzip -v > /dev/null 2>&1; then
    source /etc/os-release
    case $ID in
        debian|ubuntu)
            apt update
            apt install -y unzip
            ;;
        centos|fedora|rhel)
            yum update
            yum install -y unzip
            ;;
        *)
            quitWithError "$ID is not supported"
            ;;
    esac
fi

echo "install ..."
unzip -o $CAPELL_PACKAGE_PATH

SERVICE_CONF=/usr/lib/systemd/system/capell.service

if [ -f $SERVICE_CONF ]; then
    echo -e "\033[33mwarnning: service already exists\033[0m"
fi

echo "[Unit]
Description=Capell edge node
After=libvirtd.service docker.service

[Service]
Type=simple
User=root
Group=root
ExecStart=`pwd`/capell-edge-server --bind $BIND
Restart=on-failure

[Install]
WantedBy=multi-user.target" > $SERVICE_CONF

systemctl enable capell.service
systemctl restart capell.service

echo -e "\033[32minstallation is completed\033[0m"

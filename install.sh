#!/bin/bash

export PATH="/usr/bin:$PATH"
set -e
OS=`uname | tr '[:upper:]' '[:lower:]'`
ARCH=`uname -m`

PACKAGE_VERSION=v0.0.15
CAPELL_PACKAGE_NAME=capell_edge_server_${OS}_${ARCH}_${PACKAGE_VERSION}.zip
CAPELL_PACKAGE_PATH=/tmp/$CAPELL_PACKAGE_NAME

function quitWithError() {
    echo -e "\033[31m$1\033[0m"
    exit 1
}


if [ x"$OS" != x"linux" ] && [ x"$OS" != x"darwin" ]; then
    quitWithError "system not supported"
fi
if [ x"$OS" == x"linux" ]; then
    if [ x"$ARCH" != x"x86_64" ] && [ x"$ARCH" != x"aarch64" ]; then
        quitWithError "only supports x86_64 and aarch64"
    fi
    if [ x"$UID" != x"0" ]; then
        quitWithError "must run as root"
    fi
fi
if [ x"$BIND" == x"" ]; then
    quitWithError "missing BIND environment variable"
fi

if [ -f $CAPELL_PACKAGE_PATH ]; then
    rm -f $CAPELL_PACKAGE_PATH
fi

echo "download package: $CAPELL_PACKAGE_NAME"
echo "https://github.com/capell-io/service-node/releases/download/$PACKAGE_VERSION/$CAPELL_PACKAGE_NAME"
curl -#L -o $CAPELL_PACKAGE_PATH "https://github.com/capell-io/service-node/releases/download/$PACKAGE_VERSION/$CAPELL_PACKAGE_NAME"

if [ x"$OS" == x"linux" ]; then
    if ! unzip -v > /dev/null 2>&1; then
        source /etc/os-release
        case $ID in
            debian|ubuntu)
                apt -y update
                apt install -y unzip
                ;;
            centos|fedora|rhel)
                yum -y update
                yum install -y unzip
                ;;
            *)
                quitWithError "$ID is not supported"
                ;;
        esac
    fi
fi

echo "install ..."
unzip -o $CAPELL_PACKAGE_PATH

if [ x"$OS" == x"linux" ]; then
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
Environment=EDGE_DIRECT_JOIN_ORDER=1
Environment=CAPELL_MODE=dev
ExecStart=`pwd`/capell-edge-server --bind $BIND
Restart=on-failure

[Install]
WantedBy=multi-user.target" > $SERVICE_CONF

    systemctl enable capell.service
    systemctl restart capell.service
else
    if [ -f edge.pid ]; then
        LAST_PID=`cat edge.pid`
        echo "last edge pid: $LAST_PID"

        EDGE_PID=`ps -ef | grep capell-edge-server | grep -v "grep" | awk '{print $2}'`
        for PID in $EDGE_PID
        do
            if [ x"$LAST_PID" == x"$PID" ]; then 
                kill -9 $PID  
                echo "kill: $PID"
            fi
        done
    fi
    CAPELL_MODE=dev EDGE_DIRECT_JOIN_ORDER=1 ./capell-edge-server --bind $BIND -d
fi

echo -e "\033[32minstallation is completed\033[0m"

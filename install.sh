#!/bin/bash

VERSION=v0.0.1
WORKER_PACKAGE_NAME=service_node_$VERSION.tar.gz
WORKER_PACKAGE_PATH=/tmp/$WORKER_PACKAGE_NAME

echo "download file: $WORKER_PACKAGE_NAME"
if [ -f $WORKER_PACKAGE_PATH ]; then
    rm -f $WORKER_PACKAGE_PATH
fi
curl -# -L -o $WORKER_PACKAGE_PATH "https://github.com/capell-io/service-node/releases/download/$VERSION/$WORKER_PACKAGE_NAME"


echo "install ..."

TARGET_DIR=./service-node
if [ ! -d "$TARGET_DIR" ]; then
    mkdir "$TARGET_DIR"
fi

DATA_DIR=./service-node/data
if [ -d $DATA_DIR ]; then
    echo -e "\033[31mdirectory already exists: $DATA_DIR \033[0m"
fi

tar -C "$TARGET_DIR" -xzf $WORKER_PACKAGE_PATH

echo "clear temporary file ..."
rm -f $WORKER_PACKAGE_PATH

cd "$TARGET_DIR"

./service-node init --bind $BIND
if [ $? -ne 0 ]; then
    echo -e "\033[31minit node failed\033[0m"
    exit 1
fi

SERVICE_CONF=/usr/lib/systemd/system/capell.service

if [ -f $SERVICE_CONF ]; then
    echo -e "\033[31mservice already exists\033[0m"
else
    echo "[Unit]
Description=Capell node

[Service]
Type=simple
User=root
Group=root
ExecStart=`pwd`/service-node

[Install]
WantedBy=multi-user.target" > $SERVICE_CONF

    systemctl enable capell.service
    echo "installed as service"
fi

systemctl start capell.service

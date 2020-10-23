#!/bin/bash -x

#Node Exporter Image
IMAGE_LOCATION="quay.io/prometheus/node-exporter:v1.0.1"
#Script will use buysbox location to determine process uid mapping,can be any linux container that supports proc
BUSYBOX_LOCATION="docker.io/library/busybox"
#FOR ROOTLESS Podman, UID podman should run container as
PODMAN_USER="1000"
#UID inside the container being used by process
CONTAINER_USER="1001"
EXPORTER_PORT="9100"
CONTAINER_NAME="Node_Exporter"
SYSTEMD_ENABLE=True
echo "Will run podman commands as USERNAME:$(id -un $PODMAN_USER) ID:$PODMAN_USER"

#Get UID Mapping inside Container Process
echo "Obtaining User Namespace UID Mapping"
outputline=$(sudo -u \#$PODMAN_USER -H sh -c "podman run -u 1001 busybox cat /proc/self/uid_map | tail -n 1")
outputarray=($outputline)
uid=$(( $CONTAINER_USER + ${outputarray[1]}-${outputarray[0]} ))
echo "User $CONTAINER_USER will be available as UID $uid on your host, make sure to change ownership of any required folders to that"

#Start Node_Exporter Container
sudo -u \#$PODMAN_USER -H sh -c "podman run -d --memory 1000m --name $CONTAINER_NAME --network host --expose $EXPORTER_PORT $IMAGE_LOCATION"

#Check Node Exporter Status
if sudo -u '#1000' -H sh -c 'podman ps -a | grep Node | grep Up'
then
        echo "$CONTAINER_NAME looks up"
else
        echo "$CONTAINER_NAME might be down"
fi

#Create Systemd Start File
if [ $SYSTEMD_ENABLE == "True" ]
then

#Enable Systemd Selinux Permissions
echo "Please note selinux permissions must be enabled for systemd containers e.g sudo setsebool -P container_manage_cgroup on"
sudo -u '#1000' -H sh -c "podman generate systemd --restart-policy=always -t 1 -f -n $CONTAINER_NAME"
sudo mv ./container-$CONTAINER_NAME.service /etc/systemd/system/container-$CONTAINER_NAME.service
sudo chown root:root /etc/systemd/system/container-$CONTAINER_NAME.service
sudo chmod ugo+rwx /etc/systemd/system/container-$CONTAINER_NAME.service
fi

#Enable Systemd Service
sudo systemctl daemon-reload
sudo systemctl enable container-$CONTAINER_NAME.service

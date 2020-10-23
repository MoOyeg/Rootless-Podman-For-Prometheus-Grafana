#!/bin/bash

#Prometheus Image
IMAGE_LOCATION="quay.io/prometheus/prometheus:v2.21.0"
#Script will use buysbox location to determine process uid mapping,can be any linux container that supports proc
BUSYBOX_LOCATION="docker.io/library/busybox"
#FOR ROOTLESS Podman, UID podman should run container as
PODMAN_USER="1000"
#UID inside the container being used by process
CONTAINER_USER="1000"
PROMETHEUS_PORT="8081"                                                                                                                                                                                                                       CONTAINER_NAME="prometheus"
#Create Systemd service to allow container be run as a service
SYSTEMD_ENABLE=True
#Create User for UID Mapping in Host for Easier Tracability
USER_CREATE=True
USER_NAME="prometheus"
#Folder on Host(Must Exist) to Store Prometheus Configuration, Script will attempt to change owner to $CONTAINER_USER user host mapping
CONFIG_FOLDER="/etc/prometheus"                                                                                                                                                                                                              #Folder on Host(Must Exist) to Store Prometheus TSDB Data, Script will attempt to change owner to $CONTAINER_USER user host mapping                                                                                                          PROMETHEUS_TSDB_STORE="/mnt/disk-nvme1/prometheus"
#Location in Container to mount storage
STORE_LOCATION="/var/www"
#Get Sample configuration from github
SAMPLE_CONFIGURATION="True"


#Script Start
echo "Will run podman commands as USERNAME:$(id -un $PODMAN_USER) ID:$PODMAN_USER"

#Get UID Mapping inside Container Process
echo "Obtaining User Namespace UID Mapping"
outputline=$(sudo -u \#$PODMAN_USER -H sh -c "podman run -u 1001 busybox cat /proc/self/uid_map | tail -n 1")
outputarray=($outputline)
uid=$(( $CONTAINER_USER + ${outputarray[1]}-${outputarray[0]} ))

#Creating User for UID
echo "User $CONTAINER_USER will be available as UID $uid on your host, make sure to change ownership of any required folders to that"
if [ $USER_CREATE == "True" ]
then
   #Check if User Already Exists
   if getent passwd $uid
   then
           echo "User with UID $uid exists"
   else
            echo "Creating User and Group with uid $uid"
            sudo groupadd -g $uid $USER_NAME
            sudo useradd -M -r -s /bin/false -u $uid -g $uid $USER_NAME
            echo "Created User and Group with uid $uid"
   fi

fi

#Change folder ownerships
echo "Changing ownership of $CONFIG_FOLDER to being owned by $USER_NAME"
sudo chown $USER_NAME:$USER_NAME $CONFIG_FOLDER
echo "Changed ownership of $CONFIG_FOLDER to being owned by $USER_NAME"


echo "Changing ownership of $PROMETHEUS_TSDB_STORE to being owned by $USER_NAME"
sudo chown $USER_NAME:$USER_NAME $PROMETHEUS_TSDB_STORE
echo "Changed ownership of $PROMETHEUS_TSDB_STORE to being owned by $USER_NAME"

#Get Sample Configuration
if [ $SAMPLE_CONFIGURATION == "True" ]
then
   sudo -u $USER_NAME -H sh -c "curl -O https://raw.githubusercontent.com/MoOyeg/Podman-PrometheusGrafana/main/prometheus.yml > $CONFIG_FOLDER/prometheus.yml"
fi


#Start Prometheus Container
echo "Starting Container $CONTAINER_NAME"
sudo -u \#$PODMAN_USER -H sh -c "podman run -d -u $CONTAINER_USER  --volume $CONFIG_FOLDER:/etc/prometheus --volume $PROMETHEUS_TSDB_STORE:$STORE_LOCATION:Z --expose $PROMETHEUS_PORT --network host --name prometheus --entrypoint "/bin/prometheus" quay.io/prometheus/prometheus:v2.21.0 --config.file=/etc/prometheus/prometheus.yml --web.listen-address=0.0.0.0:8080 --storage.tsdb.path /var/www"
echo "Container $CONTAINER_NAME created"

#Check Node Exporter Status
if sudo -u '#1000' -H sh -c 'podman ps -a | grep Node | grep Up'
then
        echo "$CONTAINER_NAME looks up"
else
        echo "$CONTAINER_NAME might be down"
fi


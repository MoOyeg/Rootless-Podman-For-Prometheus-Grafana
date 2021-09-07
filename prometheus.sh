#!/bin/bash -x
#Script will use buysbox location to determine process uid mapping,can be any linux container that supports proc
#Script uses different uids inside and outside container if you want to use the same uid use the "--userns=keep-id" flag for podman


#Prometheus Image
IMAGE_LOCATION="quay.io/prometheus/prometheus:v2.21.0"
#Script will use buysbox location to determine process uid mapping,can be any linux container that supports proc
BUSYBOX_LOCATION="docker.io/library/busybox"
#FOR ROOTLESS Podman, UID podman should run container as
PODMAN_USER="1000"
#UID inside the container being used by process
CONTAINER_USER="1000"
PROMETHEUS_PORT="8081"
CONTAINER_NAME="prometheus"
#Create Systemd service to allow container be run as a service
SYSTEMD_ENABLE=True
#Create User for UID Mapping in Host for Easier Tracability
USER_CREATE=True
USER_NAME="prometheus"
#Folder on Host(Must Exist) to Store Prometheus Configuration, Script will attempt to change owner to $CONTAINER_USER user host mapping 
CONFIG_FOLDER="/etc/prometheus"
#Folder on Host(Must Exist) to Store Prometheus TSDB Data, Script will attempt to change owner to $CONTAINER_USER user host mapping
PROMETHEUS_TSDB_STORE="/tmp/prometheus"
#Location in Container to mount storage
STORE_LOCATION="/var/www"
#Get Sample configuration from github
SAMPLE_CONFIGURATION="True"
#Enable and Open firewall Service
FIREWALL="True"

### Functions ####

#Function to Check if folder exists and try to create it
dir_exists() {
  [ -d $1 ] && echo "Directory $1 exists." || ( mkdir -p $1 || ( echo "Error: Directory $1 does not exist or Could not be created."))

  [ ! -d $1 ] && exit 1

}

#Check if Container exists and delete it if it does
container_exists() {
  container_id=$(sudo -u \#$PODMAN_USER -H sh -c "podman ps -a --filter \"name=$CONTAINER_NAME\" --quiet")
  [ -n $container_id ] && (sudo -u \#$PODMAN_USER -H sh -c "podman kill $container_id; podman rm $container_id")
}


####  Script Start #####
PODMAN_USERNAME=$(id -un $PODMAN_USER)
echo "Will run podman commands as USERNAME:$PODMAN_USERNAME ID:$PODMAN_USER"


#Get UID Mapping inside Container Process
echo "Obtaining User Namespace UID Mapping"
outputline=$(sudo -u \#$PODMAN_USER -H sh -c "podman run -u 1001 $BUSYBOX_LOCATION cat /proc/self/uid_map | tail -n 1")
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
dir_exists $CONFIG_FOLDER
dir_exists $PROMETHEUS_TSDB_STORE
echo "Changing ownership of $CONFIG_FOLDER to being owned by $USER_NAME"
sudo chown $(id -un $uid):$(id -un $uid) $CONFIG_FOLDER
echo "Changed ownership of $CONFIG_FOLDER to being owned by $USER_NAME"


echo "Changing ownership of $PROMETHEUS_TSDB_STORE to being owned by $USER_NAME"
sudo chown $(id -un $uid):$(id -un $uid) $PROMETHEUS_TSDB_STORE
echo "Changed ownership of $PROMETHEUS_TSDB_STORE to being owned by $USER_NAME"

#Get Sample Configuration
if [ $SAMPLE_CONFIGURATION == "True" ]
then
   sudo -u $USER_NAME -H sh -c "curl -o $CONFIG_FOLDER/prometheus.yml https://raw.githubusercontent.com/MoOyeg/Podman-PrometheusGrafana/main/prometheus.yml"
fi


#Start Prometheus Container
container_exists
echo "Starting Container $CONTAINER_NAME"
sudo -u \#$PODMAN_USER -H sh -c "podman run -d -u $CONTAINER_USER --cpus=2.0 --memory 2000m  --volume $CONFIG_FOLDER:/etc/prometheus --volume $PROMETHEUS_TSDB_STORE:$STORE_LOCATION:Z --expose $PROMETHEUS_PORT --network host --name $CONTAINER_NAME $IMAGE_LOCATION --config.file=$CONFIG_FOLDER/prometheus.yml --web.listen-address=0.0.0.0:$PROMETHEUS_PORT --storage.tsdb.path $STORE_LOCATION"
echo "Container $CONTAINER_NAME created"

#Check Prometheus Status
if sudo -u \#$PODMAN_USER -H sh -c 'podman ps -a | grep prometheus | grep Up' 
then
	echo "$CONTAINER_NAME looks up"
else
	echo "$CONTAINER_NAME might be down"
fi
#Create Systemd Start File
if [ $SYSTEMD_ENABLE == "True" ]
then
   #Check if systemd folder exists
	dir_exists "/home/$PODMAN_USERNAME/.config/systemd/user/"

	#Enable Systemd Selinux Permissions
	#echo "Please note selinux permissions must be enabled for systemd containers e.g sudo setsebool -P container_manage_cgroup on"
	#if the systemctl --user command 
	sudo -i -u \#$PODMAN_USER bash << EOF
    echo "Creating systemd file to /home/$PODMAN_USERNAME/.config/systemd/user/container-$CONTAINER_NAME.service"
    podman generate systemd  -t 5 -n $CONTAINER_NAME > /home/$PODMAN_USERNAME/.config/systemd/user/container-$CONTAINER_NAME.service
    echo "Copied systemd file to /home/$PODMAN_USERNAME/.config/systemd/user/container-$CONTAINER_NAME.service"
    export XDG_RUNTIME_DIR="/run/user/$UID"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    systemctl --user daemon-reload
    systemctl --user enable container-$CONTAINER_NAME.service
    #systemctl --user restart container-$CONTAINER_NAME.service
EOF

sudo loginctl enable-linger $(id -un $PODMAN_USER)
fi

#Enable Firewall Service and Port
if [ $FIREWALL == "True" ]
then
	sudo firewall-cmd --permanent --new-service=container-$CONTAINER_NAME
	sudo firewall-cmd --permanent --service=container-$CONTAINER_NAME --set-description="Service to run Prometheus via container-$CONTAINER_NAME, Started by User:$(id -un $PODMAN_USER)"
	sudo firewall-cmd --permanent --service=container-$CONTAINER_NAME --set-short="container-$CONTAINER_NAME"
	sudo firewall-cmd --permanent --service=container-$CONTAINER_NAME --add-port="$PROMETHEUS_PORT/tcp"
	sudo firewall-cmd --zone=public --add-service=container-$CONTAINER_NAME
	sudo firewall-cmd --zone=public --permanent --add-service=container-$CONTAINER_NAME
	sudo firewall-cmd --zone=FedoraWorkstation --permanent --add-service=container-$CONTAINER_NAME
	sudo firewall-cmd --zone=FedoraWorkstation --add-service=container-$CONTAINER_NAME
	sudo firewall-cmd --reload
fi
echo "Complete"

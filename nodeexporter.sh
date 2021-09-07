#!/bin/bash 
#Script will use buysbox location to determine process uid mapping,can be any linux container that supports proc
#Script uses different uids inside and outside container if you want to use the same uid use the "--userns=keep-id" flag for podman

#Node Exporter Image
IMAGE_LOCATION="quay.io/prometheus/node-exporter:v1.0.1"
#Script will use buysbox location to determine process uid mapping,can be any linux container that supports proc
BUSYBOX_LOCATION="docker.io/library/busybox"
#FOR ROOTLESS Podman, UID podman should run container as
PODMAN_USER="1000"
#UID inside the container being used by process
CONTAINER_USER="1001"
EXPORTER_PORT="9100"
CONTAINER_NAME="node-exporter"
#Create Systemd service to allow container be run as a service
SYSTEMD_ENABLE="True"
#Create User for UID MApping in Host for Easier Tracability
USER_CREATE="True"
USER_NAME="node-exporter"
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
	

#Start Node_Exporter Container
echo "Starting Container $CONTAINER_NAME"
sudo -u \#$PODMAN_USER -H sh -c "podman run -d -u $CONTAINER_USER --cpus=2.0 --memory 2000m --name $CONTAINER_NAME --network host --expose $EXPORTER_PORT $IMAGE_LOCATION"
echo "Container $CONTAINER_NAME created"

#Check Node Exporter Status
if sudo -u \#$PODMAN_USER -H sh -c 'podman ps -a | grep Node | grep Up' 
then
	echo "$CONTAINER_NAME looks up"
else
	echo "$CONTAINER_NAME might be down"
fi

#Create Systemd Start File
if [ $SYSTEMD_ENABLE == "True" ]
then

#Check if systemd folder exists and create if not
[ ! -d "/home/$PODMAN_USERNAME/.config/systemd/user/" ] && sudo -u \#$PODMAN_USER -H sh -c "mkdir -p /home/$PODMAN_USERNAME/.config/systemd/user/"

#Enable Systemd Selinux Permissions
#echo "Please note selinux permissions must be enabled for systemd containers e.g sudo setsebool -P container_manage_cgroup on"
#if the systemctl --user command 
sudo -i -u \#$PODMAN_USER bash << EOF
echo "Creating systemd file to /home/$PODMAN_USERNAME/.config/systemd/user/container-$CONTAINER_NAME.service"
podman generate systemd  -t 5 -n $CONTAINER_NAME > /home/$PODMAN_USERNAME/.config/systemd/user/container-$CONTAINER_NAME.service
echo "Copied systemd file to /home/$PODMAN_USERNAME/.config/systemd/user/container-$CONTAINER_NAME.service"
sleep 5
EOF

#Enable and Restart Container Services
sudo machinectl shell --uid=$PODMAN_USERNAME .host /usr/bin/systemctl --user daemon-reload
sudo machinectl shell --uid=$PODMAN_USERNAME .host /usr/bin/systemctl --user enable container-$CONTAINER_NAME.service
sudo machinectl shell --uid=$PODMAN_USERNAME .host /usr/bin/systemctl --user stop container-$CONTAINER_NAME.service
sudo machinectl shell --uid=$PODMAN_USERNAME .host /usr/bin/systemctl --user restart container-$CONTAINER_NAME.service
sudo loginctl enable-linger $(id -un $PODMAN_USER)
fi

#Enable Firewall Service and Port
if [ $FIREWALL == "True" ]
then
sudo firewall-cmd --permanent --new-service=container-$CONTAINER_NAME
sudo firewall-cmd --permanent --service=container-$CONTAINER_NAME --set-description="Service to run Node Exporter via container-$CONTAINER_NAME, Started by User:$(id -un $PODMAN_USER)"
sudo firewall-cmd --permanent --service=container-$CONTAINER_NAME --set-short="container-$CONTAINER_NAME"
sudo firewall-cmd --permanent --service=container-$CONTAINER_NAME --add-port="$EXPORTER_PORT/tcp"
sudo firewall-cmd --zone=public --add-service=container-$CONTAINER_NAME
sudo firewall-cmd --zone=public --permanent --add-service=container-$CONTAINER_NAME
sudo firewall-cmd --zone=FedoraWorkstation --permanent --add-service=container-$CONTAINER_NAME
sudo firewall-cmd --zone=FedoraWorkstation --add-service=container-$CONTAINER_NAME
sudo firewall-cmd --reload
fi
echo "Complete"

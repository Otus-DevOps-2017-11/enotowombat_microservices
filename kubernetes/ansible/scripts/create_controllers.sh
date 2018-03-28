#!/bin/bash
#echo [controllers] >> ../inventory
for ((i=0; i<$CONTROLLERS_COUNT; i++))
do
gcloud compute instances create controller-${i} \
       --async \
       --boot-disk-size 200GB\
       --can-ip-forward \
       --image-family ubuntu-1604-lts \
       --image-project ubuntu-os-cloud \
       --machine-type n1-standard-1 \
       --private-network-ip 10.240.0.1${i} \
       --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
       --subnet kubernetes \
       --tags kubernetes-the-hard-way,controller
sleep 10
ansible_host=$(gcloud compute instances describe controller-${i} --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
echo controller-${i} $ansible_host >> ../inventory
if [ -z `ssh-keygen -F $ansible_host` ]; then
  ssh-keyscan -H ansible_host=$ansible_host >> ~/.ssh/known_hosts
fi
done

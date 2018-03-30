#!/bin/bash
#echo [workers] >> ../inventory
for ((i=0; i<$WORKERS_COUNT; i++))
do
gcloud compute instances create worker-${i} \
       --async \
       --boot-disk-size 200GB \
       --can-ip-forward \
       --image-family ubuntu-1604-lts \
       --image-project ubuntu-os-cloud \
       --machine-type n1-standard-1 \
       --metadata pod-cidr=10.200.${i}.0/24 \
       --private-network-ip 10.240.0.2${i} \
       --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
       --subnet kubernetes \
       --tags kubernetes-the-hard-way,worker
#echo 10.240.0.2${i} >> ../inventory
done

#waiting for assigning to the tag_group
#sleep 480

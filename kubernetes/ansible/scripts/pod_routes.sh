#!/bin/bash
for ((i=0; i<$WORKERS_COUNT; i++))
do
  let "D=20+${i}"
  gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
  --network kubernetes-the-hard-way \
  --next-hop-address 10.240.0.${D} \
  --destination-range 10.200.${i}.0/24
done

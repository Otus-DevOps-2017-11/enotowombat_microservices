#!/bin/bash

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

instance=$1

cd $INSTALL_DIR

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=${instance}.kubeconfig

kubectl config set-credentials system:node:${instance} \
  --client-certificate=${instance}.pem \
  --client-key=${instance}-key.pem \
  --embed-certs=true \
  --kubeconfig=${instance}.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:node:${instance} \
  --kubeconfig=${instance}.kubeconfig

kubectl config use-context default --kubeconfig=${instance}.kubeconfig

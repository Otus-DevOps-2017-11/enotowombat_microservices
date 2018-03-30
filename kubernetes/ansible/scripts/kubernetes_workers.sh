#!/bin/bash

# Provisioning a Kubernetes Worker Node
# Install the cri-o OS Dependencies

# Add the alexlarsson/flatpak PPA which hosts the libostree package

sudo add-apt-repository -y ppa:alexlarsson/flatpak

sudo apt-get update

# Install the OS dependencies required by the cri-o container runtime

sudo apt-get install -y socat libgpgme11 libostree-1-1

# Download and Install Worker Binaries

wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc4/runc.amd64 \
  https://storage.googleapis.com/kubernetes-the-hard-way/crio-amd64-v1.0.0-beta.0.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.7.4/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.7.4/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.7.4/bin/linux/amd64/kubelet

# Create the installation directories

sudo mkdir -p \
  /etc/containers \
  /etc/cni/net.d \
  /etc/crio \
  /opt/cni/bin \
  /usr/local/libexec/crio \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Install the worker binaries

sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/

tar -xvf crio-amd64-v1.0.0-beta.0.tar.gz

chmod +x kubectl kube-proxy kubelet runc.amd64

sudo mv runc.amd64 /usr/local/bin/runc

sudo mv crio crioctl kpod kubectl kube-proxy kubelet /usr/local/bin/

sudo mv conmon pause /usr/local/libexec/crio/

# Configure CNI Networking

# Retrieve the Pod CIDR range for the current compute instance

POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

# Create the bridge network configuration file

cat > 10-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# Create the loopback network configuration file

cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

# Move the network configuration files to the CNI configuration directory

sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

# Configure the CRI-O Container Runtime

sudo mv crio.conf seccomp.json /etc/crio/

sudo mv policy.json /etc/containers/

cat > crio.service <<EOF
[Unit]
Description=CRI-O daemon
Documentation=https://github.com/kubernetes-incubator/cri-o

[Service]
ExecStart=/usr/local/bin/crio
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubelet

sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/

sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig

sudo mv ca.pem /var/lib/kubernetes/

# Create the kubelet.service systemd unit file

cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=crio.service
Requires=crio.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/crio.sock \\
  --enable-custom-metrics \\
  --image-pull-progress-deadline=2m \\
  --image-service-endpoint=unix:///var/run/crio.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --require-kubeconfig \\
  --runtime-request-timeout=10m \\
  --tls-cert-file=/var/lib/kubelet/${HOSTNAME}.pem \\
  --tls-private-key-file=/var/lib/kubelet/${HOSTNAME}-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Proxy

sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

# Create the kube-proxy.service systemd unit file

cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the Worker Services

sudo mv crio.service kubelet.service kube-proxy.service /etc/systemd/system/

sudo systemctl daemon-reload

sudo systemctl enable crio kubelet kube-proxy

sudo systemctl start crio kubelet kube-proxy

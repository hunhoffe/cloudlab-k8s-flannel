#!/bin/bash
set -x

# Unlike home directories, this directory will be included in the image
USER_GROUP=k8suser
INSTALL_DIR=/home/k8s-flannel

# General updates
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# Pip is useful
sudo apt install -y python3-pip
python3 -m pip install --upgrade pip

# Turn off swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Set containerd configuraiton
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Set kubernetes networking settings
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload to load above changes
sudo sysctl --system

# Install containerd
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo apt-add-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io
sudo apt-mark hold containerd.io

# Configure containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Enable containerd system and check status
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd | grep "active (running)" || (echo "ERROR: containerd service not running, exiting."; exit -1)

# Install Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Prepare kubelet to use private cloudlab IP address
sudo sed -i.bak "s/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml --node-ip=REPLACE_ME_WITH_IP/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Make sure the $INSTALL_DIR can be accessible to everyone with access to this profile
sudo groupadd $USER_GROUP
sudo mkdir $INSTALL_DIR
sudo chgrp -R $USER_GROUP $INSTALL_DIR
sudo chmod -R o+rw $INSTALL_DIR

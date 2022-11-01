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

# Install docker
sudo apt install -y docker.io
sudo systemctl start docker || (echo "ERROR: Docker systemctl start failed, exiting." && exit -1)
sudo systemctl enable docker || (echo "ERROR: Docker systemctl enable failed, exiting." && exit -1)
sudo docker run hello-world | grep "Hello from Docker!" || (echo "ERROR: Docker installation failed, exiting." && exit -1)

# Install Kubernetes
sudo apt install -y apt-transport-https curl
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt install -y kubeadm kubelet kubectl kubernetes-cni

# Prepare kubelet to use private cloudlab IP address
sudo sed -i.bak "s/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml --node-ip=REPLACE_ME_WITH_IP/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Make sure the $INSTALL_DIR can be accessible to everyone with access to this profile
sudo groupadd $USER_GROUP
sudo mkdir $INSTALL_DIR
sudo chgrp -R $USER_GROUP $INSTALL_DIR
sudo chmod -R o+rw $INSTALL_DIR
